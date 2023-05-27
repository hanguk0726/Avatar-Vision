use std::{
    ffi::c_void,
    sync::{atomic::AtomicBool, Arc, Mutex, Once},
};

use domain::{channel::ChannelService, textrue};
use irondash_message_channel::{irondash_init_message_channel_context, FunctionResult};
use irondash_run_loop::RunLoop;
use irondash_texture::{PixelDataProvider, SendableTexture, Texture};
use message_channel::{
    audio_message_channel::{self, AudioHandler},
    camera_message_channel::{self, CameraHandler},
    recording_message_channel::{self, RecordingHandler},
    rendering_message_channel::{self, RenderingHandler},
    texture_message_channel::{self, TextureHandler},
};

use crate::{
    domain::camera::CameraService, domain::recording::RecordingService,
    domain::resolution::ResolutionService,
};
use textrue::TextureService;
use tools::log_::init_logging;

mod domain;
mod message_channel;
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
    let texture_service = Arc::new(TextureService::new(resolution_settings.clone()));
    let render_buffer: Arc<Mutex<Vec<u8>>> = texture_service.pixel_buffer.clone();
    let textrue = Texture::new_with_provider(flutter_enhine_id, texture_service).unwrap();
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
    let recording_info = Arc::new(Mutex::new(RecordingService::new(recording.clone())));
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
        audio_service: Arc::new(Mutex::new(None)),
        pcm: audio,
        recording,
        current_device: Arc::new(Mutex::new(None)),
    });
}
