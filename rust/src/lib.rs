use std::{
    cell::RefCell,
    ffi::c_void,
    sync::{Arc, Mutex, Once},
    thread::{self},
};

use irondash_message_channel::{irondash_init_message_channel_context, FunctionResult};
use irondash_run_loop::RunLoop;
use irondash_texture::Texture;
use log::debug;
use textrue::PixelBufferSource;

use crate::{channel_capture::CaptureHandler, channel_textrue::TextureHandler, log_::init_logging, camera::Camera};

mod camera;
mod capture;
mod channel_capture;
mod channel_textrue;
mod encoding;
mod log_;
mod textrue;

static START: Once = Once::new();

// must be called first from Dart side.
#[no_mangle]
pub extern "C" fn rust_init_texture(flutter_engine_id: i64) -> i64 {
    START.call_once(|| {
        init_logging();
    });
    RunLoop::sender_for_main_thread()
        .send_and_wait(move || init_channels_on_main_thread(flutter_engine_id))
}

#[no_mangle]
pub extern "C" fn rust_init_message_channel_context(data: *mut c_void) -> FunctionResult {
    debug!(
        "Initializing message channel context from dart thread {:?}",
        thread::current().id()
    );
    irondash_init_message_channel_context(data)
}

fn init_channels_on_main_thread(flutter_enhine_id: i64) -> i64 {
    debug!(
        "Initializing handlers (on platform thread: {:?})",
        thread::current().id()
    );
    assert!(RunLoop::is_main_thread());
    let (sender, receiver) = flume::bounded(200);
    let (sender, receiver) = (Arc::new(sender), Arc::new(receiver));
    let pixel_buffer: Arc<Mutex<Vec<u8>>> = Arc::new(Mutex::new(vec![]));
    let provider = Arc::new(PixelBufferSource::new(Arc::clone(&pixel_buffer)));
    let textrue = Texture::new_with_provider(flutter_enhine_id, provider).unwrap();
    let texture_id = textrue.id();
    channel_textrue::init(TextureHandler {
        pixel_buffer,
        receiver: receiver,
        texture_provider: textrue.into_sendable_texture(),
        encoded: Arc::new(Mutex::new(vec![])),
    });
    channel_capture::init(CaptureHandler {
        camera: RefCell::new(Camera::new(sender)),
    });
    texture_id
}
