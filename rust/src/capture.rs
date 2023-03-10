use kanal::Sender;
use log::{debug, error};
use nokhwa::pixel_format::RgbAFormat;
use nokhwa::utils::{mjpeg_to_rgb, CameraIndex, FrameFormat, RequestedFormat, RequestedFormatType};
use nokhwa::CallbackCamera;
use nokhwa_core::buffer::Buffer;

use std::fmt::Error;
use std::sync::Arc;


pub fn inflate_camera_conection(
    rending_sender: Arc<Sender<Buffer>>,
) -> Result<CallbackCamera, Error> {
    let index = CameraIndex::Index(0);
    let requested =
        RequestedFormat::new::<RgbAFormat>(RequestedFormatType::AbsoluteHighestFrameRate);

    let camera = CallbackCamera::new(index, requested, move |buf| {
        debug!("sending frame");
        rending_sender.try_send(buf).expect("Error sending frame!");
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

pub fn decode_to_rgb(
    data: &[u8],
    frame_format: &FrameFormat,
    rgba: bool,
) -> Result<Vec<u8>, Error> {
    match frame_format {
        FrameFormat::MJPEG => mjpeg_to_rgb(data, rgba).map_err(|why| {
            error!("Error converting MJPEG to RGB: {:?}", why);
            Error
        }),
        FrameFormat::YUYV => Ok(yuyv422_to_rgb_(data, rgba)),
        FrameFormat::GRAY => Ok(data
            .iter()
            .flat_map(|x| {
                let pxv = *x;
                [pxv, pxv, pxv]
            })
            .collect()),
        // FrameFormat::RAWRGB => Ok(data.to_vec()),
        // FrameFormat::NV12 => nv12_to_rgb(resolution, data, false),
        _ => {
            // let data = data.decode_image::<RgbAFormat>().unwrap();
            // Ok(data.to_vec())
            error!("Error converting to RGB: {:?}", frame_format);
            Ok(vec![])
        }
    }
}

fn yuyv422_to_rgb_(data: &[u8], rgba: bool) -> Vec<u8> {
    let mut rgb = Vec::with_capacity(data.len() * 2);
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

        if rgba {
            rgb.extend_from_slice(&[
                r0 as u8, g0 as u8, b0 as u8, 255, r1 as u8, g1 as u8, b1 as u8, 255,
            ]);
        } else {
            rgb.extend_from_slice(&[r0 as u8, g0 as u8, b0 as u8, r1 as u8, g1 as u8, b1 as u8]);
        }
    }
    rgb
}
