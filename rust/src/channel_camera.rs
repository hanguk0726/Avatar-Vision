use std::{cell::RefCell, mem::ManuallyDrop, thread};

use async_trait::async_trait;
use irondash_message_channel::{
    AsyncMethodHandler, MethodCall, PlatformError, PlatformResult, Value,
};
use irondash_run_loop::RunLoop;
use log::debug;

use crate::camera::Camera;

pub struct CameraHandler {
    pub camera: RefCell<Camera>,
}

#[async_trait(?Send)]
impl AsyncMethodHandler for CameraHandler {
    async fn on_method_call(&self, call: MethodCall) -> PlatformResult {
        match call.method.as_str() {
            "open_camera_stream" => {
                debug!(
                    "Received request {:?} on thread {:?}",
                    call,
                    thread::current().id()
                );
                let mut camera = self.camera.borrow_mut();
                camera.infate_camera();
                camera.open_camera_stream();
                Ok("ok".into())
            }
            "stop_camera_stream" => {
                debug!(
                    "Received request {:?} on thread {:?}",
                    call,
                    thread::current().id()
                );
                let mut camera = self.camera.borrow_mut();
                camera.stop_camera_stream();
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

pub fn init(camera_handler: CameraHandler) {
    thread::spawn(|| {
        let _ = ManuallyDrop::new(camera_handler.register("camera_channel_background_thread"));
        debug!(
            "Running RunLoop on background thread {:?}",
            thread::current().id()
        );
        RunLoop::current().run();
    });
}
