use std::{
    mem::{take, ManuallyDrop},
    sync::{Arc, Mutex},
    thread,
};

use async_trait::async_trait;
use flume::Receiver;
use irondash_message_channel::{
    AsyncMethodHandler, IntoValue, MethodCall, PlatformError, PlatformResult, Value,
};
use irondash_run_loop::RunLoop;
use irondash_texture::{PixelDataProvider, SendableTexture};
use log::debug;
use nokhwa::Buffer;

use crate::{
    capture::decode,
    encoding::{encode_to_h264, encoder, to_mp4},
};

pub struct TextureHandler {
    pub pixel_buffer: Arc<Mutex<Vec<u8>>>,
    pub receiver: Arc<Receiver<Buffer>>,
    pub texture_provider: Arc<SendableTexture<Box<dyn PixelDataProvider>>>,
    pub encoded: Arc<Mutex<Vec<u8>>>,
}

#[derive(IntoValue)]
struct ThreadInfo {
    thread_id: String,
    is_main_thread: bool,
}

#[derive(IntoValue)]
struct TextureHandlerResponse {
    thread_info: ThreadInfo,
}

impl TextureHandler {
    fn render_texture(&self, decoded_frame: &mut Vec<u8>) {
        let mut pixel_buffer = self.pixel_buffer.lock().unwrap();
        *pixel_buffer = take(decoded_frame);
        debug!(
            "mark_frame_available, pixel_buffer: {:?}",
            pixel_buffer.len()
        );
        self.texture_provider.mark_frame_available();
    }
    fn encode(&self, decoded_frame: &[u8]) {
        let mut encoder = encoder(1280, 720).unwrap();
        let encoded = Arc::clone(&self.encoded);
        let mut encoded = encoded.lock().unwrap();
        encode_to_h264(&mut encoder, decoded_frame, &mut encoded);
        debug!("encoded length: {:?}", encoded.len());
    }
}
#[async_trait(?Send)]
impl AsyncMethodHandler for TextureHandler {
    async fn on_method_call(&self, call: MethodCall) -> PlatformResult {
        match call.method.as_str() {
            "render_texture" => {
                debug!(
                    "Received request {:?} on thread {:?}",
                    call,
                    thread::current().id()
                );
                // The receiver will be automatically dropped when sender get removed
                rayon::scope(|s| {
                    s.spawn(|_| {
                        while let Ok(buf) = self.receiver.recv() {
                            debug!("received buffer");
                            let mut decoded = decode(buf.buffer(), &buf.source_frame_format()).unwrap();
                            self.render_texture(&mut decoded)
                        }
                    });
                    s.spawn(|_| {
                        while let Ok(buf) = self.receiver.recv() {
                            debug!("received buffer");
                            let decoded = decode(buf.buffer(), &buf.source_frame_format()).unwrap();
                            self.encode(&decoded[..])
                        }
                    });
                });
                Ok("render_texture finished".into())
            }
            _ => Err(PlatformError {
                code: "invalid_method".into(),
                message: Some(format!("Unknown Method: {}", call.method)),
                detail: Value::Null,
            }),
        }
    }
}

pub(crate) fn init(textrue_handler: TextureHandler) {
    thread::spawn(|| {
        let _ = ManuallyDrop::new(
            textrue_handler.register("texture_handler_channel_background_thread"),
        );
        debug!(
            "Running RunLoop on background thread {:?}",
            thread::current().id()
        );
        RunLoop::current().run();
    });
}
// async fn observable_encoding_frames_eagerly(&mut self) {
//     let camera = self.camera.as_ref().unwrap();
//     let frame_format = camera.frame_format().unwrap();
//     let mut encoder = encoder(1280, 720).unwrap();
//     let future = self.buffers.signal_cloned().for_each(|buffers| {
//         debug!("buffers len: {}", buffers.len());

//         // consume all quque & encode
//         while let Some(buf) = buffers.iter().take_while(|x| x.len() > 0).next() {
//             let frame = decode(&buf, &frame_format).unwrap();
//             encode_to_h264(&mut encoder, &frame, &mut self.encoded);
//         }

//         async {}
//     });
//     future.await
// }
// if let Err(e) = self.save() {
//     error!("Failed to save video {:?}", e);
// }
// fn save(&mut self) -> Result<(), std::io::Error> {
//     debug!("*********** saving... ***********");

//     to_mp4(&mut self.encoded, "test.mp4").unwrap();
//     debug!("*********** saved! ***********");
//     Ok(())
// }
