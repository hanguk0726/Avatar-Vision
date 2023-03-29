use std::{
    cell::RefCell,
    ffi::c_void,
    sync::{
        atomic::{AtomicBool, AtomicU32},
        Arc, Mutex, Once,
    },
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
    camera::Camera, channel::ChannelHandler, channel_audio::AudioHandler,
    channel_camera::CameraHandler, channel_recording::RecordingHandler,
    channel_rendering::RenderingHandler, channel_textrue::TextureHandler, log_::init_logging,
    recording::RecordingInfo,
};

mod audio;
mod camera;
mod channel;
mod channel_audio;
mod channel_camera;
mod channel_recording;
mod channel_rendering;
mod channel_textrue;
mod domain;
mod log_;
mod recording;
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
    let channel_handler = Arc::new(Mutex::new(ChannelHandler::new()));

    let pixel_buffer: Arc<Mutex<Vec<u8>>> = Arc::new(Mutex::new(vec![]));

    let provider = Arc::new(PixelBufferSource::new(pixel_buffer.clone()));
    let textrue = Texture::new_with_provider(flutter_enhine_id, provider).unwrap();
    let texture_id = textrue.id();

    let recording = Arc::new(AtomicBool::new(false));
    let recording_info = Arc::new(Mutex::new(RecordingInfo::new(Arc::clone(&recording))));
    let audio = Arc::new(Mutex::new(channel_audio::Pcm {
        data: Arc::new(Mutex::new(vec![])),
        sample_rate: 0,
        channels: 0,
        bit_rate: 0,
    }));

    channel_textrue::init(TextureHandler {
        pixel_buffer: pixel_buffer.clone(),
        channel_handler: channel_handler.clone(),
        recording: Arc::clone(&recording),
    });

    channel_camera::init(CameraHandler {
        camera: RefCell::new(Camera::new(channel_handler.clone())),
    });

    channel_recording::init(RecordingHandler::new(
        Arc::clone(&audio),
        Arc::clone(&recording_info),
        channel_handler,
    ));
    channel_rendering::init(RenderingHandler {
        texture_provider: textrue.into_sendable_texture(),
        rendering: Arc::new(AtomicBool::new(false)),
    });
    channel_audio::init(AudioHandler {
        stream: RefCell::new(None),
        audio,
    });

    texture_id
}
