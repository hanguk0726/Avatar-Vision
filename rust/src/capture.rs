use flume::Receiver;
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

pub static CAPTRUE_STATE: Lazy<Mutex<Option<CaptureState>>> = Lazy::new(|| Mutex::new(None));



#[derive(Clone)]
pub struct CaptureState {
    pub receiver: Arc<Receiver<Buffer>>,
    pub buffer: Vec<u8>,
    pub format: CameraFormat,
}

pub fn inflateCameraConection() -> Result<CallbackCamera, Error> {
    let (sender, receiver) = flume::unbounded();
    let (sender, receiver) = (Arc::new(sender), Arc::new(receiver));
    let sender_clone = sender.clone();
    let index = CameraIndex::Index(0);
    let requested =
        RequestedFormat::new::<RgbAFormat>(RequestedFormatType::AbsoluteHighestFrameRate);
    let mut camera = CallbackCamera::new(index, requested, move |buf| {
        debug!("sending frame");
        sender_clone.send(buf).expect("Error sending frame!");
    })
    .map_err(|why| {
        eprintln!("Error opening camera: {:?}", why);
        Error
    })
    .unwrap();
    //TODO resolution
    let format = camera
        .camera_format()
        .map_err(|why| {
            eprintln!("Error reading camera format: {:?}", why);
            Error
        })
        .unwrap();
    let camera_info = camera.info().clone();
    debug!("format :{}", format);
    debug!("camera_info :{}", camera_info);

    *CAPTRUE_STATE.lock().unwrap() = Some(CaptureState {
        receiver,
        buffer: Vec::new(),
        format,
    });



    Ok(camera)
}
