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
use kanal::{AsyncReceiver, AsyncSender, Receiver, Sender};
use log::{debug, info};
use nokhwa::Buffer;

use crate::{channel::ChannelHandler, domain::image_processing::decode_to_rgb};
pub struct TextureHandler {
    pub pixel_buffer: Arc<Mutex<Vec<u8>>>,
    pub channel_handler: Arc<Mutex<ChannelHandler>>,
    pub recording: Arc<AtomicBool>,
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

                let render_buffer: Arc<Mutex<(usize, Vec<u8>)>> = Arc::new(Mutex::new((0, vec![])));

                let decode =
                    move |index: usize,
                          buf: Buffer,
                          render_buffer: Arc<Mutex<(usize, Vec<u8>)>>| {
                        let decoded =
                            decode_to_rgb(buf.buffer(), &buf.source_frame_format(), true).unwrap();
                        let mut render_buffer = render_buffer.lock().unwrap();
                        debug!("index {}, last {}", index, render_buffer.0);
                        if index > render_buffer.0 {
                            *render_buffer = (index, decoded.clone());
                        }
                    };

                let receiver = self.channel_handler.lock().unwrap().rendering.1.clone();

                let pool = tokio::runtime::Builder::new_multi_thread()
                    .worker_threads(4)
                    .build()
                    .unwrap();

                let mut index = 0;
                while let Ok(buf) = receiver.recv() {
                    let render_buffer = render_buffer.clone();
                    let render_buffer2 = render_buffer.clone();
                    index += 1;
                    pool.spawn(async move {
                        decode(index, buf, render_buffer);
                    });

                    let render = render_buffer2.lock().unwrap();
                    let decoded = render.1.to_owned();
                    
                    if self.recording.load(std::sync::atomic::Ordering::Relaxed) {
                        encoding_sender
                        .try_send(decoded.clone())
                        .unwrap_or_else(|e| {
                            debug!("encoding channel sending failed: {:?}", e);
                            false
                        });
                    }
                    
                    let mut pixel_buffer = self.pixel_buffer.lock().unwrap();
                    *pixel_buffer = decoded;
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
