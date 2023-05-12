use std::{
    mem::ManuallyDrop,
    sync::{atomic::AtomicBool, Arc, Mutex},
    thread,
    time::Duration,
};

use async_trait::async_trait;
use irondash_message_channel::{
    AsyncMethodHandler, AsyncMethodInvoker, IsolateId, Late, MethodCall, PlatformError,
    PlatformResult, Value,
};
use irondash_run_loop::RunLoop;
use irondash_texture::{PixelDataProvider, SendableTexture};

use log::{debug, error, info};

pub struct RenderingHandler {
    pub texture: Arc<SendableTexture<Box<dyn PixelDataProvider>>>,
    pub rendering: Arc<AtomicBool>,
    invoker: Late<AsyncMethodInvoker>,
}

impl RenderingHandler {
    pub fn new(
        texture: Arc<SendableTexture<Box<dyn PixelDataProvider>>>,
        rendering: Arc<AtomicBool>,
    ) -> Self {
        Self {
            texture,
            rendering,
            invoker: Late::new(),
        }
    }

    fn mark_rendering_state_on_ui(&self, target_isolate: IsolateId) {
        let rendering = self.rendering.load(std::sync::atomic::Ordering::Relaxed);

        self.invoker.call_method_sync(
            target_isolate,
            "mark_rendering_state",
            Value::Bool(rendering),
            |_| {},
        );
    }
}

#[async_trait(?Send)]
impl AsyncMethodHandler for RenderingHandler {
    fn assign_invoker(&self, _invoker: AsyncMethodInvoker) {
        self.invoker.set(_invoker);
    }
    async fn on_method_call(&self, call: MethodCall) -> PlatformResult {
        match call.method.as_str() {
            "start_rendering" => {
                debug!(
                    "Received request {:?} on thread {:?}",
                    call,
                    thread::current().id()
                );

                self.rendering
                    .store(true, std::sync::atomic::Ordering::Relaxed);
                self.mark_rendering_state_on_ui(call.isolate);
                let texture_provider = Arc::clone(&self.texture);

                let rendering: Arc<AtomicBool> = self.rendering.clone();
                let frame_interval = Duration::from_millis(1000 / 30);
                thread::spawn(move || {
                    // avoid blocking the method channel
                    while rendering.load(std::sync::atomic::Ordering::Relaxed) {
                        thread::sleep(frame_interval);
                        texture_provider.mark_frame_available();
                    }
                });

                Ok("ok".into())
            }

            "stop_rendering" => {
                debug!(
                    "Received request {:?} on thread {:?}",
                    call,
                    thread::current().id()
                );

                self.rendering
                    .store(false, std::sync::atomic::Ordering::Relaxed);
                self.mark_rendering_state_on_ui(call.isolate);
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
        let _ =
            ManuallyDrop::new(rendering_handler.register("rendering_channel_background_thread"));
        debug!(
            "Running RunLoop on background thread {:?}",
            thread::current().id()
        );
        RunLoop::current().run();
    });
}
