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
    encoding::{encode_to_h264, rgba_to_yuv, to_mp4},
};

pub struct EncodingHandler {
    pub encodig_receiver: Arc<AsyncReceiver<Vec<u8>>>,
    pub encoded: Arc<Mutex<Vec<u8>>>,
    pub processing: Arc<AtomicBool>,
    pub frame_rate: Arc<Mutex<u32>>,
    pub audio: Arc<Mutex<Pcm>>,
}

impl EncodingHandler {
    pub fn new(
        encodig_receiver: Arc<AsyncReceiver<Vec<u8>>>,
        frame_rate: Arc<Mutex<u32>>,
        audio: Arc<Mutex<Pcm>>,
    ) -> Self {
        Self {
            encodig_receiver,
            encoded: Arc::new(Mutex::new(Vec::new())),
            processing: Arc::new(AtomicBool::new(false)),
            frame_rate,
            audio,
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
        let frame_rate = *self.frame_rate.lock().unwrap();
        let audio = Arc::clone(&self.audio);
        let audio = audio.lock().unwrap();
        let audio_data = audio.data.lock().unwrap();
        debug!(
            "audio : {}, {}, {}, {},",
            &audio_data.len(),
            &audio.sample_rate,
            &audio.channels,
            &audio.bit_rate
        );

        to_mp4(&encoded[..], "test", frame_rate, &audio).unwrap();
        debug!("*********** saved! ***********");
        self.set_processing(false);
        Ok(())
    }

    fn set_processing(&self, processing: bool) {
        self.processing
            .store(processing, std::sync::atomic::Ordering::Relaxed);
    }
}
#[async_trait(?Send)]
impl AsyncMethodHandler for EncodingHandler {
    async fn on_method_call(&self, call: MethodCall) -> PlatformResult {
        match call.method.as_str() {
            "start_encoding" => {
                debug!(
                    "Received request {:?} on thread {:?}",
                    call,
                    thread::current().id()
                );
                self.set_processing(true);
                let started = std::time::Instant::now();
                let mut count = 0;
                let yuv_data = Arc::new(Mutex::new(Vec::new()));

                let pool = tokio::runtime::Builder::new_multi_thread()
                    .worker_threads(4)
                    .build()
                    .unwrap();

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
            _ => Err(PlatformError {
                code: "invalid_method".into(),
                message: Some(format!("Unknown Method: {}", call.method)),
                detail: Value::Null,
            }),
        }
    }
}

pub fn init(encoding_handler: EncodingHandler) {
    thread::spawn(|| {
        let _ = ManuallyDrop::new(encoding_handler.register("encoding_channel_background_thread"));
        debug!(
            "Running RunLoop on background thread {:?}",
            thread::current().id()
        );
        RunLoop::current().run();
    });
}
