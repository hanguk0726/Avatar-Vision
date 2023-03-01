use std::{
    iter::repeat_with,
    mem::take,
    sync::{Arc, Mutex},
};

use irondash_texture::{PayloadProvider, BoxedPixelData, SimplePixelData};
use log::debug;
#[derive(Clone)]
pub struct PixelBufferSource {
    pixel_buffer: Arc<Mutex<Vec<u8>>>,
}

impl PixelBufferSource {
    pub fn new(pixel_buffer: Arc<Mutex<Vec<u8>>>) -> Self {
        Self { pixel_buffer }
    }
}

impl PayloadProvider<BoxedPixelData> for PixelBufferSource {
    fn get_payload(&self) -> BoxedPixelData {
        debug!("Rendering pixel buffer");
        let width = 1280i32;
        let height = 720i32;
        let mut data = self.pixel_buffer.lock().unwrap();
        let data: Vec<u8> = take(&mut data);
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
