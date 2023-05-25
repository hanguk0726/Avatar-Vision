use std::{
    collections::HashMap,
    mem::ManuallyDrop,
    sync::{
        atomic::{AtomicBool, AtomicUsize},
        Arc, Mutex,
    },
    thread,
};

use async_trait::async_trait;
use irondash_message_channel::{
    AsyncMethodHandler, MethodCall, PlatformError, PlatformResult, Value,
};
use irondash_run_loop::RunLoop;

use log::{debug};
use nokhwa::Buffer;

use crate::{ tools::image_processing::decode_to_rgb, domain::channel::ChannelService,  };
pub struct TextureHandler {
    pub render_buffer: Arc<Mutex<Vec<u8>>>,
    pub channel_handler: Arc<Mutex<ChannelService>>,
    pub recording: Arc<AtomicBool>,
}
#[async_trait(?Send)]
impl AsyncMethodHandler for TextureHandler {
    async fn on_method_call(&self, call: MethodCall) -> PlatformResult {
        match call.method.as_str() {
            // decode images from webcam parrallelly using thread pool and sending it to display and encoder.

            "open_texture_stream" => {
                debug!(
                    "Received request {:?} on thread {:?}",
                    call,
                    thread::current().id()
                );
                let map: HashMap<String, String> = call.args.try_into().unwrap();
                let resolution = map.get("resolution").unwrap().as_str();
                let resolution = resolution.split("x").collect::<Vec<&str>>();
                let width = resolution[0].parse::<u32>().unwrap();
                let height = resolution[1].parse::<u32>().unwrap();

                // display only the latest image. highest index on the moment.
                let render_buffer_index: Arc<AtomicUsize> = Arc::new(AtomicUsize::new(0));

                let pool = tokio::runtime::Builder::new_multi_thread()
                    .worker_threads(8)
                    .build()
                    .unwrap();

                let receiver = self.channel_handler.lock().unwrap().rendering.1.clone();
                let recording = self.recording.clone();
                let recording_sender = self.channel_handler.lock().unwrap().recording.0.clone();

                let pixel_buffer = self.render_buffer.clone();
                let mut index = 0;

                while let Ok((buf, timestamp)) = receiver.recv() {

                    let render_buffer_index = render_buffer_index.clone();
                    let pixel_buffer = pixel_buffer.clone();

                    if recording.load(std::sync::atomic::Ordering::Relaxed) {
                        recording_sender.send((buf.clone(), timestamp)).unwrap_or_else(|e| {
                            debug!("Error sending to recording channel: {}", e)
                        });
                    }

                    index += 1;

                    pool.spawn(async move {
                        decode(index, buf, render_buffer_index, pixel_buffer, width, height);
                    });
                }
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

fn decode(
    index: usize,
    buf: Buffer,
    render_buffer: Arc<AtomicUsize>,
    pixel_buffer: Arc<Mutex<Vec<u8>>>,
    width: u32,
    height: u32,
) {
    // check if the frame is outdated
    let render_buffer_index = render_buffer.load(std::sync::atomic::Ordering::SeqCst);
    if render_buffer_index > index {
        debug!("drop frame :: outdated");
        return;
    }

    // let time = std::time::Instant::now();
    let decoded = decode_to_rgb(
        buf.buffer(),
        &buf.source_frame_format(),
        true,
        width,
        height,
    )
    .unwrap();
    // debug!("decode time {:?}", time.elapsed());
    
    let render_buffer_index = render_buffer.load(std::sync::atomic::Ordering::SeqCst);
    if index > render_buffer_index.to_owned() {
        let mut pixel_buffer = pixel_buffer.lock().unwrap();
        *pixel_buffer = decoded;
        render_buffer.store(index, std::sync::atomic::Ordering::SeqCst);
    } else {
        debug!("drop frame :: outdated");
    }
}
