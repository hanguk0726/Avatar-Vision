use irondash_texture::{BoxedPixelData, PayloadProvider, SimplePixelData};
use std::{
    iter::repeat_with,
    mem::take,
    sync::{
        atomic::{AtomicBool, AtomicI32, AtomicUsize},
        Arc, Mutex,
    },
};

use log::{debug, error};

use crate::{channel::ChannelHandler, resolution_settings::ResolutionSettings};

#[derive(Clone)]
pub struct PixelBufferSource {
    pub pixel_buffer: Arc<Mutex<Vec<u8>>>,
    pub resolution: Arc<ResolutionSettings>,
    pub channel_handler: Arc<Mutex<ChannelHandler>>,
    pub recording: Arc<AtomicBool>,
    pub count: Arc<AtomicUsize>,
}

impl PixelBufferSource {
    pub fn new(
        resolution: Arc<ResolutionSettings>,
        channel_handler: Arc<Mutex<ChannelHandler>>,
        recording: Arc<AtomicBool>,
        count: Arc<AtomicUsize>,
    ) -> Self {
        Self {
            pixel_buffer: Arc::new(Mutex::new(Vec::new())),
            channel_handler,
            recording,
            resolution,
            count,
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
        let channel_handler = self.channel_handler.clone();
        let mut encoding_sender = self.channel_handler.lock().unwrap().encoding.0.clone();
        // let queue = channel_handler.lock().unwrap().queue.clone().0;
        let count = self.count.clone();
        //add 1
    
        // let test = channel_handler.lock().unwrap().test.clone();

        // let mut test = test.lock().unwrap();

        let recording = self.recording.clone();
        let width: i32 = self.width();
        let height: i32 = self.height();
        match self.pixel_buffer.lock() {
            Ok(mut data) => {
                if data.len() == 0 || data.len() != (width * height * 4) as usize {
                    // when transitioning from a resolution to another
                    // info! {"backup buffer is empty"};
                    *data = repeat_with(|| 0u8)
                        .take((width * height * 4) as usize)
                        .collect::<Vec<u8>>();
                }

                // if recording.load(std::sync::atomic::Ordering::Relaxed) {
                //     encoding_sender.try_send_realtime(data.clone()).unwrap_or_else(|e| {
                //         debug!("encoding channel sending failed: {:?}", e);
                //         false
                //     });
                //     count.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                //     // queue.push(count, data.clone()).unwrap();
                //     // debug!("queue pushed");
                // } else {
                //     if encoding_sender.is_closed() {
                //         let mut channel_handler = channel_handler.lock().unwrap();
                //         channel_handler.reset_encoding();
                //         encoding_sender = channel_handler.encoding.0.clone();
                //     }
                // }
                return SimplePixelData::new_boxed(width, height, data.to_owned());
            }
            Err(e) => {
                error!("error: {:?}", e);
                let data = repeat_with(|| 0u8)
                    .take((width * height * 4) as usize)
                    .collect::<Vec<u8>>();

                //dulicated code
                // if recording.load(std::sync::atomic::Ordering::Relaxed) {
                //     encoding_sender.try_send(data.clone()).unwrap_or_else(|e| {
                //         debug!("encoding channel sending failed: {:?}", e);
                //         false
                //     });
                // } else {
                //     if encoding_sender.is_closed() {
                //         let mut channel_handler = channel_handler.lock().unwrap();
                //         channel_handler.reset_encoding();
                //         encoding_sender = channel_handler.encoding.0.clone();
                //     }
                // }
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
