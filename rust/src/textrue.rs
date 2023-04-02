use std::{
    iter::repeat_with,
    mem::take,
    sync::{atomic::AtomicBool, Arc, Mutex},
};

use irondash_texture::{BoxedPixelData, PayloadProvider, SimplePixelData};

use kanal::AsyncSender;
use log::{debug, error};
#[derive(Clone)]
pub struct PixelBufferSource {
    pub pixel_buffer: Arc<Mutex<Vec<u8>>>,
    last_pixel_buffer: Arc<Mutex<Vec<u8>>>,
    encoding_sender: Arc<AsyncSender<Vec<u8>>>,
    recording: Arc<AtomicBool>,
}

impl PixelBufferSource {
    pub fn new(encoding_sender: Arc<AsyncSender<Vec<u8>>>, recording: Arc<AtomicBool>) -> Self {
        Self {
            pixel_buffer: Arc::new(Mutex::new(Vec::new())),
            last_pixel_buffer: Arc::new(Mutex::new(Vec::new())),
            encoding_sender,
            recording,
        }
    }
}

impl PayloadProvider<BoxedPixelData> for PixelBufferSource {
    fn get_payload(&self) -> BoxedPixelData {
        let width = 1280i32;
        let height = 720i32;

        match self.pixel_buffer.lock() {
            Ok(mut data) => {
                let mut data = take(&mut *data);
                let mut last_pixel_buffer = self.last_pixel_buffer.lock().unwrap();
                if data.len() == 0 {
                    // info! {"pixel buffer is empty fallback to backup buffer"};
                    data = last_pixel_buffer.clone();
                    if data.len() == 0 {
                        // info! {"backup buffer is empty"};
                        data = repeat_with(|| 0u8)
                            .take((width * height * 4) as usize)
                            .collect::<Vec<u8>>();
                    }
                } else {
                    *last_pixel_buffer = data.clone();
                }
                let data_ = data.clone();
                if self.recording.load(std::sync::atomic::Ordering::Relaxed) {
                    let encoding_sender = self.encoding_sender.clone();
                    encoding_sender.try_send(data_).unwrap_or_else(|e| {
                        error!("error: {:?}", e);
                        false
                    });
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
