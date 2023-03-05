use std::{
    mem::ManuallyDrop,
    sync::{Arc, Mutex, atomic::AtomicBool},
    thread,
};

use async_trait::async_trait;
use irondash_message_channel::{
    AsyncMethodHandler, MethodCall, PlatformError, PlatformResult, Value,
};
use irondash_run_loop::RunLoop;
use kanal::Receiver;
use log::{debug, error};
use nokhwa::Buffer;

use crate::{
    capture::decode,
    encoding::{encode_to_h264, encoder, to_mp4},
};

pub struct EncodingHandler {
    pub encodig_receiver: Arc<Receiver<Buffer>>,
    pub encoded: Arc<Mutex<Vec<u8>>>,
    pub processing: Arc<AtomicBool>,
}

impl EncodingHandler {
    pub fn new(encodig_receiver: Arc<Receiver<Buffer>>) -> Self {
        Self {
            encodig_receiver,
            encoded: Arc::new(Mutex::new(Vec::new())),
            processing: Arc::new(AtomicBool::new(false)),
        }
    }
    fn encode(&self, decoded_frame: &[u8]) {
        let mut encoder = encoder(1280, 720).unwrap();
        let encoded = Arc::clone(&self.encoded);
        let mut encoded = encoded.lock().unwrap();
        encode_to_h264(&mut encoder, decoded_frame, &mut encoded);
        debug!("encoded length: {:?}", encoded.len());
    }

    fn save(&self) -> Result<(), std::io::Error> {
        debug!("*********** saving... ***********");
        let encoded = Arc::clone(&self.encoded);
        let encoded = encoded.lock().unwrap();
        to_mp4(&encoded[..], "test.mp4").unwrap();
        debug!("*********** saved! ***********");
        self.set_processing(false);
        Ok(())
    }

    fn set_processing(&self, processing: bool) {
        self.processing.store(processing, std::sync::atomic::Ordering::Relaxed);
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

                let mut count = 0;
                while let Ok(buf) = self.encodig_receiver.recv() {
                    debug!("received buffer");
                    let decoded = decode(buf.buffer(), &buf.source_frame_format()).unwrap();
                    self.encode(&decoded[..]);
                    count += 1;
                }
                debug!("encoded {} frames", count);

                if let Err(e) = self.save() {
                    error!("Failed to save video {:?}", e);
                }

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
