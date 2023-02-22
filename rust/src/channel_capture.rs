use std::{mem::ManuallyDrop, thread, time::Duration};

use async_trait::async_trait;
use irondash_message_channel::{
    AsyncMethodHandler, IntoValue, MethodCall, PlatformError, PlatformResult, TryFromValue, Value,
};
use irondash_run_loop::RunLoop;
use log::debug;

use crate::{
    capture::{inflateCameraConection, CAPTRUE_STATE},
    textrue::TEXTURE_PROVIDER,
};

struct CaptureHandler {}

#[async_trait(?Send)]
impl AsyncMethodHandler for CaptureHandler {
    async fn on_method_call(&self, call: MethodCall) -> PlatformResult {
        match call.method.as_str() {
            // "inflate_camera_conection" => {
            //     debug!("Received request {:?} on thread {:?}",
            //         call,
            //         thread::current().id()
            //     );
            //     inflateCameraConection().unwrap();
            //     Ok("ok".into())
            // }
            "open_camera_stream" => {
                debug!(
                    "Received request {:?} on thread {:?}",
                    call,
                    thread::current().id()
                );
                if let Ok(mut camera) = inflateCameraConection() {
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

pub(crate) fn init() {
    thread::spawn(|| {
        let _ = ManuallyDrop::new(CaptureHandler {}.register("captrue_channel_background_thread"));
        debug!(
            "Running RunLoop on background thread {:?}",
            thread::current().id()
        );
        RunLoop::current().run();
    });
}
