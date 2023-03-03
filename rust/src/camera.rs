use futures_signals::signal::Mutable;
use futures_signals::signal::SignalExt;
use std::{
    cell::RefCell,
    sync::{Arc, Mutex},
};

use flume::Sender;
use log::{debug, error};
use nokhwa::{Buffer, CallbackCamera};

use crate::{
    capture::{decode, inflate_camera_conection},
    encoding::{encode_to_h264, encoder, to_mp4},
};

pub struct Camera {
    pub sender: Arc<Sender<Buffer>>,
    pub camera: Option<CallbackCamera>,
    pub frame_rates: [f64; 30],
}

impl Camera {
    pub fn new(sender: Arc<Sender<Buffer>>) -> Self {
        Self {
            sender,
            camera: None,
            frame_rates: [0.0; 30],
        }
    }
    pub fn infate_camera(&mut self) {
        if let Ok(camera) = inflate_camera_conection(
            self.sender.clone(),
            self.frame_rates,
            // Arc::clone(&self.buffers),
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
        if let Some(mut camera) = self.camera.take() {
            if let Err(e) = camera.stop_stream() {
                debug!("Failed to close camera{:?}", e);
                drop(camera)
            } else {
                debug!("camera closed");
            }
        } else {
            debug!("Failed to open camera");
        }
    }
   
}
