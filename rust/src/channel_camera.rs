use std::{
    cell::RefCell,
    collections::HashMap,
    mem::ManuallyDrop,
    ops::Not,
    sync::{atomic::AtomicBool, Arc, Mutex},
    thread,
};

use async_trait::async_trait;
use irondash_message_channel::{
    AsyncMethodHandler, MethodCall, PlatformError, PlatformResult, Value,
};
use irondash_run_loop::RunLoop;
use log::{debug, error};
use nokhwa::{
    query,
    utils::{ApiBackend, CameraIndex},
};

use crate::camera::Camera;

pub struct CameraHandler {
    pub rendering: Arc<AtomicBool>,
    pub camera: Arc<Mutex<Camera>>,
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
                {
                    let mut camera = self.camera.lock().unwrap();
                    let mut camera_index: Option<CameraIndex> = None;
                    {
                        let camera_info = &mut camera.current_camera_info.lock().unwrap();
                        camera_index.replace(camera_info.as_ref().unwrap().index().clone());
                    }
                    if camera_index.is_none() {
                        return PlatformResult::Err(PlatformError {
                            code: "method_failed".into(),
                            message: Some(format!("open_camera_stream failed: {}", call.method)),
                            detail: Value::Null,
                        });
                    }
                    camera.infate_camera(camera_index.unwrap());
                    camera.open_camera_stream();
                }
                let camera = self.camera.clone();
                let rendering = self.rendering.clone();
                thread::spawn(move || {
                    while rendering.load(std::sync::atomic::Ordering::Relaxed) {
                        let camera = camera.clone();
                        let mut camera = camera.lock().unwrap();
                        if camera.health_check().not() {
                            error!("camera health check failed"); // TODO: call method on Flutter to handle the error
                            break;
                        }
                        std::thread::sleep(std::time::Duration::from_millis(1000));
                    }
                });
                return PlatformResult::Ok("ok".into());
            }
            "stop_camera_stream" => {
                debug!(
                    "Received request {:?} on thread {:?}",
                    call,
                    thread::current().id()
                );
                let mut camera = self.camera.lock().unwrap();
                camera.stop_camera_stream();
                Ok("ok".into())
            }

            "select_camera_device" => {
                debug!(
                    "Received request {:?} on thread {:?}",
                    call,
                    thread::current().id()
                );
                let mut camera = self.camera.lock().unwrap();
                let map: HashMap<String, String> = call.args.try_into().unwrap();
                let camera_name = map.get("device_name").unwrap().as_str();
                let cameras = query(ApiBackend::Auto).unwrap();
                if let Some(camera_info) = cameras.iter().find(|c| c.human_name() == camera_name) {
                    let mut current_camera_info = camera.current_camera_info.lock().unwrap();
                    current_camera_info.replace(camera_info.clone());
                    return PlatformResult::Ok("ok".into());
                }
                PlatformResult::Err(PlatformError {
                    code: "method_failed".into(),
                    message: Some(format!("select_camera_device failed: {}", call.method)),
                    detail: Value::Null,
                })
            }
            "available_cameras" => {
                debug!(
                    "Received request {:?} on thread {:?}",
                    call,
                    thread::current().id()
                );
                let cameras = query(ApiBackend::Auto).unwrap();
                let camera_names: Vec<String> =
                    cameras.iter().map(|c| c.human_name().clone()).collect();
                debug!("available_cameras: {:?}", camera_names);
                Ok(camera_names.into())
            }

            "current_camera_device" => {
                debug!(
                    "Received request {:?} on thread {:?}",
                    call,
                    thread::current().id()
                );

                let mut camera = self.camera.lock().unwrap();
                let camera_info = &mut camera.current_camera_info.lock().unwrap();
                match camera_info.as_ref() {
                    Some(camera_info) => Ok(camera_info.human_name().into()),
                    None => Ok("".into()),
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
