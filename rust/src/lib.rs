use std::{
    cell::RefCell,
    ffi::c_void,
    sync::{atomic::AtomicU32, Arc, Mutex, Once},
    thread::{self},
};

use irondash_message_channel::{irondash_init_message_channel_context, FunctionResult};
use irondash_run_loop::RunLoop;
use irondash_texture::Texture;
use kanal::{AsyncReceiver, AsyncSender, Receiver, Sender};
use log::debug;
use nokhwa::Buffer;
use textrue::PixelBufferSource;

use crate::{
    camera::Camera, channel_audio::AudioHandler, channel_camera::CameraHandler,
    channel_encoding::RecordingHandler, channel_textrue::TextureHandler, log_::init_logging,
};

mod audio;
mod camera;
mod channel_audio;
mod channel_camera;
mod channel_encoding;
mod channel_textrue;
mod domain;
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
    let (rendering_sender, rendering_receiver): (Sender<Buffer>, Receiver<Buffer>) =
        kanal::bounded(1);
    let (encoding_sender, encoding_receiver) = kanal::unbounded_async();
    let (rendering_sender, rendering_receiver) =
        (Arc::new(rendering_sender), Arc::new(rendering_receiver));
    let (encoding_sender, encoding_receiver) =
        (Arc::new(encoding_sender), Arc::new(encoding_receiver));

    let pixel_buffer: Arc<Mutex<Vec<u8>>> = Arc::new(Mutex::new(vec![]));
    let provider = Arc::new(PixelBufferSource::new(Arc::clone(&pixel_buffer)));
    let textrue = Texture::new_with_provider(flutter_enhine_id, provider).unwrap();
    let texture_id = textrue.id();

    let frame_rate = Arc::new(Mutex::new(0u32));
    let audio = Arc::new(Mutex::new(channel_audio::Pcm {
        data: Arc::new(Mutex::new(vec![])),
        sample_rate: 0,
        channels: 0,
        bit_rate: 0,
    }));
    channel_encoding::init(RecordingHandler::new(
        encoding_receiver.clone(),
        Arc::clone(&frame_rate),
        Arc::clone(&audio),
    ));
    channel_textrue::init(TextureHandler {
        pixel_buffer: pixel_buffer,
        receiver: rendering_receiver.clone(),
        texture_provider: textrue.into_sendable_texture(),
        encoding_sender: Arc::clone(&encoding_sender),
        frame_rate: Arc::clone(&frame_rate),
    });

    channel_camera::init(CameraHandler {
        camera: RefCell::new(Camera::new(
            Some(Arc::clone(&rendering_sender)))),
    });
    channel_audio::init(AudioHandler {
        stream: RefCell::new(None),
        audio,
    });
    texture_id
}
