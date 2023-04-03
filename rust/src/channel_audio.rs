use std::{
    cell::RefCell,
    mem::ManuallyDrop,
    sync::{atomic::AtomicBool, Arc, Mutex},
    thread,
};

use async_trait::async_trait;
use irondash_message_channel::{
    AsyncMethodHandler, MethodCall, PlatformError, PlatformResult, Value,
};
use irondash_run_loop::RunLoop;
use log::debug;

use crate::{
    audio::{open_audio_stream, AudioStream},
    recording::RecordingInfo,
};

pub struct AudioHandler {
    pub recording_info: Arc<Mutex<RecordingInfo>>,
    pub stream: RefCell<Option<AudioStream>>,
    pub audio: Arc<Mutex<Pcm>>,
}
#[derive(Debug, Clone)]
pub struct Pcm {
    pub data: Arc<Mutex<Vec<u8>>>,
    pub sample_rate: u32,
    pub channels: u16,
    pub bit_rate: usize,
}
#[async_trait(?Send)]
impl AsyncMethodHandler for AudioHandler {
    async fn on_method_call(&self, call: MethodCall) -> PlatformResult {
        match call.method.as_str() {
            "open_audio_stream" => {
                debug!(
                    "Received request {:?} on thread {:?}",
                    call,
                    thread::current().id()
                );

                let recorder = open_audio_stream().unwrap();

                let mut audio = self.audio.lock().unwrap();
                *audio = recorder.audio.clone();

                recorder.play().unwrap();

                self.stream.replace(Some(recorder));
                PlatformResult::Ok("ok".into())
            }
            "stop_audio_stream" => {
                debug!(
                    "Received request {:?} on thread {:?}",
                    call,
                    thread::current().id()
                );
                let recorder = self.stream.borrow_mut().take().unwrap();

                recorder.stop();

                self.stream.replace(None);
                return PlatformResult::Ok("ok".into());
            }
            _ => Err(PlatformError {
                code: "invalid_method".into(),
                message: Some(format!("Unknown Method: {}", call.method)),
                detail: Value::Null,
            }),
        }
    }
}

pub fn init(audio_handler: AudioHandler) {
    thread::spawn(|| {
        let _ = ManuallyDrop::new(audio_handler.register("audio_channel_background_thread"));
        debug!(
            "Running RunLoop on background thread {:?}",
            thread::current().id()
        );
        RunLoop::current().run();
    });
}
