use std::{
    cell::RefCell,
    ffi::c_void,
    sync::{
        atomic::{AtomicBool, AtomicI32, AtomicUsize},
        Arc, Mutex, Once,
    },
};

use irondash_message_channel::{irondash_init_message_channel_context, FunctionResult};
use irondash_run_loop::RunLoop;
use irondash_texture::{PixelDataProvider, SendableTexture, Texture};

use log::debug;
use textrue::PixelBufferSource;
use tools::log_::init_logging;

use crate::{
    camera::Camera, channel::ChannelHandler, channel_audio::AudioHandler,
    channel_camera::CameraHandler, channel_recording::RecordingHandler,
    channel_rendering::RenderingHandler, channel_textrue::TextureHandler, recording::RecordingInfo,
    resolution_settings::ResolutionSettings,
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
mod recording;
mod resolution_settings;
mod textrue;
mod tools;

static START: Once = Once::new();

#[no_mangle]
pub extern "C" fn rust_init_on_main_thread(flutter_engine_id: i64) -> i64 {
    START.call_once(|| {
        init_logging();
    });
    RunLoop::sender_for_main_thread().send_and_wait(move || init_on_main_thread(flutter_engine_id))
}

#[no_mangle]
pub extern "C" fn rust_init_message_channel_context(data: *mut c_void) -> FunctionResult {
    irondash_init_message_channel_context(data)
}

fn init_on_main_thread(flutter_enhine_id: i64) -> i64 {
    assert!(RunLoop::is_main_thread());

    let resolution_settings = Arc::new(ResolutionSettings::new());
    let provider = Arc::new(PixelBufferSource::new(resolution_settings.clone()));
    let render_buffer: Arc<Mutex<Vec<u8>>> = provider.pixel_buffer.clone();
    let textrue = Texture::new_with_provider(flutter_enhine_id, provider).unwrap();
    let texture_id = textrue.id();

    init_channels(
        render_buffer.clone(),
        textrue.into_sendable_texture(),
        resolution_settings,
    );

    texture_id
}

fn init_channels(
    render_buffer: Arc<Mutex<Vec<u8>>>,
    texture: Arc<SendableTexture<Box<dyn PixelDataProvider>>>,
    resolution_settings: Arc<ResolutionSettings>,
) {
    let channel_handler = Arc::new(Mutex::new(ChannelHandler::new()));
    let recording = Arc::new(AtomicBool::new(false));
    let rendering = Arc::new(AtomicBool::new(false));
    let capture_white_sound = Arc::new(AtomicBool::new(false));
    let encoding_buffer = Arc::new(Mutex::new(Vec::new()));
    let recording_info = Arc::new(Mutex::new(RecordingInfo::new(
        recording.clone(),
        capture_white_sound.clone(),
    )));
    let audio = Arc::new(Mutex::new(channel_audio::Pcm {
        data: Arc::new(Mutex::new(vec![])),
        sample_rate: 0,
        channels: 0,
        bit_rate: 0,
    }));

    channel_textrue::init(TextureHandler {
        render_buffer,
        channel_handler: channel_handler.clone(),
        recording: recording.clone(),
        encoding_buffer: encoding_buffer.clone(),
    });

    channel_camera::init(CameraHandler::new(
        rendering.clone(),
        Arc::new(Mutex::new(Camera::new(
            channel_handler.clone(),
            resolution_settings,
        ))),
    ));

    channel_recording::init(RecordingHandler::new(
        audio.clone(),
        recording_info.clone(),
        channel_handler,
        encoding_buffer,
    ));

    channel_rendering::init(RenderingHandler::new(texture, rendering));

    channel_audio::init(AudioHandler {
        capture_white_sound,
        stream: Arc::new(Mutex::new(None)),
        audio,
        current_device: Arc::new(Mutex::new(None)),
    });
}
