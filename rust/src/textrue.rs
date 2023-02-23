use std::{
    fmt::Error,
    iter::repeat_with,
    sync::{Arc, Mutex},
};

use flume::Receiver;
use irondash_texture::{
    BoxedPixelData, PayloadProvider, PixelDataProvider, SendableTexture, SimplePixelData, Texture,
};
use log::{debug, error};
use nokhwa::{
    pixel_format::RgbAFormat,
    utils::{mjpeg_to_rgb, yuyv422_to_rgb, FrameFormat},
    Buffer, CallbackCamera,
};
use once_cell::sync::Lazy;

use crate::capture::decode;

#[derive(Clone)]
pub struct PixelBufferSource {
    receiver: Arc<Receiver<Buffer>>,
}

impl PixelBufferSource {
    pub fn new(receiver: Arc<Receiver<Buffer>>) -> Self {
        Self {
            receiver: receiver,
        }
    }
}

impl PayloadProvider<BoxedPixelData> for PixelBufferSource {
    fn get_payload(&self) -> BoxedPixelData {
        // !!! CAUTION !!!
        // Aware CAPTRUE_STATE is being holded here, so can't be used in other places.
        debug!("Rendering pixel buffer");
        let width = 1280i32;
        let height = 720i32;
        let buffer = self.receiver.recv().unwrap();
        // let data = buffer.decode_image::<RgbAFormat>().unwrap();
        // let data = data.to_vec();
        let data = decode(buffer).unwrap();
        let data = if data.len() == 0 {
            debug!("data: {:?}", data.len());
            repeat_with(|| 0)
                .take((width * height * 4) as usize)
                .collect()
        } else {
            debug!("data: {:?}", data.len());
            data
        };

        SimplePixelData::new_boxed(width, height, data)
    }
}

#[allow(dead_code)]
fn test_texture() -> BoxedPixelData {
    let rng = fastrand::Rng::new();
    let width = 1280i32;
    let height = 720i32;
    debug!("Rendering pixel buffer");
    let bytes: Vec<u8> = repeat_with(|| rng.u8(..))
        .take((width * height * 4) as usize)
        .collect();
    SimplePixelData::new_boxed(width, height, bytes)
}
