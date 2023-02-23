use std::{mem::ManuallyDrop, thread, time::Duration, sync::Arc};

use async_trait::async_trait;
use flume::Sender;
use irondash_message_channel::{
    AsyncMethodHandler,  MethodCall, PlatformError, PlatformResult, Value,
};
use irondash_run_loop::RunLoop;
use log::debug;
use nokhwa::Buffer;

use crate::{
    capture::{inflate_camera_conection},
};

pub struct CaptureHandler {
    pub sender: Arc<Sender<Vec<u8>>>
}

#[async_trait(?Send)]
impl AsyncMethodHandler for CaptureHandler {
    async fn on_method_call(&self, call: MethodCall) -> PlatformResult {
        match call.method.as_str() {
            "open_camera_stream" => {
                debug!(
                    "Received request {:?} on thread {:?}",
                    call,
                    thread::current().id()
                );
                if let Ok(mut camera) = inflate_camera_conection(self.sender.clone()) {
                    match camera.open_stream() {
                        Ok(_) => println!("Opened Stream"),
                        Err(_) => println!("Failed to Open Stream"),
                    }
                    loop {}
                } else {
                    debug!("Failed to inflate camera");
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

pub(crate) fn init(captureHandler:CaptureHandler) {
    thread::spawn(|| {
        let _ = ManuallyDrop::new(captureHandler.register("captrue_channel_background_thread"));
        debug!(
            "Running RunLoop on background thread {:?}",
            thread::current().id()
        );
        RunLoop::current().run();
    });
}
