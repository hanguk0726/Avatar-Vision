use irondash_texture::{BoxedPixelData, PayloadProvider, SimplePixelData};
use std::{
    iter::repeat_with,
    mem::take,
    sync::{atomic::AtomicI32, Arc, Mutex},
};

use log::{debug, error};

use crate::resolution_settings::ResolutionSettings;

#[derive(Clone)]
pub struct PixelBufferSource {
    pub pixel_buffer: Arc<Mutex<Vec<u8>>>,
    pub resolution: Arc<ResolutionSettings>,
    last_pixel_buffer: Arc<Mutex<Vec<u8>>>,
}

impl PixelBufferSource {
    pub fn new(resolution: Arc<ResolutionSettings>) -> Self {
        Self {
            pixel_buffer: Arc::new(Mutex::new(Vec::new())),
            last_pixel_buffer: Arc::new(Mutex::new(Vec::new())),
            resolution,
        }
    }

    pub fn width(&self) -> i32 {
        self.resolution
            .width
            .load(std::sync::atomic::Ordering::Relaxed)
    }

    pub fn height(&self) -> i32 {
        self.resolution
            .height
            .load(std::sync::atomic::Ordering::Relaxed)
    }
}

impl PayloadProvider<BoxedPixelData> for PixelBufferSource {
    // An error occurring here causes the Flutter app to shut down without any error message.
    // ex: if the length of the data does not match the required width * height * 4 for the texture widget of Flutter

    fn get_payload(&self) -> BoxedPixelData {
        let width: i32 = self.width();
        let height: i32 = self.height();
        match self.pixel_buffer.lock() {
            Ok(mut data) => {
                let mut data = take(&mut *data);
                let mut last_pixel_buffer = self.last_pixel_buffer.lock().unwrap();
                if data.len() == 0 {
                    // info! {"pixel buffer is empty fallback to backup buffer"};
                    data = last_pixel_buffer.clone();
                } else {
                    *last_pixel_buffer = data.clone();
                }
                if data.len() == 0 || data.len() != (width * height * 4) as usize { // when transitioning from a resolution to another
                    // info! {"backup buffer is empty"};
                    data = repeat_with(|| 0u8)
                        .take((width * height * 4) as usize)
                        .collect::<Vec<u8>>();
                }
                return SimplePixelData::new_boxed(width, height, data);
            }
            Err(e) => {
                error!("error: {:?}", e);
                let data = repeat_with(|| 0u8)
                    .take((width * height * 4) as usize)
                    .collect::<Vec<u8>>();
                return SimplePixelData::new_boxed(width, height, data);
            }
        }
    }
}

// #[allow(dead_code)]
// fn test_texture() -> BoxedPixelData {
//     let rng = fastrand::Rng::new();
//     let width = 1280i32;
//     let height = 720i32;
//     debug!("Rendering pixel buffer");
//     let bytes: Vec<u8> = repeat_with(|| rng.u8(..))
//         .take((width * height * 4) as usize)
//         .collect();
//     SimplePixelData::new_boxed(width, height, bytes)
// }
