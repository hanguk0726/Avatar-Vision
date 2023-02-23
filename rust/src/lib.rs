use std::{
    ffi::c_void,
    thread::{self}, sync::{Once, Arc},
};

use irondash_message_channel::{irondash_init_message_channel_context, FunctionResult};
use irondash_run_loop::RunLoop;
use irondash_texture::Texture;
use log::debug;
use textrue:: PixelBufferSource;

use crate::{channel_capture::CaptureHandler, channel_textrue::TextureHandler, log_::init_logging};

mod addition;
mod capture;
mod channel_capture;
mod channel_textrue;
mod http_client;
mod log_;
mod slow;
mod textrue;

static START: Once = Once::new();

// must be called first from Dart side.
#[no_mangle]
pub extern "C" fn rust_init_texture(flutter_engine_id: i64) -> i64 {
    START.call_once(|| {
        init_logging();
    });
    RunLoop::sender_for_main_thread().send_and_wait(move || {
        init_channels_on_main_thread(flutter_engine_id)
    })
}

#[no_mangle]
pub extern "C" fn rust_init_message_channel_context(data: *mut c_void) -> FunctionResult {
    debug!(
        "Initializing message channel context from dart thread {:?}",
        thread::current().id()
    );
    // init FFI part of message channel from data obtained from Dart side.
    irondash_init_message_channel_context(data)
}

fn init_channels_on_main_thread(flutter_enhine_id: i64) -> i64{
    debug!(
        "Initializing handlers (on platform thread: {:?})",
        thread::current().id()
    );
    assert!(RunLoop::is_main_thread());
    let (sender, receiver) = flume::bounded(1);
    let (sender, receiver) = (Arc::new(sender), Arc::new(receiver));
    let provider = Arc::new(PixelBufferSource::new(receiver));
    let textrue = Texture::new_with_provider(flutter_enhine_id, provider).unwrap();
    let texture_id = textrue.id();
    channel_textrue::init(TextureHandler {
        texture_provider: textrue.into_sendable_texture(),
    });
    channel_capture::init(CaptureHandler { sender });
    texture_id
}
