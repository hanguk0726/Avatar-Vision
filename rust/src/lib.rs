use std::{
    ffi::c_void,
    sync::{atomic::AtomicBool, Arc, Mutex, Once},
};

use domain::{channel::ChannelService, textrue};
use irondash_message_channel::{irondash_init_message_channel_context, FunctionResult};
use irondash_run_loop::RunLoop;
use irondash_texture::{PixelDataProvider, SendableTexture, Texture};
use message_channel::{camera_message_channel::{self, CameraHandler}, texture_message_channel::{self, TextureHandler}, audio_message_channel::{self, AudioHandler}, recording_message_channel::{RecordingHandler, self}, rendering_message_channel::{self, RenderingHandler}};

use crate::{ domain::camera::CameraService, domain::recording::RecordingService,
    domain::resolution_settings::ResolutionService,
};
use textrue::PixelBufferSource;
use tools::log_::init_logging;

mod message_channel;
mod domain;
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
    let resolution_settings = Arc::new(ResolutionService::new());
    let provider = Arc::new(PixelBufferSource::new(resolution_settings.clone()));
    let render_buffer: Arc<Mutex<Vec<u8>>> = provider.pixel_buffer.clone();
    let textrue = Texture::new_with_provider(flutter_enhine_id, provider).unwrap();
    let texture_id = textrue.id();

    init_message_channels(
        render_buffer.clone(),
        textrue.into_sendable_texture(),
        resolution_settings,
    );

    texture_id
}

fn init_message_channels(
    render_buffer: Arc<Mutex<Vec<u8>>>,
    texture: Arc<SendableTexture<Box<dyn PixelDataProvider>>>,
    resolution_settings: Arc<ResolutionService>,
) {
    let channel_handler = Arc::new(Mutex::new(ChannelService::new()));
    let recording = Arc::new(AtomicBool::new(false));
    let rendering = Arc::new(AtomicBool::new(false));
    let capture_white_sound = Arc::new(AtomicBool::new(false));
    let recording_info = Arc::new(Mutex::new(RecordingService::new(
        recording.clone(),
        capture_white_sound.clone(),
    )));
    let audio = Arc::new(Mutex::new(audio_message_channel::Pcm {
        data: Arc::new(Mutex::new(vec![])),
        sample_rate: 0,
        channels: 0,
        bit_rate: 0,
    }));

    texture_message_channel::init(TextureHandler {
        render_buffer,
        channel_handler: channel_handler.clone(),
        recording: recording.clone(),
    });

    camera_message_channel::init(CameraHandler::new(
        rendering.clone(),
        Arc::new(Mutex::new(CameraService::new(
            channel_handler.clone(),
            resolution_settings,
        ))),
    ));

    recording_message_channel::init(RecordingHandler::new(
        audio.clone(),
        recording_info.clone(),
        channel_handler,
    ));

    rendering_message_channel::init(RenderingHandler::new(texture, rendering));

    audio_message_channel::init(AudioHandler {
        capture_white_sound,
        stream: Arc::new(Mutex::new(None)),
        audio,
        current_device: Arc::new(Mutex::new(None)),
    });
}
