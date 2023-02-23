use std::{
    mem::ManuallyDrop,
    sync::{Arc, Mutex},
    thread,
    time::Duration,
};

use async_trait::async_trait;
use irondash_message_channel::{
    AsyncMethodHandler, IntoValue, MethodCall, PlatformError, PlatformResult, TryFromValue, Value,
};
use irondash_run_loop::RunLoop;
use irondash_texture::{PixelDataProvider, SendableTexture};
use log::debug;

pub struct TextureHandler {
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
                let texture_provider = self.texture_provider.clone();
                loop {
                    debug!("mark_frame_available");
                    texture_provider.mark_frame_available();
                    RunLoop::current().wait(Duration::from_millis(4)).await;
                }
            }
            _ => Err(PlatformError {
                code: "invalid_method".into(),
                message: Some(format!("Unknown Method: {}", call.method)),
                detail: Value::Null,
            }),
        }
    }
}

pub(crate) fn init(textrueHandler: TextureHandler) {
    // create TextureHandler instance that will listen on main (platform) thread.
    // let _ = ManuallyDrop::new(TextureHandler {}.register("texture_handler_channel"));

    // create background thread and new TextureHandler instance that will listen
    // on background thread (using different channel).
    thread::spawn(|| {
        let _ =
            ManuallyDrop::new(textrueHandler.register("texture_handler_channel_background_thread"));
        debug!(
            "Running RunLoop on background thread {:?}",
            thread::current().id()
        );
        RunLoop::current().run();
    });
}
