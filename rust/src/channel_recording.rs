use std::{
    mem::ManuallyDrop,
    ops::Not,
    sync::{atomic::AtomicBool, Arc, Mutex},
    thread,
};

use async_trait::async_trait;
use irondash_message_channel::{
    AsyncMethodHandler, MethodCall, PlatformError, PlatformResult, Value,
};
use irondash_run_loop::RunLoop;
use kanal::AsyncReceiver;
use log::{debug, error, info};

use crate::{
    channel::ChannelHandler,
    channel_audio::Pcm,
    recording::{encode_to_h264, rgba_to_yuv, to_mp4, RecordingInfo},
};

pub struct RecordingHandler {
    pub encoded: Arc<Mutex<Vec<u8>>>,
    pub audio: Arc<Mutex<Pcm>>,
    pub recording_info: Arc<Mutex<RecordingInfo>>,
    pub channel_handler: Arc<Mutex<ChannelHandler>>,
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
        }
    }

    fn encode(&self, yuv_vec: Vec<Vec<u8>>) {
        let processed = encode_to_h264(yuv_vec);

        let encoded = Arc::clone(&self.encoded);
        let mut encoded = encoded.lock().unwrap();
        *encoded = processed;

        debug!("encoded length: {:?}", encoded.len());
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
                let yuv_data = Arc::new(Mutex::new(Vec::new()));

                let pool = tokio::runtime::Builder::new_multi_thread()
                    .worker_threads(4)
                    .build()
                    .unwrap();

                {
                    let mut recording_info = self.recording_info.lock().unwrap();
                    recording_info.start();
                }

                let encoding_receiver = self.channel_handler.lock().unwrap().encoding.1.clone();
                while let Ok(rgba) = encoding_receiver.recv().await {
                    debug!("received buffer");
                    count += 1;
                    let yuv_data_clone = yuv_data.clone();
                    pool.spawn(async move {
                        let width = 1280;
                        let height = 720;
                        let started = std::time::Instant::now();
                        let yuv = rgba_to_yuv(&rgba[..], width, height);
                        let mut yuv_data = yuv_data_clone.lock().unwrap();
                        debug!("encoded to yuv: {:?}", started.elapsed().as_millis());
                        yuv_data.push(yuv);
                    });
                }

                self.encode(yuv_data.lock().unwrap().to_owned());

                debug!(
                    "encoded {} frames, time elapsed {}",
                    count,
                    started.elapsed().as_secs()
                );

                if let Err(e) = self.save(count) {
                    error!("Failed to save video {:?}", e);
                }
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
                    recording_info
                        .recording
                        .store(false, std::sync::atomic::Ordering::Relaxed);
                    recording_info.stop();
                }
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
