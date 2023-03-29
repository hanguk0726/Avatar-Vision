use std::{
    cell::RefCell,
    iter::repeat_with,
    mem::take,
    sync::{Arc, Mutex},
};

use irondash_texture::{BoxedPixelData, PayloadProvider, SimplePixelData};
use kanal::Receiver;
use log::{debug, error, info};
#[derive(Clone)]
pub struct PixelBufferSource {
    // pixel_buffer: Arc<Receiver<Vec<u8>>>,
    pixel_buffer: Arc<Mutex<Vec<u8>>>,
    last_pixel_buffer: Arc<Mutex<Vec<u8>>>,
}

impl PixelBufferSource {
    // pub fn new(pixel_buffer: Arc<Receiver<Vec<u8>>>) -> Self {
    pub fn new(pixel_buffer: Arc<Mutex<Vec<u8>>>) -> Self {
        Self {
            pixel_buffer,
            last_pixel_buffer: Arc::new(Mutex::new(Vec::new())),
        }
    }
}

impl PayloadProvider<BoxedPixelData> for PixelBufferSource {
    fn get_payload(&self) -> BoxedPixelData {
        let width = 1280i32;
        let height = 720i32;

        // match  self.pixel_buffer.recv() {

        //     Ok(data) => {
        //         debug!("pixel buffer is not empty");
        //         return SimplePixelData::new_boxed(width, height, data);
        //     }
        //     Err(_) => {
        //         info! {"pixel buffer is empty"};
        //         let data = repeat_with(|| 0u8)
        //             .take((width * height * 4) as usize)
        //             .collect::<Vec<u8>>();
        //         return SimplePixelData::new_boxed(width, height, data);
        //     }
        // }

        match self.pixel_buffer.lock() {
            Ok(mut data) => {
                let mut data = take(&mut *data);
                let mut last_pixel_buffer = self.last_pixel_buffer.lock().unwrap();
                if data.len() == 0 {
                    info! {"pixel buffer is empty fallback to backup buffer"};
                    // use back up buffer
                    data = last_pixel_buffer.clone();
                    if data.len() == 0 {
                        info! {"backup buffer is empty"};
                        data = repeat_with(|| 0u8)
                            .take((width * height * 4) as usize)
                            .collect::<Vec<u8>>();
                    }
                } else {
                    *last_pixel_buffer = data.clone();
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
