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

        sender
            .send(buf)
            .expect("Error sending frame!");
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

pub fn decode(buf: Buffer) -> Result<Vec<u8>, Error> {
    let data = buf.buffer();
    match buf.source_frame_format() {
        FrameFormat::MJPEG => mjpeg_to_rgb(data, true).map_err(|why| {
            error!("Error converting MJPEG to RGB: {:?}", why);
            Error
        }),
        FrameFormat::YUYV => yuyv422_to_rgb(data, true).map_err(|why| {
            error!("Error converting YUYV to RGB: {:?}", why);
            Error
        }),
        // FrameFormat::GRAY => Ok(data
        //     .iter()
        //     .flat_map(|x| {
        //         let pxv = *x;
        //         [pxv, pxv, pxv]
        //     })
        //     .collect()),
        // FrameFormat::RAWRGB => Ok(data.to_vec()),
        // FrameFormat::NV12 => nv12_to_rgb(resolution, data, false),
        _ => {
            //fallback to default handler
            let data = buf.decode_image::<RgbAFormat>().unwrap();
            Ok(data.to_vec())
        }
    }
}
