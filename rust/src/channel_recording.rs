use std::{
    collections::HashMap,
    fs,
    mem::ManuallyDrop,
    ops::Not,
    sync::{atomic::AtomicUsize, Arc, Mutex},
    thread,
};

use async_trait::async_trait;
use irondash_message_channel::{
    AsyncMethodHandler, AsyncMethodInvoker, IsolateId, Late, MethodCall, PlatformError,
    PlatformResult, Value,
};
use irondash_run_loop::RunLoop;

use log::{debug, error, info};

use crate::{
    channel::ChannelHandler,
    channel_audio::Pcm,
    domain::image_processing::rgba_to_yuv,
    recording::{encode_to_h264, to_mp4, RecordingInfo, WritingState},
    tools::ordqueue::{new, OrdQueueIter},
};

pub struct RecordingHandler {
    pub encoded: Arc<Mutex<Vec<u8>>>,
    pub audio: Arc<Mutex<Pcm>>,
    pub recording_info: Arc<Mutex<RecordingInfo>>,
    pub channel_handler: Arc<Mutex<ChannelHandler>>,
    pub encoding_buffer: Arc<Mutex<Vec<u8>>>,
    invoker: Late<AsyncMethodInvoker>,
}

impl RecordingHandler {
    pub fn new(
        audio: Arc<Mutex<Pcm>>,
        recording_info: Arc<Mutex<RecordingInfo>>,
        channel_handler: Arc<Mutex<ChannelHandler>>,
        encoding_buffer: Arc<Mutex<Vec<u8>>>,
    ) -> Self {
        Self {
            encoded: Arc::new(Mutex::new(Vec::new())),
            audio,
            recording_info,
            channel_handler,
            encoding_buffer,
            invoker: Late::new(),
        }
    }

    fn encode(&self, yuv_iter: OrdQueueIter<Vec<u8>>, len: usize, width: usize, height: usize) {
        let processed = encode_to_h264(yuv_iter, len, width, height);

        let encoded = Arc::clone(&self.encoded);
        let mut encoded = encoded.lock().unwrap();
        *encoded = processed;

        debug!("encoded length: {:?}", encoded.len());
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

    fn save(&self, file_path: &str, width: u32, height: u32) -> Result<(), std::io::Error> {
        debug!("*********** saving... ***********");

        let encoded = Arc::clone(&self.encoded);
        let encoded = encoded.lock().unwrap();

        let audio = Arc::clone(&self.audio);
        let audio = audio.lock().unwrap();
        let audio = audio.to_owned();

        to_mp4(&encoded[..], file_path, 24, audio, width, height).unwrap();
        debug!("*********** saved! ***********");
        Ok(())
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
                    let mut recording_info = self.recording_info.lock().unwrap();
                    recording_info.start();
                }
                {
                    self.mark_recording_state_on_ui(call.isolate);
                    self.audio.lock().unwrap().data.lock().unwrap().clear();
                }
                let mut frame_count = 0;
                let desired_frame_time = std::time::Duration::from_micros(41666);
                let mut accumulator = std::time::Duration::from_micros(0);
                let started = std::time::Instant::now();
                let mut previous_time = started;

                // capturing textures should be done in a separate thread
                // to catch up the delay & maintain the frame rate
                // Compensate for the delay rather than trying to control all of its effects
                thread::spawn(move || {
                    'outer_loop: loop {
                        let start_time = std::time::Instant::now();
                        accumulator += start_time.duration_since(previous_time);

                        previous_time = start_time;

                        // If the accumulator has accumulated enough time for a frame, process it
                        while accumulator >= desired_frame_time {
                            let rgba = encoding_buffer.lock().unwrap();
                            let sent = encoding_sender.try_send(rgba.clone()).unwrap_or_else(|e| {
                                debug!("encoding channel sending failed: {:?}", e);
                                false
                            });
                            if sent {
                                frame_count += 1;
                                accumulator -= desired_frame_time;
                            } else {
                                if recording.load(std::sync::atomic::Ordering::Relaxed).not() {
                                    break 'outer_loop;
                                }
                            }
                        }

                        let elapsed = start_time.duration_since(started);

                        if recording.load(std::sync::atomic::Ordering::Relaxed).not() {
                            break 'outer_loop;
                        }
                        debug!(
                            "accumulator: {:?}, time elapsed: {:?}",
                            accumulator, elapsed
                        );

                        let time_to_sleep = desired_frame_time;
                        std::thread::sleep(time_to_sleep);
                        // debug!(
                        //     "consumed time: {:?}, frames encoded: {}",
                        //     time_to_sleep,
                        //     frame_count
                        // );
                    }
                });

                info!("recording finished");
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
                let file_path = map.get("file_path").unwrap().as_str();
                debug!("file_path: {:?}", file_path);
                let resolution = map.get("resolution").unwrap().as_str();
                let resolution = resolution.split("x").collect::<Vec<&str>>();
                let width = resolution[0].parse::<usize>().unwrap();
                let height = resolution[1].parse::<usize>().unwrap();

                let update_writing_state = |state: WritingState| async move {
                    {
                        self.recording_info.lock().unwrap().set_writing_state(state);
                    }

                    self.mark_writing_state_on_ui(call.isolate);
                };

                let mut count = 0;
                let encoding_receiver = self.channel_handler.lock().unwrap().encoding.1.clone();
                if encoding_receiver.is_closed() {
                    self.channel_handler.lock().unwrap().reset_encoding();
                }
                let num_worker = if num_cpus::get() >= 16 { 4 } else { 2 }; //TODO spilit this into a mode so that user can choose
                let (queue, iter) = new();
                let queue = Arc::new(queue);
                let pool = tokio::runtime::Builder::new_multi_thread()
                    .worker_threads(num_worker)
                    .build()
                    .unwrap();
                update_writing_state(WritingState::Collecting).await;

                while let Ok(rgba) = encoding_receiver.recv().await {
                    let queue = queue.clone();
                    pool.spawn(async move {
                        let yuv = rgba_to_yuv(&rgba[..], width, height);
                        queue.push(count, yuv).unwrap();
                    });
                    // debug!("encoded {} frames", count);
                    count += 1;
                }
                update_writing_state(WritingState::Encoding).await;
                self.encode(iter, count, width, height);

                debug!(
                    "encoded {} frames, time elapsed {}",
                    count,
                    started.elapsed().as_secs()
                );
                update_writing_state(WritingState::Saving).await;
                #[cfg(debug_assertions)]
                {
                    std::thread::sleep(std::time::Duration::from_secs(1));
                }

                if let Err(e) = self.save(file_path, width as u32, height as u32) {
                    error!("Failed to save video {:?}", e);
                }

                {
                    self.recording_info
                        .lock()
                        .unwrap()
                        .set_writing_state(WritingState::Idle);
                }
                self.mark_writing_state_on_ui(call.isolate);

                pool.shutdown_timeout(std::time::Duration::from_secs(1));
                info!("encording finished");
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
