use flume::{Receiver, Sender};
use log::{debug, error};
use nokhwa::pixel_format::RgbAFormat;
use nokhwa::utils::{
    mjpeg_to_rgb, yuyv422_to_rgb, CameraFormat, CameraIndex, FrameFormat, RequestedFormat,
    RequestedFormatType,
};
use nokhwa::CallbackCamera;
use nokhwa_core::buffer::Buffer;
use once_cell::sync::Lazy;
use std::fmt::Error;
use std::sync::{Arc, Mutex};


pub fn inflate_camera_conection(sender: Arc<Sender<Buffer>>) -> Result<CallbackCamera, Error> {
    let index = CameraIndex::Index(0);
    let requested =
        RequestedFormat::new::<RgbAFormat>(RequestedFormatType::AbsoluteHighestFrameRate);
    let camera = CallbackCamera::new(index, requested, move |buf| {
        debug!("sending frame");
        sender.send(buf).expect("Error sending frame!");
    })
    .map_err(|why| {
        eprintln!("Error opening camera: {:?}", why);
        Error
    })?;
    let format = camera
        .camera_format()
        .map_err(|why| {
            eprintln!("Error reading camera format: {:?}", why);
            Error
        })?;
    let camera_info = camera.info().clone();
    debug!("format :{}", format);
    debug!("camera_info :{}", camera_info);

    Ok(camera)
}
