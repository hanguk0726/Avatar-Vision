use kanal::{AsyncSender};
use std::sync::Arc;

use log::debug;
use nokhwa::{Buffer, CallbackCamera};

use crate::{capture::inflate_camera_conection};

pub struct Camera {
    pub rendering_sender: Option<Arc<AsyncSender<Buffer>>>,
    pub camera: Option<CallbackCamera>,
}

impl Camera {
    pub fn new(
        rendering_sender: Option<Arc<AsyncSender<Buffer>>>,
    ) -> Self {
        Self {
            rendering_sender,
            camera: None,
        }
    }
    pub fn infate_camera(&mut self) {
        let rendering_sender = self.rendering_sender.take().unwrap();
        if let Ok(camera) = inflate_camera_conection(
            rendering_sender,
        ) {
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
        if let Some(camera) = self.camera.take() {
            drop(camera);
            drop(self.rendering_sender.take());
        } else {
            debug!("Failed to stop camera stream");
        }
    }
}
