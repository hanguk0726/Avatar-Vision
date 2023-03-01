use std::sync::Arc;

use flume::Sender;
use log::debug;
use nokhwa::{Buffer, CallbackCamera};

use crate::capture::inflate_camera_conection;

pub struct TestCamera {
    pub sender: Arc<Sender<Buffer>>,
    pub camera: Option<CallbackCamera>,
}

impl TestCamera {
    pub fn new(sender: Arc<Sender<Buffer>>) -> Self {
        Self {
            sender,
            camera: None,
        }
    }

    pub fn infate_camera(&mut self) {
        if let Ok(mut camera) = inflate_camera_conection(self.sender.clone()) {
            self.camera = Some(camera);
        } else {
            debug!("Failed to inflate camera");
        }
    }

    pub fn open_camera_stream(&mut self) {
        if let Some(mut camera) = self.camera.take() {
            if let Err(_) = camera.open_stream() {
                debug!("Failed to open camera");
            } else {
                debug!("camera opened");
            }
            self.camera = Some(camera);
        } else {
            debug!("Failed to open camera");
        }
    }

    pub fn stop_camera_stream(&mut self) {
        if let Some(mut camera) = self.camera.take() {
           
            if let Err(e) = camera.stop_stream() {
                debug!("Failed to close camera {:?}", e);
                drop(camera)
            } else {
                debug!("camera closed");
            }
        } else {
            debug!("Failed to open camera");
        }
    }
}
