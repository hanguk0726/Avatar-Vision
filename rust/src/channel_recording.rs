use std::{
    mem::ManuallyDrop,
    sync::{Arc, Mutex},
    thread,
};

use async_trait::async_trait;
use irondash_message_channel::{
    AsyncMethodHandler, AsyncMethodInvoker, IntoValue, IsolateId, Late, MethodCall, PlatformError,
    PlatformResult, Value,
};
use irondash_run_loop::RunLoop;

use log::{debug, error, info};
use tokio::runtime::Runtime;

use crate::{
    channel::ChannelHandler,
    channel_audio::Pcm,
    domain::image_processing::rgba_to_yuv,
    recording::{encode_to_h264, to_mp4, RecordingInfo},
    tools::ordqueue::{new, OrdQueueIter},
};

pub struct RecordingHandler {
    pub encoded: Arc<Mutex<Vec<u8>>>,
    pub audio: Arc<Mutex<Pcm>>,
    pub recording_info: Arc<Mutex<RecordingInfo>>,
    pub channel_handler: Arc<Mutex<ChannelHandler>>,
    invoker: Late<AsyncMethodInvoker>,
}

#[derive(IntoValue)]
struct State {
    state: bool,
}

impl RecordingHandler {
    pub fn new(
        audio: Arc<Mutex<Pcm>>,
        recording_info: Arc<Mutex<RecordingInfo>>,
        channel_handler: Arc<Mutex<ChannelHandler>>,
    ) -> Self {
        Self {
            encoded: Arc::new(Mutex::new(Vec::new())),
            audio,
            recording_info,
            channel_handler,
            invoker: Late::new(),
        }
    }

    fn encode(&self, yuv_iter: OrdQueueIter<Vec<u8>>, len: usize) {
        let processed = encode_to_h264(yuv_iter, len);

        let encoded = Arc::clone(&self.encoded);
        let mut encoded = encoded.lock().unwrap();
        *encoded = processed;

        debug!("encoded length: {:?}", encoded.len());
    }

    async fn mark_writing_state_on_ui(&self, target_isolate: IsolateId) {
        let recording_info = self.recording_info.lock().unwrap();
        let writing_state = recording_info
            .writing_state
            .load(std::sync::atomic::Ordering::Relaxed);

        if let Err(e) = self
            .invoker
            .call_method(
                target_isolate,
                "mark_writing_state",
                State {
                    state: writing_state,
                },
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
            .call_method(
                target_isolate,
                "mark_recording_state",
                State { state: recording },
            )
            .await
        {
            error!("Error while marking recording state on UI: {:?}", e);
        }
    }

    fn save(&self, frames: usize) -> Result<(), std::io::Error> {
        debug!("*********** saving... ***********");

        let encoded = Arc::clone(&self.encoded);
        let encoded = encoded.lock().unwrap();

        let recording_info = self.recording_info.lock().unwrap();
        let frame_rate = recording_info.frame_rate(frames);

        let audio = Arc::clone(&self.audio);
        let audio = audio.lock().unwrap();
        let audio = audio.to_owned();
        to_mp4(&encoded[..], "test", frame_rate, audio).unwrap();
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

                self.audio.lock().unwrap().data.lock().unwrap().clear();

                let started = std::time::Instant::now();
                let mut count = 0;

                let num_worker = if num_cpus::get() >= 16 { 4 } else { 2 };
                let (queue, iter) = new();
                let queue = Arc::new(queue);
                let pool = tokio::runtime::Builder::new_multi_thread()
                    .worker_threads(num_worker)
                    .build()
                    .unwrap();

                {
                    let mut recording_info = self.recording_info.lock().unwrap();
                    recording_info.start();
                }
                self.mark_recording_state_on_ui(call.isolate).await;

                let encoding_receiver = self.channel_handler.lock().unwrap().encoding.1.clone();
                while let Ok(rgba) = encoding_receiver.recv().await {
                    let queue = queue.clone();
                    pool.spawn(async move {
                        let width = 1280;
                        let height = 720;
                        let yuv = rgba_to_yuv(&rgba[..], width, height);
                        queue.push(count, yuv).unwrap();
                    });
                    // debug!("encoded {} frames", count);
                    count += 1;
                }

                self.encode(iter, count);

                debug!(
                    "encoded {} frames, time elapsed {}",
                    count,
                    started.elapsed().as_secs()
                );
                {
                    self.recording_info.lock().unwrap().set_writing_state(true);
                }
                self.mark_writing_state_on_ui(call.isolate).await;

                if let Err(e) = self.save(count) {
                    error!("Failed to save video {:?}", e);
                }

                {
                    self.recording_info.lock().unwrap().set_writing_state(false);
                }
                self.mark_writing_state_on_ui(call.isolate).await;

                pool.shutdown_timeout(std::time::Duration::from_secs(1));

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
