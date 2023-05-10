use std::{
    collections::HashMap,
    fs,
    io::Read,
    mem::ManuallyDrop,
    ops::Not,
    sync::{
        atomic::{AtomicUsize, Ordering},
        Arc, Mutex,
    },
    thread,
    time::{Duration, Instant},
};

use async_trait::async_trait;
use irondash_message_channel::{
    AsyncMethodHandler, AsyncMethodInvoker, IsolateId, Late, MethodCall, PlatformError,
    PlatformResult, Value,
};
use irondash_run_loop::RunLoop;

use kanal::{AsyncReceiver, AsyncSender, Sender};
use log::{debug, error, info};
use nokhwa::Buffer;
use tokio::{
    runtime::Runtime,
    task::{block_in_place, spawn_blocking},
};

use crate::{
    channel::ChannelHandler,
    channel_audio::Pcm,
    domain::image_processing::{decode_to_rgb, rgba_to_yuv},
    recording::{encode_to_h264, to_mp4, RecordingInfo, WritingState},
    tools::ordqueue::{new, OrdQueueIter},
};

pub struct RecordingHandler {
    pub audio: Arc<Mutex<Pcm>>,
    pub recording_info: Arc<Mutex<RecordingInfo>>,
    pub channel_handler: Arc<Mutex<ChannelHandler>>,
    final_audio_buffer: Arc<Mutex<Pcm>>,
    uiEvent: (
        Arc<AsyncSender<(String, String)>>,
        Arc<AsyncReceiver<(String, String)>>,
    ),
    invoker: Late<AsyncMethodInvoker>,
}

impl RecordingHandler {
    pub fn new(
        audio: Arc<Mutex<Pcm>>,
        recording_info: Arc<Mutex<RecordingInfo>>,
        channel_handler: Arc<Mutex<ChannelHandler>>,
    ) -> Self {
        let (s, r) = kanal::bounded_async(1);
        let uiEvent = (Arc::new(s), Arc::new(r));

        Self {
            audio,
            recording_info,
            channel_handler,
            final_audio_buffer: Arc::new(Mutex::new(Pcm::new())),
            uiEvent,
            invoker: Late::new(),
        }
    }

    fn mark_writing_state_on_ui(&self, target_isolate: IsolateId) {
        let recording_info = self.recording_info.lock().unwrap();
        let writing_state = recording_info.writing_state.lock().unwrap();
        self.invoker.call_method_sync(
            target_isolate,
            "mark_writing_state",
            &*writing_state.to_str(),
            |_| {},
        );
    }

    fn mark_recording_state_on_ui(&self, target_isolate: IsolateId) {
        let recording_info = self.recording_info.lock().unwrap();
        let recording = recording_info
            .recording
            .load(std::sync::atomic::Ordering::Relaxed);

        self.invoker
            .call_method_sync(target_isolate, "mark_recording_state", recording, |_| {});
    }
}

#[async_trait(?Send)]
impl AsyncMethodHandler for RecordingHandler {
    fn assign_invoker(&self, _invoker: AsyncMethodInvoker) {
        self.invoker.set(_invoker);
    }

    async fn on_method_call(&self, call: MethodCall) -> PlatformResult {
        match call.method.as_str() {
            "start_recording" => {
                debug!(
                    "Received request {:?} on thread {:?}",
                    call,
                    thread::current().id()
                );

                let recording_info = self.recording_info.clone();
                let channel_handler = self.channel_handler.clone();
                let encoding_sender = channel_handler.lock().unwrap().encoding.0.clone();
                let recording = recording_info.lock().unwrap().recording.clone();
                let recording_receiver = self.channel_handler.lock().unwrap().recording.1.clone();
                // start audio before start recording
                {
                    let mut recording_info = self.recording_info.lock().unwrap();
                    recording_info.start();
                }
                self.mark_recording_state_on_ui(call.isolate);

                let mut timestamp = None;

                let mut batch =
                    move |list: Vec<(Buffer, Instant)>, encoding_sender: Sender<Buffer>| -> u32 {
                        let fps = 24;
                        let one_second = Duration::from_millis(1000);
                        let frame_interval = Duration::from_millis(1000 / fps);
                        if timestamp.is_none() {
                            timestamp = Some(list.first().unwrap().1 + one_second);
                        }
                        let mut enough = false;
                        let mut count = 0u32;
                        for (_, time) in list.iter() {
                            count += 1;
                            if time > &timestamp.unwrap() {
                                enough = true;
                                break;
                            }
                        }
                        if enough.not() {
                            info!("not enough frame, wait and retry");
                            thread::sleep(Duration::from_millis(400));
                            return 0;
                        }
                        let mut loop_count = 0;

                        let mut last_tick = list.first().unwrap().1;
                        for i in 0..count {
                            let (buffer, time) = &list[i as usize];
                            if i != 0 {
                                let diff = time.saturating_duration_since(last_tick);
                                // debug!("diff: {:?}, i {:?} ,time {:?}", diff, i, time);
                                if diff < frame_interval {
                                    continue;
                                }
                            }

                            encoding_sender.send(buffer.clone()).unwrap();
                            last_tick += frame_interval;
                            loop_count += 1;
                        }
                        debug!("{} frames filtered", loop_count);
                        while (fps - loop_count) > 0 {
                            encoding_sender
                                .send(list[(count - 1) as usize].0.clone())
                                .unwrap();
                            loop_count += 1;
                        }
                        timestamp = Some(timestamp.unwrap() + one_second);
                        count
                    };
                {
                    self.audio.lock().unwrap().data.lock().unwrap().clear();
                    debug!("**************************** audio data cleared ****************************");
                }
                // + 1s on last_time when flush
                let list: Arc<Mutex<Vec<(Buffer, Instant)>>> = Arc::new(Mutex::new(vec![]));

                thread::spawn(move || {
                    rayon::scope(|s| {
                        s.spawn(|_| {
                            while let Ok(el) = recording_receiver.recv() {
                                list.lock().unwrap().push(el);
                            }
                        });
                        s.spawn(|_| {
                            loop {
                                let list_ = { list.lock().unwrap().clone() };
                                if list_.len() > 0 {
                                    let flushed_length = batch(list_, encoding_sender.clone());
                                    if flushed_length != 0 {
                                        //remove all flushed elements from origin
                                        let mut list = list.lock().unwrap();
                                        list.drain(0..flushed_length as usize);
                                    }
                                } else {
                                    thread::sleep(Duration::from_millis(400));
                                }
                            }
                        });
                    });
                });

                info!("The recording got into the process.");
                Ok("ok".into())
            }
            "start_encording" => {
                debug!(
                    "Received request {:?} on thread {:?}",
                    call,
                    thread::current().id()
                );
                let started = std::time::Instant::now();
                let map: HashMap<String, String> = call.args.try_into().unwrap();
                let file_path = map.get("file_path").unwrap().to_string();
                debug!("file_path: {:?}", file_path);
                let resolution = map.get("resolution").unwrap().as_str();
                let resolution = resolution.split("x").collect::<Vec<&str>>();
                let width = resolution[0].parse::<usize>().unwrap();
                let height = resolution[1].parse::<usize>().unwrap();
                let ui_event_sender = self.uiEvent.0.clone();
                let update_writing_state = move |state: WritingState| {
                    let sent = ui_event_sender
                        .try_send(("write_state".to_string(), state.to_str().to_string()))
                        .unwrap_or_else(|_| false);
                    if sent {
                        debug!("uiEvent {} sent", state.to_str());
                    } else {
                        error!("uiEvent sending failed");
                    }
                };

                let mut count = 0;
                let encoding_receiver = self.channel_handler.lock().unwrap().encoding.1.clone();
                if encoding_receiver.is_closed() {
                    self.channel_handler.lock().unwrap().reset_encoding();
                }
                let (queue, iter) = new();
                let queue: Arc<crate::tools::ordqueue::OrdQueue<Vec<u8>>> = Arc::new(queue);
                let final_audio = self.final_audio_buffer.clone();
                let mut worker_count = 2;
                let mut pool = tokio::runtime::Builder::new_multi_thread()
                    .worker_threads(worker_count)
                    .build()
                    .unwrap();
                update_writing_state(WritingState::Encoding);
                let writing_state = { self.recording_info.lock().unwrap().writing_state.clone() };
                let processed: Arc<Mutex<Vec<u8>>> = Arc::new(Mutex::new(Vec::new()));
                let processed2 = processed.clone();

                thread::spawn(move || {
                    rayon::scope(|s| {
                        s.spawn(|_| {
                            while let Ok(buf) = encoding_receiver.recv() {
                                let queue = queue.clone();
                                pool.spawn(async move {
                                    let rgba = decode_to_rgb(
                                        buf.buffer(),
                                        &buf.source_frame_format(),
                                        true,
                                        width as u32,
                                        height as u32,
                                    )
                                    .unwrap();
                                    let yuv = rgba_to_yuv(&rgba[..], width, height);
                                    queue.push(count, yuv).unwrap_or_else(|e| {
                                        error!("queue push failed: {:?}", e);
                                    });
                                    // debug!("encoding to h264 send {}", count);
                                });
                                // debug!("encoded {} frames", count);
                                count += 1;
                                if *writing_state.lock().unwrap() == WritingState::Saving {
                                    if worker_count == 2 {
                                        worker_count = 8;
                                        pool = tokio::runtime::Builder::new_multi_thread()
                                            .worker_threads(worker_count)
                                            .build()
                                            .unwrap();
                                    }
                                }
                            }

                            drop(queue);

                            debug!("terminate receiving frames on recording");
                        });
                        s.spawn(|_| {
                            let mut processed = processed2.lock().unwrap();
                            encode_to_h264(iter, &mut processed, width, height);
                            debug!("terminate encoding frames on recording");
                        });
                    });

                    pool.shutdown_timeout(std::time::Duration::from_secs(1));
                    debug!(
                        "encoded {} frames, time elapsed {}",
                        count,
                        started.elapsed().as_secs()
                    );

                    debug!("*********** saving... ***********");

                    let processed = processed.lock().unwrap();

                    if let Err(e) = to_mp4(
                        &processed[..],
                        file_path,
                        24,
                        final_audio.lock().unwrap().to_owned(),
                        width as u32,
                        height as u32,
                    ) {
                        error!("Failed to save video {:?}", e);
                    }
                    debug!("*********** saved! ***********");
                    update_writing_state(WritingState::Idle);
                });

                info!("The encording got into the process.");
                Ok("ok".into())
            }
            "stop_recording" => {
                debug!(
                    "Received request {:?} on thread {:?}",
                    call,
                    thread::current().id()
                );
                {
                    let mut recording_info = self.recording_info.lock().unwrap();
                    recording_info.stop();
                }
                let audio = Arc::clone(&self.audio);
                let audio = audio.lock().unwrap();
                let mut final_audio = self.final_audio_buffer.lock().unwrap();
                *final_audio = audio.to_owned();
                debug!("**************************** audio data finalized ****************************");
                self.channel_handler.lock().unwrap().encoding.0.close();
                self.mark_recording_state_on_ui(call.isolate);
                self.recording_info
                    .lock()
                    .unwrap()
                    .set_writing_state(WritingState::Saving);
                self.mark_writing_state_on_ui(call.isolate);

                Ok("ok".into())
            }
            "listen_ui_event_dispatcher" => {
                debug!(
                    "Received request {:?} on thread {:?}",
                    call,
                    thread::current().id()
                );
                while let Ok(event) = self.uiEvent.1.recv().await {
                    debug!("event: {:?}", event);
                    match event.0.as_str() {
                        "write_state" => {
                            self.recording_info
                                .lock()
                                .unwrap()
                                .set_writing_state(WritingState::from_str(event.1.as_str()));
                            self.mark_writing_state_on_ui(call.isolate);
                        }
                        _ => {}
                    };
                }

                Ok("ok".into())
            }
            _ => Err(PlatformError {
                code: "invalid_method".into(),
                message: Some(format!("Unknown Method: {}", call.method)),
                detail: Value::Null,
            }),
        }
    }
}

pub fn init(recording_handler: RecordingHandler) {
    thread::spawn(|| {
        let _ =
            ManuallyDrop::new(recording_handler.register("recording_channel_background_thread"));
        debug!(
            "Running RunLoop on background thread {:?}",
            thread::current().id()
        );
        RunLoop::current().run();
    });
}
