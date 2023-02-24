use flume::{Receiver, Sender};
use log::{debug, error};
use nokhwa::pixel_format::RgbAFormat;
use nokhwa::utils::{
    mjpeg_to_rgb, yuyv422_to_rgb, CameraFormat, CameraIndex, FrameFormat, RequestedFormat,
    RequestedFormatType,
};
use nokhwa::{CallbackCamera, NokhwaError};
use nokhwa_core::buffer::Buffer;
use once_cell::sync::Lazy;
use std::fmt::Error;
use std::sync::{Arc, Mutex};
use std::time::Instant;

pub fn inflate_camera_conection(sender: Arc<Sender<Vec<u8>>>) -> Result<CallbackCamera, Error> {
    let index = CameraIndex::Index(0);
    let requested =
        RequestedFormat::new::<RgbAFormat>(RequestedFormatType::AbsoluteHighestFrameRate);
    let camera = CallbackCamera::new(index, requested, move |buf| {
        debug!("sending frame");
        let start = Instant::now();
        let buf = decode(buf).unwrap();
        let duration = start.elapsed();

        debug!("Time elapsed in decode_function() is: {:?}", duration);

        sender.send(buf).expect("Error sending frame!");
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

fn decode(buf: Buffer) -> Result<Vec<u8>, Error> {
    let data = buf.buffer();
    match buf.source_frame_format() {
        FrameFormat::MJPEG => mjpeg_to_rgb(data, true).map_err(|why| {
            error!("Error converting MJPEG to RGB: {:?}", why);
            Error
        }),
        FrameFormat::YUYV => Ok(yuyv422_to_rgba_(data)),
        // FrameFormat::YUYV => yuyv422_to_rgb(data, true).map_err(|why| {
        //     error!("Error converting YUYV to RGB: {:?}", why);
        //     Error
        // }),
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

fn yuyv422_to_rgba_(data: &[u8]) -> Vec<u8> {
    let mut rgba = Vec::with_capacity(data.len() * 2);
    for chunk in data.chunks_exact(4) {
        let y0 = chunk[0] as f32;
        let u = chunk[1] as f32;
        let y1 = chunk[2] as f32;
        let v = chunk[3] as f32;

        let r0 = y0 + 1.370705 * (v - 128.);
        let g0 = y0 - 0.698001 * (v - 128.) - 0.337633 * (u - 128.);
        let b0 = y0 + 1.732446 * (u - 128.);

        let r1 = y1 + 1.370705 * (v - 128.);
        let g1 = y1 - 0.698001 * (v - 128.) - 0.337633 * (u - 128.);
        let b1 = y1 + 1.732446 * (u - 128.);

        rgba.extend_from_slice(&[
            r0 as u8, g0 as u8, b0 as u8, 255, r1 as u8, g1 as u8, b1 as u8, 255,
        ]);
    }
    rgba
}

// fn yuyv422_to_rgb_(data: &[u8], rgba: bool) ->  Result<Vec<u8>, NokhwaError> {
    

// }