use std::{
    borrow::BorrowMut,
    cell::RefCell,
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
use log::{debug, info};
use nokhwa::Buffer;

use crate::{channel::ChannelHandler, domain::image_processing::decode_to_rgb};

pub struct TextureHandler {
    pub pixel_buffer: Arc<Mutex<Vec<u8>>>,
    pub channel_handler: Arc<Mutex<ChannelHandler>>,
    pub texture_provider: Arc<SendableTexture<Box<dyn PixelDataProvider>>>,
    pub recording: Arc<AtomicBool>,
}

impl TextureHandler {
    fn render_texture(&self, decoded_frame: &mut Vec<u8>) {
        let mut pixel_buffer = self.pixel_buffer.lock().unwrap();

        *pixel_buffer = take(decoded_frame);
        if pixel_buffer.len() == 0 {
            log::error!("pixel_buffer is empty")
        }
        self.texture_provider.mark_frame_available();
    }

    fn handle_encoding(&self, frame: Vec<u8>) {}
}

#[async_trait(?Send)]
impl AsyncMethodHandler for TextureHandler {
    async fn on_method_call(&self, call: MethodCall) -> PlatformResult {
        match call.method.as_str() {
            "open_texture_stream" => {
                debug!(
                    "Received request {:?} on thread {:?}",
                    call,
                    thread::current().id()
                );

                let encoding_sender = self.channel_handler.lock().unwrap().encoding.0.clone();

                let decode = |buf: Buffer| {
                    let mut decoded =
                        decode_to_rgb(buf.buffer(), &buf.source_frame_format(), true).unwrap();
                    if self.recording.load(std::sync::atomic::Ordering::Relaxed) {
                        encoding_sender
                            .try_send(decoded.clone())
                            .unwrap_or_else(|e| {
                                debug!("encoding channel sending failed: {:?}", e);
                                false
                            });
                    }

                    self.render_texture(&mut decoded);
                };

                let receiver = self.channel_handler.lock().unwrap().rendering.1.clone();
                
                while let Ok(buf) = receiver.recv() {
                    decode(buf);
                }

                info!("render_texture finished");
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
