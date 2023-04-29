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
    pub frame_count: Arc<AtomicUsize>,
    pub encoding: Arc<Mutex<Vec<u8>>>,
    invoker: Late<AsyncMethodInvoker>,
}

impl RecordingHandler {
    pub fn new(
        audio: Arc<Mutex<Pcm>>,
        recording_info: Arc<Mutex<RecordingInfo>>,
        channel_handler: Arc<Mutex<ChannelHandler>>,
        frame_count: Arc<AtomicUsize>,
        encoding: Arc<Mutex<Vec<u8>>>,
    ) -> Self {
        Self {
            encoded: Arc::new(Mutex::new(Vec::new())),
            audio,
            recording_info,
            channel_handler,
            invoker: Late::new(),
            frame_count,
            encoding,
        }
    }

    // fn encode(&self, yuv_iter: OrdQueueIter<Vec<u8>>, len: usize, width: usize, height: usize) {
    fn encode(&self, yuv_iter: Vec<Vec<u8>>, len: usize, width: usize, height: usize) {
        let processed = encode_to_h264(yuv_iter, len, width, height);

        let encoded = Arc::clone(&self.encoded);
        let mut encoded = encoded.lock().unwrap();
        *encoded = processed;

        debug!("encoded length: {:?}", encoded.len());
    }

    async fn mark_writing_state_on_ui(&self, target_isolate: IsolateId) {
        let recording_info = self.recording_info.lock().unwrap();
        let writing_state = recording_info.writing_state.lock().unwrap();

        if let Err(e) = self
            .invoker
            .call_method(
                target_isolate,
                "mark_writing_state",
                &*writing_state.to_str(),
            )
            .await
        {
            error!("Error while marking writing state on UI: {:?}", e);
        }
    }

    async fn mark_recording_state_on_ui(&self, target_isolate: IsolateId) {
        let recording_info = self.recording_info.lock().unwrap();
        let recording = recording_info
            .recording
            .load(std::sync::atomic::Ordering::Relaxed);

        if let Err(e) = self
            .invoker
            .call_method(target_isolate, "mark_recording_state", recording)
            .await
        {
            error!("Error while marking recording state on UI: {:?}", e);
        }
    }

    fn save(
        &self,
        frames: usize,
        file_path: &str,
        width: u32,
        height: u32,
    ) -> Result<(), std::io::Error> {
        debug!("*********** saving... ***********");

        let encoded = Arc::clone(&self.encoded);
        let encoded = encoded.lock().unwrap();

        let recording_info = self.recording_info.lock().unwrap();
        let frame_rate = recording_info.frame_rate(frames);

        let audio = Arc::clone(&self.audio);
        let audio = audio.lock().unwrap();
        let audio = audio.to_owned();

        to_mp4(&encoded[..], file_path, frame_rate, audio, width, height).unwrap();
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
                    self.mark_writing_state_on_ui(call.isolate).await;
                };

                update_writing_state(WritingState::Collecting).await;
                self.audio.lock().unwrap().data.lock().unwrap().clear();

                let encoding_receiver = self.channel_handler.lock().unwrap().encoding.1.clone();

                let num_worker = if num_cpus::get() >= 16 { 4 } else { 2 }; //TODO spilit this into a mode so that user can choose
                                                                            // let (queue, iter) = new();
                                                                            // let queue = Arc::new(queue);
                                                                            // let pool = tokio::runtime::Builder::new_multi_thread()
                                                                            //     .worker_threads(num_worker)
                                                                            //     .build()
                                                                            //     .unwrap();
                let started = std::time::Instant::now();

                {
                    let mut recording_info = self.recording_info.lock().unwrap();
                    recording_info.start();
                }
                self.mark_recording_state_on_ui(call.isolate).await;
                // while let Ok(rgba) = encoding_receiver.recv().await {
                //     let queue = queue.clone();
                //     pool.spawn(async move {

                //         let yuv = rgba_to_yuv(&rgba[..], width, height);
                //         queue.push(count, yuv).unwrap();
                //     });
                //     // debug!("encoded {} frames", count);
                //     count += 1;
                // }
                let mut count = Arc::new(Mutex::new(0usize));
                let mut empty = Arc::new(Mutex::new(vec![]));
                let count_thread = Arc::clone(&count);
                let _recording_info = self.recording_info.clone();
                let _channel_handler = self.channel_handler.clone();
                let _encoding = self.encoding.clone();
                let _empty = Arc::clone(&empty);
                thread::spawn(move || {
                    let mut prev_time = std::time::Instant::now();
                    let desired_frame_time = std::time::Duration::from_micros(41666);

                    loop {
                        let start_time = std::time::Instant::now();
                        let time_since_prev_frame = start_time.duration_since(prev_time);

                        // Determine the number of missed frames
                        let missed_frames = (time_since_prev_frame.as_micros()
                            / desired_frame_time.as_micros())
                            as u32;
                        let mut __e = _empty.lock().unwrap();
                        {
                            let rgba = _encoding.lock().unwrap();
                            __e.push(rgba.clone());
                            let mut count = count_thread.lock().unwrap();
                            *count += 1;
                        }

                        for _ in 0..missed_frames {
                            let rgba = _encoding.lock().unwrap();
                            __e.push(rgba.clone());
                            let mut count = count_thread.lock().unwrap();
                            *count += 1;
                        }

                        // Calculate the amount of time to sleep to maintain a consistent frame rate
                        let remainder = time_since_prev_frame - desired_frame_time * missed_frames;

                        let time_to_sleep = desired_frame_time - remainder;
                        std::thread::sleep(time_to_sleep);

                        // Record the current time as the previous frame time for the next iteration
                        prev_time = start_time;
                        let count = count_thread.lock().unwrap();
                        debug!("B encoded {:?} frames", count);
                        let recording_info = _recording_info.lock().unwrap();
                        if recording_info
                            .recording
                            .load(std::sync::atomic::Ordering::Relaxed)
                            .not()
                        {
                            break;
                        }
                        debug!(
                            "consumed time: {:?}, {:?}",
                            std::time::Instant::now().duration_since(started),
                            std::time::Instant::now().duration_since(start_time),
                        );
                    }
                });
                while let Ok(_) = encoding_receiver.recv().await {}
                update_writing_state(WritingState::Encoding).await;

                #[cfg(debug_assertions)]
                {
                    std::thread::sleep(std::time::Duration::from_secs(1));
                }
                let mut count = Arc::try_unwrap(count).unwrap().into_inner().unwrap();
                // debug!("ABC");
                // debug!("ABC2");
                // let iter = self.channel_handler.lock().unwrap().queue.1.clone();
                // debug!("ABC3");
                // let mut iter = iter.lock().unwrap();
                // debug!("ABC4");

                // while let Some(rgba) = iter.next() {
                //     debug!("encoded {} frames", count);
                //     let yuv = rgba_to_yuv(&rgba[..], width, height);
                //     empty.push(yuv);
                // }
                let empty = Arc::try_unwrap(empty).unwrap().into_inner().unwrap();
                let converted = empty
                    .into_iter()
                    .map(|rgba| rgba_to_yuv(&rgba[..], width, height))
                    .collect::<Vec<Vec<u8>>>();
                self.encode(converted, count, width, height);

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

                if let Err(e) = self.save(count, file_path, width as u32, height as u32) {
                    error!("Failed to save video {:?}", e);
                }

                {
                    self.recording_info
                        .lock()
                        .unwrap()
                        .set_writing_state(WritingState::Idle);
                }
                self.mark_writing_state_on_ui(call.isolate).await;

                // pool.shutdown_timeout(std::time::Duration::from_secs(1));

                info!("encoding finished");
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
                self.mark_recording_state_on_ui(call.isolate).await;
                self.channel_handler.lock().unwrap().encoding.1.close();
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
