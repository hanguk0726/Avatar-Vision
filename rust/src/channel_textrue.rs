use std::{
    mem::{take, ManuallyDrop},
    sync::{atomic::AtomicBool, Arc, Mutex},
    thread,
    time::Duration,
};

use async_trait::async_trait;
use irondash_message_channel::{
    AsyncMethodHandler, IntoValue, MethodCall, PlatformError, PlatformResult, Value,
};
use irondash_run_loop::RunLoop;
use irondash_texture::{PixelDataProvider, SendableTexture};
use kanal::{AsyncReceiver, AsyncSender, Receiver};
use log::debug;
use nokhwa::Buffer;

use crate::domain::image_processing::decode_to_rgb;

pub struct TextureHandler {
    pub pixel_buffer: Arc<Mutex<Vec<u8>>>,
    pub receiver: Arc<Receiver<Buffer>>,
    pub texture_provider: Arc<SendableTexture<Box<dyn PixelDataProvider>>>,
    pub encoding_sender: Arc<AsyncSender<Vec<u8>>>,
    pub recording: Arc<AtomicBool>,
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

    fn handle_recording(&self, frame: Vec<u8>) {
        self.encoding_sender.try_send(frame).unwrap_or_else(|_| {
            debug!("encoding channel is full, drop frame");
            false
        });
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

                let decode = |buf: Buffer| {
                    let time = std::time::Instant::now();
                    let mut decoded =
                        decode_to_rgb(buf.buffer(), &buf.source_frame_format(), true).unwrap();
                    debug!(
                        "decoded frame, time elapsed: {}",
                        time.elapsed().as_millis()
                    );

                    if self.recording.load(std::sync::atomic::Ordering::Relaxed) {
                        self.handle_recording(decoded.clone());
                    }

                    self.render_texture(&mut decoded);
                };

                while let Ok(buf) = self.receiver.recv() {
                    let time = std::time::Instant::now();
                    debug!("received buffer on texture channel");
                    decode(buf);
                    debug!(
                        "render_texture, time elapsed: {}",
                        time.elapsed().as_millis()
                    );
                }

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
        let _ = ManuallyDrop::new(textrue_handler.register("texture_channel_background_thread"));
        debug!(
            "Running RunLoop on background thread {:?}",
            thread::current().id()
        );
        RunLoop::current().run();
    });
}
