use std::{
    collections::HashMap,
    mem::ManuallyDrop,
    sync::{atomic::AtomicBool, Arc, Mutex},
    thread,
};

use async_trait::async_trait;
use irondash_message_channel::{
    AsyncMethodHandler, MethodCall, PlatformError, PlatformResult, Value,
};
use irondash_run_loop::RunLoop;
use log::debug;
use nokhwa::{
    query,
    utils::{ApiBackend, CameraIndex},
};

use crate::domain::camera::CameraService;

pub struct CameraHandler {
    pub rendering: Arc<AtomicBool>,
    pub camera_service: Arc<Mutex<CameraService>>,
}

impl CameraHandler {
    pub fn new(rendering: Arc<AtomicBool>, camera: Arc<Mutex<CameraService>>) -> Self {
        Self { rendering, camera_service: camera }
    }
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
                let map: HashMap<String, String> = call.args.try_into().unwrap();
                let resolution = map.get("resolution");

                let mut camera_service = self.camera_service.lock().unwrap();
                let mut camera_index: Option<CameraIndex> = None;

                {
                    let camera_info = &mut camera_service.current_camera_info.lock().unwrap();
                    camera_index.replace(camera_info.as_ref().unwrap().index().clone());
                }

                if camera_index.is_none() {
                    return PlatformResult::Err(PlatformError {
                        code: "method_failed".into(),
                        message: Some(format!("open_camera_stream failed: {}", call.method)),
                        detail: Value::Null,
                    });
                }

                camera_service.infate_camera(camera_index.unwrap(), resolution);
                camera_service.open_camera_stream();

                return PlatformResult::Ok("ok".into());
            }

            "stop_camera_stream" => {
                debug!(
                    "Received request {:?} on thread {:?}",
                    call,
                    thread::current().id()
                );
                let mut camera_service = self.camera_service.lock().unwrap();
                camera_service.stop_camera_stream();
                Ok("ok".into())
            }

            "camera_health_check" => {
                let mut camera_service = self.camera_service.lock().unwrap();
                let (health_check, message) = camera_service.health_check();
                if health_check {
                    return PlatformResult::Ok("ok".into());
                }
                Ok(message.into())
            }

            "select_camera_device" => {
                debug!(
                    "Received request {:?} on thread {:?}",
                    call,
                    thread::current().id()
                );
                let camera_service = self.camera_service.lock().unwrap();

                let map: HashMap<String, String> = call.args.try_into().unwrap();
                let camera_name = map.get("device_name").unwrap().as_str();
                
                let cameras = query(ApiBackend::Auto).unwrap();
                if let Some(camera_info) = cameras.iter().find(|c| c.human_name() == camera_name) {
                    let mut current_camera_info = camera_service.current_camera_info.lock().unwrap();
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

            "current_resolution" => {
                debug!(
                    "Received request {:?} on thread {:?}",
                    call,
                    thread::current().id()
                );
                let camera_service = self.camera_service.lock().unwrap();

                let mut resolution = camera_service.resolution_service.get_current_resolution();
                let resolution = resolution.as_mut().to_string();

                Ok(Value::String(resolution))
            }

            "current_camera_device" => {
                debug!(
                    "Received request {:?} on thread {:?}",
                    call,
                    thread::current().id()
                );

                let camera_service = self.camera_service.lock().unwrap();

                let camera_info = &mut camera_service.current_camera_info.lock().unwrap();
                match camera_info.as_ref() {
                    Some(camera_info) => Ok(camera_info.human_name().into()),
                    None => Ok("".into()),
                }
            }
            "available_resolution" => {
                debug!(
                    "Received request {:?} on thread {:?}",
                    call,
                    thread::current().id()
                );
                let camera_service = self.camera_service.lock().unwrap();
                let list = &mut camera_service.resolution_service.get_available_resolutions();
                let list = list.to_owned();

                debug!("available_resolution: {:?}", list);
                Ok(list.into())
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
