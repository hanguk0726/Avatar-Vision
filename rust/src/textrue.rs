use std::{
    iter::repeat_with,
    mem::take,
    sync::{Arc, Mutex},
};

use irondash_texture::{
    BoxedPixelData, PayloadProvider, PixelDataProvider, SendableTexture, SimplePixelData, Texture,
};
use log::debug;
use once_cell::sync::Lazy;

use crate::capture::CAPTRUE_STATE;

pub static TEXTURE_PROVIDER: Lazy<Mutex<Option<Arc<SendableTexture<Box<dyn PixelDataProvider>>>>>> =
    Lazy::new(|| Mutex::new(None));

pub fn init_on_main_thread_texture(engine_handle: i64) -> irondash_texture::Result<i64> {
    let provider = Arc::new(PixelBufferSource::new());
    let texture = Texture::new_with_provider(engine_handle, provider)?;
    let id = texture.id();
    *TEXTURE_PROVIDER.lock().unwrap() = Some(texture.into_sendable_texture());
    debug!("Created texture with id {}", id);
    Ok(id)
}
#[derive(Clone)]
pub struct PixelBufferSource {}

impl PixelBufferSource {
    pub fn new() -> Self {
        Self {}
    }
}

impl PayloadProvider<BoxedPixelData> for PixelBufferSource {
    fn get_payload(&self) -> BoxedPixelData {
        let binding = CAPTRUE_STATE.lock().unwrap();
        let state = binding.as_ref().unwrap();
        let mut buffer = state.receiver.recv().unwrap();
        let width = 1280i32;
        let height = 720i32;
        debug!("Rendering pixel buffer");
        let data: Vec<u8> = take(&mut buffer);
        let _data = if data.len() == 0 {
            debug!("data: {:?}", data.len());
            repeat_with(|| 0)
                .take((width * height * 4) as usize)
                .collect()
        } else {
            debug!("data: {:?}", data.len());
            data
        };

        SimplePixelData::new_boxed(width, height, _data)
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
