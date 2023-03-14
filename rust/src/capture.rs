use kanal::AsyncSender;
use log::{debug, error};
use nokhwa::pixel_format::RgbAFormat;
use nokhwa::utils::{CameraIndex, RequestedFormat, RequestedFormatType};
use nokhwa::CallbackCamera;
use nokhwa_core::buffer::Buffer;

use std::cell::RefCell;
use std::fmt::Error;
use std::sync::{Arc, Mutex};
use std::time::Instant;

#[cfg(debug_assertions)]
static TIME_INSTANCE: Mutex<RefCell<Option<Instant>>> = Mutex::new(RefCell::new(None));

//# refactor needed
pub fn inflate_camera_conection(
    rendering_sender: Arc<AsyncSender<Buffer>>,
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
