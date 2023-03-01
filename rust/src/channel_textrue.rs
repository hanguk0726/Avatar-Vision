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
    encoding::{encode_to_h264, encoder, to_mp4}
};

pub struct TextureHandler {
    pub pixel_buffer: Arc<Mutex<Vec<u8>>>,
    pub receiver: Arc<Receiver<Buffer>>,
    pub texture_provider: Arc<SendableTexture<Box<dyn PixelDataProvider>>>,
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

                while let Ok(buf) = self.receiver.recv() { // will automatically dropped when sender get removed
                    debug!("received buffer");
                    let decoded = &mut decode(buf).unwrap();  
                    let mut pixel_buffer = self.pixel_buffer.lock().unwrap();
                    *pixel_buffer = take(decoded);
                    debug!("mark_frame_available, pixel_buffer: {:?}", pixel_buffer.len());
                    self.texture_provider.mark_frame_available();
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
    // create TextureHandler instance that will listen on main (platform) thread.
    // let _ = ManuallyDrop::new(TextureHandler {}.register("texture_handler_channel"));

    // create background thread and new TextureHandler instance that will listen
    // on background thread (using different channel).
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
