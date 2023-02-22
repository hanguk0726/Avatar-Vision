use std::{cell::Cell, iter::repeat_with, rc::Rc, sync::Arc, time::Duration};

use irondash_run_loop::RunLoop;
use irondash_texture::{BoxedPixelData, PayloadProvider, SimplePixelData, Texture};
use log::debug;

pub fn init_on_main_thread_texture(engine_handle: i64) -> irondash_texture::Result<i64> {
    let provider = Arc::new(PixelBufferSource::new());
    let texture = Texture::new_with_provider(engine_handle, provider)?;
    let id = texture.id();
    // *TEXTURE_PROVIDER.lock().unwrap() = Some(texture.into_sendable_texture());

    let animator = Rc::new(Animator {
        texture,
        counter: Cell::new(0),
    });
    animator.animate();
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
        let rng = fastrand::Rng::new();
        let width = 1280i32;
        let height = 720i32;
        debug!("Rendering pixel buffer");
        let bytes: Vec<u8> = repeat_with(|| rng.u8(..))
            .take((width * height * 4) as usize)
            .collect();
        SimplePixelData::new_boxed(width, height, bytes)
    }
}

struct Animator {
    texture: Texture<BoxedPixelData>,
    counter: Cell<u32>,
}
impl Animator {
    fn animate(self: &Rc<Self>) {
        self.texture.mark_frame_available().ok();

        let count = self.counter.get();
        self.counter.set(count + 1);

        if count < 120 {
            let self_clone = self.clone();
            RunLoop::current()
                .schedule(Duration::from_millis(100), move || {
                    self_clone.animate();
                })
                .detach();
        }
    }
}
