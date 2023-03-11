use std::{
    cell::RefCell,
    ffi::c_void,
    sync::{atomic::AtomicU32, Arc, Mutex, Once},
    thread::{self},
};

use irondash_message_channel::{irondash_init_message_channel_context, FunctionResult};
use irondash_run_loop::RunLoop;
use irondash_texture::Texture;
use log::debug;
use textrue::PixelBufferSource;

use crate::{
    camera::Camera, channel_capture::CaptureHandler, channel_encoding::EncodingHandler,
    channel_textrue::TextureHandler, log_::init_logging,
};

mod camera;
mod capture;
mod channel_capture;
mod channel_encoding;
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
    let (rendering_sender, rendering_receiver) = kanal::bounded(1);
    // let (rendering_sender, rendering_receiver) = kanal::unbounded();
    let (encoding_sender, encoding_receiver) = kanal::unbounded();
    let (rendering_sender, rendering_receiver) =
        (Arc::new(rendering_sender), Arc::new(rendering_receiver));
    let (encoding_sender, encoding_receiver) =
        (Arc::new(encoding_sender), Arc::new(encoding_receiver));

    let pixel_buffer: Arc<Mutex<Vec<u8>>> = Arc::new(Mutex::new(vec![]));
    let provider = Arc::new(PixelBufferSource::new(Arc::clone(&pixel_buffer)));
    let textrue = Texture::new_with_provider(flutter_enhine_id, provider).unwrap();
    let texture_id = textrue.id();

    let fps = Arc::new(AtomicU32::new(0));

    channel_encoding::init(EncodingHandler::new(encoding_receiver.clone(), Arc::clone(&fps)));
    channel_textrue::init(TextureHandler {
        pixel_buffer,
        receiver: rendering_receiver.clone(),
        texture_provider: textrue.into_sendable_texture(),
        encoding_sender: Arc::clone(&encoding_sender),
    });

    channel_capture::init(CaptureHandler {
        camera: RefCell::new(Camera::new(
            Some(Arc::clone(&rendering_sender)),
        )),
    });

    texture_id
}
