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
    pub frame_rate: Arc<Mutex<u32>>,
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

                let started = std::time::Instant::now();
                let mut count = 0usize;

                let decoded_vec: Arc<Mutex<Vec<(usize, Vec<u8>)>>> =
                    Arc::new(Mutex::new(Vec::new()));

                let decode =
                    |count: usize, buf: Buffer, decoded_vec: Arc<Mutex<Vec<(usize, Vec<u8>)>>>| {
                        let time = std::time::Instant::now();
                        let mut decoded =
                            decode_to_rgb(buf.buffer(), &buf.source_frame_format(), true).unwrap();
                        debug!(
                            "decoded frame, time elapsed: {}",
                            time.elapsed().as_millis()
                        );
                        // self.encoding_sender
                        //     .try_send(decoded.clone())
                        //     .unwrap_or_else(|_| {
                        //         debug!("encoding channel is full, drop frame");
                        //         false
                        //     });

                        // self.render_texture(&mut decoded);
                        let mut vec_ = decoded_vec.lock().unwrap();
                        let index_to_insert =
                            match vec_.binary_search_by_key(&count, |&(index, _)| index) {
                                Ok(index) | Err(index) => index, // if the key is found or not found, use the returned index
                            };

                        vec_.insert(index_to_insert, (count, decoded));
                    };
                let pool = tokio::runtime::Builder::new_multi_thread()
                    .worker_threads(4)
                    .build()
                    .unwrap();

                while let Ok(buf) = self.receiver.recv().await {
                    let time = std::time::Instant::now();
                    debug!("received buffer on texture channel");
                    let decoded_vec_ = Arc::clone(&decoded_vec);
                    // decode(buf);
                    pool.spawn(async move {
                        decode(count, buf, decoded_vec_);
                    });
                    count += 1;
                    debug!(
                        "render_texture, time elapsed: {}",
                        time.elapsed().as_millis()
                    );
                    let decoded_vec = decoded_vec.lock().unwrap();
                    if let Some((_, data)) = decoded_vec.last() {
                        self.encoding_sender
                            .try_send(data.clone())
                            .unwrap_or_else(|_| {
                                debug!("encoding channel is full, drop frame");
                                false
                            });
                        self.render_texture(&mut data.clone());
                    }
                }
                debug!(
                    "rendered {} frames,time elapsed {}",
                    count,
                    started.elapsed().as_secs()
                );

                let frame_rate = count as f64 / started.elapsed().as_secs_f64();
                *self.frame_rate.lock().unwrap() = frame_rate as u32;

                debug!("frame rate: {}", frame_rate);
                let encoding_channel = self.encoding_sender.as_ref();
                // wait until  encoding_channel.len() is 0 which means all frames are encoded
                while encoding_channel.len() > 0 {
                    thread::sleep(std::time::Duration::from_millis(100));
                }
                self.encoding_sender.as_ref().close();
                // runtime.shutdown_timeout(Duration::from_secs(1));
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
