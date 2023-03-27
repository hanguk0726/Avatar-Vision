use kanal::{AsyncSender, Sender};
use std::sync::{Arc, Mutex};

use log::{debug, error};
use nokhwa::pixel_format::RgbAFormat;
use nokhwa::utils::{CameraIndex, RequestedFormat, RequestedFormatType};
use nokhwa::{Buffer, CallbackCamera};

use std::cell::RefCell;
use std::fmt::Error;
use std::time::Instant;

pub struct Camera {
    pub rendering_sender: Option<Arc<Sender<Buffer>>>,
    pub camera: Option<CallbackCamera>,
}

impl Camera {
    pub fn new(rendering_sender: Option<Arc<Sender<Buffer>>>) -> Self {
        Self {
            rendering_sender,
            camera: None,
        }
    }
    pub fn infate_camera(&mut self) {
        let rendering_sender = self.rendering_sender.take().unwrap();
        if let Ok(camera) = inflate_camera_conection(rendering_sender) {
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
            if let Some(sender) = self.rendering_sender.take() {
                drop(sender);
            };
        } else {
            debug!("Failed to stop camera stream");
        }
    }
}

#[cfg(debug_assertions)]
static TIME_INSTANCE: Mutex<RefCell<Option<Instant>>> = Mutex::new(RefCell::new(None));

//# refactor needed
pub fn inflate_camera_conection(
    rendering_sender: Arc<Sender<Buffer>>,
) -> Result<CallbackCamera, Error> {
    let index = CameraIndex::Index(0);
    let requested =
        RequestedFormat::new::<RgbAFormat>(RequestedFormatType::AbsoluteHighestFrameRate);

    let camera = CallbackCamera::new(index, requested, move |buf| {
        debug_time_elasped();
        rendering_sender.try_send_realtime(buf).unwrap_or_else(|e| {
            error!("Error sending frame: {:?}", e);
            false
        });
    })
    .map_err(|why| {
        eprintln!("Error opening camera: {:?}", why);
        Error
    })?;
    let format = camera.camera_format().map_err(|why| {
        eprintln!("Error reading camera format: {:?}", why);
        Error
    })?;
    let camera_info = camera.info().clone();
    debug!("format :{}", format);
    debug!("camera_info :{}", camera_info);

    Ok(camera)
}

#[cfg(debug_assertions)]
fn debug_time_elasped() {
    if let Ok(elapsed) = TIME_INSTANCE.lock() {
        match elapsed.borrow().as_ref() {
            Some(elapsed) => {
                let duration = elapsed.elapsed().as_millis();
                debug!("sending frame {}", duration);
            }
            None => {}
        }
        elapsed.borrow_mut().replace(Instant::now());
    }
}
