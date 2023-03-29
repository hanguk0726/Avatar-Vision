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
pub struct RenderingHandler {
    pub texture_provider: Arc<SendableTexture<Box<dyn PixelDataProvider>>>,
    pub rendering: Arc<AtomicBool>
}

#[async_trait(?Send)]
impl AsyncMethodHandler for RenderingHandler {
    async fn on_method_call(&self, call: MethodCall) -> PlatformResult {
        match call.method.as_str() {
            "start_rendering" => {
                debug!(
                    "Received request {:?} on thread {:?}",
                    call,
                    thread::current().id()
                );

                self.rendering.store(true, std::sync::atomic::Ordering::Relaxed);

                let texture_provider = Arc::clone(&self.texture_provider);

                loop{
                    thread::sleep(std::time::Duration::from_millis(16)); // 60fps = 16.666ms
                    texture_provider.mark_frame_available();
                    if !self.rendering.load(std::sync::atomic::Ordering::Relaxed){
                        break;
                    }
                }

                info!("rendering finished");
                Ok("ok".into())
            }
            "stop_rendering_stream" => {
                self.rendering.store(false, std::sync::atomic::Ordering::Relaxed);
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

pub(crate) fn init(rendering_handler: RenderingHandler) {
    thread::spawn(|| {
        let _ = ManuallyDrop::new(rendering_handler.register("rendering_channel_background_thread"));
        debug!(
            "Running RunLoop on background thread {:?}",
            thread::current().id()
        );
        RunLoop::current().run();
    });
}
