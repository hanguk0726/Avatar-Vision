use std::{
    collections::HashMap,
    mem::ManuallyDrop,
    ops::Not,
    path::PathBuf,
    sync::{Arc, Mutex},
    thread,
    time::{Duration, Instant},
};

use async_trait::async_trait;
use image::{DynamicImage, ImageBuffer, Rgba};
use irondash_message_channel::{
    AsyncMethodHandler, AsyncMethodInvoker, IsolateId, Late, MethodCall, PlatformError,
    PlatformResult, Value,
};
use irondash_run_loop::RunLoop;

use kanal::{AsyncReceiver, AsyncSender, Sender};
use log::{debug, error, info};
use nokhwa::Buffer;

use crate::{
    domain::{
        channel::ChannelService,
        recording::{encode_to_h264, to_mp4, RecordingService, WritingState},
    },
    tools::{
        image_processing::{decode_to_rgb, rgba_to_yuv},
        ordqueue::new,
    },
};

use super::audio_message_channel::Pcm;

const FPS: u32 = 24;
const THUMBNAIL_DIR_NAME: &str = "thumbnails";
pub struct RecordingHandler {
    pub audio: Arc<Mutex<Pcm>>,
    pub recording_info: Arc<Mutex<RecordingService>>,
    pub channel_handler: Arc<Mutex<ChannelService>>,
    final_audio_buffer: Arc<Mutex<Pcm>>,
    ui_event: (
        Arc<AsyncSender<(String, String)>>,
        Arc<AsyncReceiver<(String, String)>>,
    ),
    invoker: Late<AsyncMethodInvoker>,
}

impl RecordingHandler {
    pub fn new(
        audio: Arc<Mutex<Pcm>>,
        recording_info: Arc<Mutex<RecordingService>>,
        channel_handler: Arc<Mutex<ChannelService>>,
    ) -> Self {
        let (s, r) = kanal::bounded_async(1);
        let ui_event = (Arc::new(s), Arc::new(r));

        Self {
            audio,
            recording_info,
            channel_handler,
            final_audio_buffer: Arc::new(Mutex::new(Pcm::new())),
            ui_event,
            invoker: Late::new(),
        }
    }
    // writing encdoed video file to disk
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
                let recording_receiver = self.channel_handler.lock().unwrap().recording.1.clone();

                let recording = recording_info.lock().unwrap().recording.clone();
                // toggle recording state
                {
                    let mut recording_info = self.recording_info.lock().unwrap();
                    recording_info.start();
                }

                self.mark_recording_state_on_ui(call.isolate);

                // the audio buffer is not empty when it's not the first time to record, flush it
                {
                    self.audio.lock().unwrap().data.lock().unwrap().clear();
                }

                // Collecting and processing frames to achieve 24fps.
                let webcam_frame_queue: Arc<Mutex<Vec<(Buffer, Instant)>>> =
                    Arc::new(Mutex::new(vec![]));
                thread::spawn(move || {
                    let timestamp = Arc::new(Mutex::new(None));
                    rayon::scope(|s| {
                        s.spawn(|_| {
                            while let Ok(el) = recording_receiver.recv() {
                                webcam_frame_queue.lock().unwrap().push(el);
                            }
                        });
                        s.spawn(|_| {
                            loop {
                                // waiting for enough elements or processing the queue
                                let list_ = { webcam_frame_queue.lock().unwrap().clone() };
                                if list_.len() > 0 {
                                    let flushed_length =
                                        batch(timestamp.clone(), list_, encoding_sender.clone());
                                    if flushed_length != 0 {
                                        //remove all flushed elements from origin
                                        let mut list = webcam_frame_queue.lock().unwrap();
                                        list.drain(0..flushed_length as usize);
                                    }
                                } else {
                                    thread::sleep(Duration::from_millis(400));
                                }
                                if recording.load(std::sync::atomic::Ordering::Relaxed).not()
                                    && recording_receiver.is_empty()
                                {
                                    recording_receiver.close();
                                    break;
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

                let file_path_prefix = map.get("file_path_prefix").unwrap().to_string();
                let file_name = map.get("file_name").unwrap().to_string();
                debug!("file_path_prefix: {:?}", file_path_prefix);

                let resolution = map.get("resolution").unwrap().as_str();
                let resolution = resolution.split("x").collect::<Vec<&str>>();
                let width = resolution[0].parse::<usize>().unwrap();
                let height = resolution[1].parse::<usize>().unwrap();

                let ui_event_sender = self.ui_event.0.clone();
                let update_writing_state = move |state: WritingState| {
                    let sent = ui_event_sender
                        .try_send(("write_state".to_string(), state.to_str().to_string()))
                        .unwrap_or_else(|_| false);
                    if sent {
                        debug!("ui_event {} sent", state.to_str());
                    } else {
                        error!("ui_Event sending failed");
                    }
                };

                let mut thumbnail_rgba: Vec<u8> = vec![];
                let mut count = 0;

                let encoding_receiver = self.channel_handler.lock().unwrap().encoding.1.clone();
                if encoding_receiver.is_closed() {
                    self.channel_handler.lock().unwrap().reset_encoding();
                }

                // This maintains order of frames while they are being encoded in multiple threads pool
                // the data added to this queue will be consumed through the 'iter'.
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

                let buffer_file_name = "temp.h264";
                
                thread::spawn(move || {
                    rayon::scope(|s| {
                        s.spawn(|_| {
                            while let Ok(buf) = encoding_receiver.recv() {
                                //pulling first frame to get the thumbnail
                                if count == 0 {
                                    let rgba = decode_to_rgb(
                                        buf.buffer(),
                                        &buf.source_frame_format(),
                                        true,
                                        width as u32,
                                        height as u32,
                                    )
                                    .unwrap();
                                    thumbnail_rgba.extend_from_slice(&rgba[..]);
                                }

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
                                // when threads for display when off, increase the thread count for encoding
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
                            //keep encoding to h264. this will be terminated when the queue is empty
                            encode_to_h264(iter, &buffer_file_name, width, height);
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

                    // encoded h264 data.
                    // get the data from file 'temp.h264'
                    let processed = std::fs::read(&buffer_file_name).unwrap();

                    let mut video_path = PathBuf::from(&file_path_prefix);
                    video_path.push(&file_name);

                    //write to mp4
                    if let Err(e) = to_mp4(
                        &processed[..],
                        video_path,
                        FPS,
                        final_audio.lock().unwrap().to_owned(),
                        width as u32,
                        height as u32,
                    ) {
                        error!("Failed to save video {:?}", e);
                    }

                    save_thumbnail(&file_path_prefix, &file_name, thumbnail_rgba, width, height);

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
            //XXX need to be seperated if this handles more events
            "listen_ui_event_dispatcher" => {
                debug!(
                    "Received request {:?} on thread {:?}",
                    call,
                    thread::current().id()
                );
                while let Ok(event) = self.ui_event.1.recv().await {
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

fn batch(
    timestamp: Arc<Mutex<Option<Instant>>>,
    list: Vec<(Buffer, Instant)>,
    encoding_sender: Sender<Buffer>,
) -> u32 {
    let one_second = Duration::from_millis(1000);
    let frame_interval = Duration::from_millis(1000 / FPS as u64);
    let mut timestamp = timestamp.lock().unwrap();
    if timestamp.is_none() {
        *timestamp = Some(list.first().unwrap().1 + one_second);
    }
    let mut enough = false;

    let mut frame_count = 0u32;
    for (_, time) in list.iter() {
        // if list contains frames for upcoming second
        if time > &timestamp.unwrap() {
            enough = true;
            break;
        }
        frame_count += 1;
    }

    if enough.not() {
        info!("not enough frame, wait and retry");
        thread::sleep(Duration::from_millis(400));
        return 0;
    }

    let mut loop_count = 0;

    let mut last_tick = list.first().unwrap().1;

    for i in 0..frame_count {
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
    debug!("{} frames filtered from {}", loop_count, frame_count);
    // if webcam is not fast enough, send the last frame multiple times
    // this is not ideal, but it's better than dropping frames which will cause audio and video out of sync.
    // also the mp4muxer could not handle the case when data is not enough for requested fps.
    while (FPS - loop_count) > 0 {
        encoding_sender
            .send(list[(frame_count - 1) as usize].0.clone())
            .unwrap();
        loop_count += 1;
        info!("{} sending additional frame", loop_count);
    }

    *timestamp = Some(timestamp.unwrap() + one_second);
    frame_count
}

fn save_thumbnail(
    file_path_prefix: &str,
    file_name: &str,
    thumbnail_rgba: Vec<u8>,
    width: usize,
    height: usize,
) {
    // create an ImageBuffer from the RGBA data
    let imgbuf =
        ImageBuffer::<Rgba<u8>, _>::from_raw(width as u32, height as u32, thumbnail_rgba).unwrap();
    // Convert the image buffer to a dynamic image
    let image = DynamicImage::ImageRgba8(imgbuf);

    // Resize the dynamic image
    let resized_image = image.resize(320, 180, image::imageops::FilterType::Lanczos3);

    // Convert the resized dynamic image back to an image buffer
    let resized_imgbuf = resized_image.into_rgba8();

    let mut thumbnail_path = PathBuf::from(&file_path_prefix);
    thumbnail_path.push(THUMBNAIL_DIR_NAME);
    thumbnail_path.push(&file_name);
    thumbnail_path.set_extension("png");

    resized_imgbuf.save(thumbnail_path).unwrap();
    info!("thumbnail saved");
}
