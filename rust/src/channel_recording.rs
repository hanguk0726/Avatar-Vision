use std::{
    collections::HashMap,
    fs,
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

use kanal::{AsyncReceiver, AsyncSender};
use log::{debug, error, info};

use crate::{
    channel::ChannelHandler,
    channel_audio::Pcm,
    domain::image_processing::rgba_to_yuv,
    recording::{encode_to_h264, to_mp4, RecordingInfo, WritingState},
    tools::ordqueue::{new, OrdQueueIter},
};

pub struct RecordingHandler {
    pub audio: Arc<Mutex<Pcm>>,
    pub recording_info: Arc<Mutex<RecordingInfo>>,
    pub channel_handler: Arc<Mutex<ChannelHandler>>,
    pub encoding_buffer: Arc<Mutex<Vec<u8>>>,
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
        encoding_buffer: Arc<Mutex<Vec<u8>>>,
    ) -> Self {
        let (s, r) = kanal::bounded_async(1);
        let uiEvent = (Arc::new(s), Arc::new(r));

        Self {
            audio,
            recording_info,
            channel_handler,
            encoding_buffer,
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
                let encoding_buffer = self.encoding_buffer.clone();
                let encoding_sender = channel_handler.lock().unwrap().encoding.0.clone();
                let recording = recording_info.lock().unwrap().recording.clone();

                {
                    self.audio.lock().unwrap().data.lock().unwrap().clear();
                }
                // start audio before start recording
                {
                    let mut recording_info = self.recording_info.lock().unwrap();
                    recording_info.start();
                }
                self.mark_recording_state_on_ui(call.isolate);
                let mut frame_count = 0;
                let recording_start_time = std::time::Instant::now();
                //Duration::from_nanos(83_333_333);
                // Record textures in a separate thread and compensate for delay to maintain the frame rate.
                let frame_interval = Duration::from_nanos(41_666_667);
                let mut adjusted_frame_interval = Duration::from_nanos(41_666_667);
                let mut accumulated = Duration::from_nanos(0);
                let mut accumulated_minus = Duration::from_nanos(0);
                let mut last_time = Instant::now();
                let mut compensation = Duration::from_nanos(0);
                let mut compensation_minus = Duration::from_nanos(0);
                let max_adjustment = Duration::from_nanos(400_000);

                let mut skip = false;
                thread::spawn(move || loop {
                    let start_time = Instant::now();
                    let elapsed: Duration = if skip {
                        skip = false;
                        frame_interval
                    } else {
                        start_time.duration_since(last_time)
                    };
                    last_time = start_time;
                    if elapsed > frame_interval {
                        // Since the sleep won't be accurate even with the adjustment,
                        // the main goal is to minimize the value of 'accumulated'.
                        let error = elapsed - frame_interval;
                        accumulated += error;

                        adjusted_frame_interval -= error.clamp(Duration::ZERO, max_adjustment);

                        // For a specific frame rate, there is a fixed number of frames that are required.
                        // Adding one frame means potentially taking the place of a future frame,
                        // so it effectively runs at double speed in the long run.
                        if (accumulated / 2) >= compensation {
                            let rgba = encoding_buffer.lock().unwrap();
                            let sent = encoding_sender.try_send(rgba.clone()).unwrap_or_else(|e| {
                                debug!("encoding channel sending failed: {:?}", e);
                                false
                            });
                            if sent {
                                frame_count += 1;
                                debug!(
                                    "frame_count: {:?}, elapsed: {:?}, adjusted_frame_interval {:?}",
                                    frame_count, elapsed, adjusted_frame_interval
                                );
                            }
                            compensation += frame_interval;
                        }
                    } else {
                        let error = frame_interval - elapsed;
                        accumulated_minus += error;
                        adjusted_frame_interval += error.clamp(Duration::ZERO, max_adjustment);

                        if (accumulated_minus / 2) >= compensation_minus {
                            compensation_minus += frame_interval;
                            skip = true;
                        } else {
                            skip = false;
                        }
                    }
                    if skip.not() {
                        spin_sleep::sleep(adjusted_frame_interval);

                        let rgba = encoding_buffer.lock().unwrap();
                        let sent = encoding_sender.try_send(rgba.clone()).unwrap_or_else(|e| {
                            debug!("encoding channel sending failed: {:?}", e);
                            false
                        });
                        if sent {
                            frame_count += 1;
                            debug!(
                                "frame_count: {:?}, elapsed: {:?}, adjusted_frame_interval {:?}",
                                frame_count, elapsed, adjusted_frame_interval
                            );
                        }
                        debug!(
                            "accumulated: {:?},accumulated_minus {:?}, total {:?} recording: {:?}, compansation: {:?}",
                            accumulated,
                            accumulated_minus,
                            accumulated.saturating_sub(accumulated_minus),
                            std::time::Instant::now().duration_since(recording_start_time),
                            compensation
                        );
                        if recording.load(std::sync::atomic::Ordering::Relaxed).not() {
                            break;
                        }
                    }
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
                    // REFACTOR ME
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
                let queue = Arc::new(queue);
                let pool = tokio::runtime::Builder::new_multi_thread()
                    .worker_threads(2)
                    .build()
                    .unwrap();
                update_writing_state(WritingState::Collecting);
                // update_writing_state(WritingState::Encoding);

                let processed: Arc<Mutex<Vec<u8>>> = Arc::new(Mutex::new(Vec::new()));
                let processed2 = processed.clone();
                let audio = Arc::clone(&self.audio);
                let mut fianl_audio: Option<Pcm> = None;
                thread::spawn(move || {
                    let r = encoding_receiver.to_sync();

                    rayon::scope(|s| {
                        s.spawn(|_| {
                            while let Ok(rgba) = r.recv() {
                                let queue = queue.clone();
                                pool.spawn(async move {
                                    let yuv = rgba_to_yuv(&rgba[..], width, height);
                                    queue.push(count, yuv).unwrap_or_else(|e| {
                                        error!("queue push failed: {:?}", e);
                                    });
                                    // debug!("encoding to h264 send {}", count);
                                });
                                // debug!("encoded {} frames", count);
                                count += 1;
                            }
                            let audio = audio.lock().unwrap();
                            fianl_audio = Some(audio.clone());
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
                        fianl_audio.unwrap(),
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
