use kanal::Sender;
use std::sync::Arc;

use log::debug;
use nokhwa::{Buffer, CallbackCamera};

use crate::capture::{inflate_camera_conection};

pub struct Camera {
    pub rendering_sender: Option<Arc<Sender<Buffer>>>,
    pub encoding_sender: Option<Arc<Sender<Buffer>>>,
    pub camera: Option<CallbackCamera>,
    pub frame_rates: [f64; 30],
}

impl Camera {
    pub fn new(
        rendering_sender: Option<Arc<Sender<Buffer>>>,
        encoding_sender: Option<Arc<Sender<Buffer>>>,
    ) -> Self {
        Self {
            rendering_sender,
            encoding_sender,
            camera: None,
            frame_rates: [0.0; 30],
        }
    }
    pub fn infate_camera(&mut self) {
        let rendering_sender = self.rendering_sender.take().unwrap();
        let encoding_sender = self.encoding_sender.take().unwrap();
        if let Ok(camera) =
            inflate_camera_conection(rendering_sender, encoding_sender, self.frame_rates)
        {
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
                debug!("Failed to close camera{:?}", e);
                drop(camera);
                drop(self.rendering_sender.take());
                drop(self.encoding_sender.take());
            } else {
                debug!("camera closed");
            }
        } else {
            debug!("Failed to open camera");
        }
    }
}
