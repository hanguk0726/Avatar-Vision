use std::{
    mem::{take, ManuallyDrop},
    sync::{Arc, Mutex},
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
use log::debug;
use nokhwa::Buffer;
use tokio::{
    runtime::{Handle, Runtime},
    task::spawn_blocking,
};

use crate::capture::decode_to_rgb;

pub struct TextureHandler {
    pub pixel_buffer: Arc<Mutex<Vec<u8>>>,
    pub receiver: Arc<AsyncReceiver<Buffer>>,
    pub texture_provider: Arc<SendableTexture<Box<dyn PixelDataProvider>>>,
    pub encoding_sender: Arc<AsyncSender<Vec<u8>>>,
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
                let (decoding_sender, decoding_receiver): (
                    Sender<Vec<u8>>,
                    Receiver<Vec<u8>>,
                ) = kanal::bounded(1);

                let decoding_sender = Arc::new(decoding_sender);

                let started = std::time::Instant::now();
                let mut count = 0;
                let pool = tokio::runtime::Builder::new_multi_thread()
                    .worker_threads(4)
                    .build()
                    .unwrap();
                let decode =
                    |buf: Buffer,
                     encoding_sender: Arc<AsyncSender<Vec<u8>>>,
                     decoding_sender: Arc<Sender<Vec<u8>>>| {
                        let time = std::time::Instant::now();
                        let mut decoded =
                            decode_to_rgb(buf.buffer(), &buf.source_frame_format(), true).unwrap();
                        debug!(
                            "decoded frame, time elapsed: {}",
                            time.elapsed().as_millis()
                        );
                        encoding_sender.try_send(decoded.clone()).unwrap();
                        decoding_sender.try_send_realtime(decoded).unwrap();
                    };

                let render = |mut decoded: Vec<u8>,
                              pixel_buffer: Arc<Mutex<Vec<u8>>>,
                              texture_provider: Arc<
                    SendableTexture<Box<dyn PixelDataProvider>>,
                >| {
                    let mut pixel_buffer = pixel_buffer.lock().unwrap();

                    *pixel_buffer = take(&mut decoded);
                    debug!(
                        "mark_frame_available, pixel_buffer: {:?}",
                        pixel_buffer.len()
                    );
                    texture_provider.mark_frame_available();
                };
                
                let runtime = Runtime::new().unwrap();
                
                let pixel_buffer = Arc::clone(&self.pixel_buffer);
                let texture_provider = Arc::clone(&self.texture_provider);
                runtime.spawn(async move {
                    while let Ok(buf) = decoding_receiver.recv() {
                        debug!("received buffer on decoding channel");
                        render(buf, pixel_buffer.clone(), texture_provider.clone());
                    }
                });
                while let Ok(buf) = self.receiver.recv().await {
                    let time = std::time::Instant::now();
                    debug!("received buffer on texture channel");
                    let encoding_sender = Arc::clone(&self.encoding_sender);
                    let decoding_sender = Arc::clone(&decoding_sender);
                    pool.spawn(async move {
                        decode(buf, encoding_sender, decoding_sender);
                    });
                    count += 1;
                    debug!(
                        "render_texture, time elapsed: {}",
                        time.elapsed().as_millis()
                    );
                }
                debug!(
                    "rendered {} frames,time elapsed {}",
                    count,
                    started.elapsed().as_secs()
                );
                let encoding_channel = self.encoding_sender.as_ref();
                // wait until  encoding_channel.len() is 0 which means all frames are encoded
                while encoding_channel.len() > 0 {
                    thread::sleep(std::time::Duration::from_millis(100));
                }
                self.encoding_sender.as_ref().close();
                runtime.shutdown_timeout(Duration::from_secs(1));
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
