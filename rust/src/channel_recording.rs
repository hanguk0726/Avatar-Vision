use std::{
    mem::ManuallyDrop,
    sync::{atomic::AtomicBool, Arc, Mutex},
    thread,
};

use async_trait::async_trait;
use irondash_message_channel::{
    AsyncMethodHandler, MethodCall, PlatformError, PlatformResult, Value,
};
use irondash_run_loop::RunLoop;
use kanal::AsyncReceiver;
use log::{debug, error};

use crate::{
    channel_audio::Pcm,
    recording::{encode_to_h264, rgba_to_yuv, to_mp4, RecordingInfo},
};

pub struct RecordingHandler {
    pub encodig_receiver: Arc<AsyncReceiver<Vec<u8>>>,
    pub encoded: Arc<Mutex<Vec<u8>>>,
    pub audio: Arc<Mutex<Pcm>>,
    pub recording_info: Arc<Mutex<RecordingInfo>>,
}

impl RecordingHandler {
    pub fn new(
        encodig_receiver: Arc<AsyncReceiver<Vec<u8>>>,
        audio: Arc<Mutex<Pcm>>,
        recording_info: Arc<Mutex<RecordingInfo>>,
    ) -> Self {
        Self {
            encodig_receiver,
            encoded: Arc::new(Mutex::new(Vec::new())),
            audio,
            recording_info,
        }
    }

    fn encode(&self, yuv_vec: Vec<Vec<u8>>) {
        let processed = encode_to_h264(yuv_vec);

        let encoded = Arc::clone(&self.encoded);
        let mut encoded = encoded.lock().unwrap();
        *encoded = processed;

        debug!("encoded length: {:?}", encoded.len());
    }

    fn save(&self) -> Result<(), std::io::Error> {
        debug!("*********** saving... ***********");
        let encoded = Arc::clone(&self.encoded);
        let encoded = encoded.lock().unwrap();

        let recording_info = self.recording_info.lock().unwrap();
        let frame_rate = recording_info.frame_rate(encoded.len());

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
    async fn on_method_call(&self, call: MethodCall) -> PlatformResult {
        match call.method.as_str() {
            "start_recoding" => {
                debug!(
                    "Received request {:?} on thread {:?}",
                    call,
                    thread::current().id()
                );
                let started = std::time::Instant::now();
                let mut count = 0;
                let yuv_data = Arc::new(Mutex::new(Vec::new()));

                let pool = tokio::runtime::Builder::new_multi_thread()
                    .worker_threads(4)
                    .build()
                    .unwrap();

                let mut recording_info = self.recording_info.lock().unwrap();
                recording_info.start();

                while let Ok(rgba) = self.encodig_receiver.recv().await {
                    debug!("received buffer");
                    let started = std::time::Instant::now();
                    count += 1;
                    let yuv_data_clone = yuv_data.clone();
                    pool.spawn(async move {
                        let width = 1280;
                        let height = 720;
                        let yuv = rgba_to_yuv(&rgba[..], width, height);
                        let mut yuv_data = yuv_data_clone.lock().unwrap();
                        yuv_data.push(yuv);
                    });
                    debug!("encoded to yuv: {:?}", started.elapsed().as_millis());
                }

                self.encode(yuv_data.lock().unwrap().clone());
                debug!(
                    "encoded {} frames, time elapsed {}",
                    count,
                    started.elapsed().as_secs()
                );

                if let Err(e) = self.save() {
                    error!("Failed to save video {:?}", e);
                }
                pool.shutdown_timeout(std::time::Duration::from_secs(1));
                Ok("encoding finished".into())
            }
            "stop_recording" => {
                debug!(
                    "Received request {:?} on thread {:?}",
                    call,
                    thread::current().id()
                );

                let mut recording_info = self.recording_info.lock().unwrap();
                recording_info.recording.store(false, std::sync::atomic::Ordering::Relaxed);
                recording_info.stop();

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
