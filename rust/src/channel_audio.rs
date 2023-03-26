use std::{
    cell::{RefCell, UnsafeCell},
    mem::ManuallyDrop,
    rc::{Rc, Weak},
    sync::{Arc, Mutex},
    thread,
};

use async_trait::async_trait;
use irondash_message_channel::{
    AsyncMethodHandler, MethodCall, PlatformError, PlatformResult, Value,
};
use irondash_run_loop::RunLoop;
use log::debug;

use crate::audio::{record_audio, AudioRecorder};

pub struct AudioHandler {
    pub recorder: RefCell<Option<AudioRecorder>>,
    pub audio: Arc<Mutex<Pcm>>,
}
#[derive(Debug)]
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
            "start_audio_recording" => {
                debug!(
                    "Received request {:?} on thread {:?}",
                    call,
                    thread::current().id()
                );
                let recorder = record_audio().unwrap();
                recorder.play().unwrap();
                self.recorder.replace(Some(recorder));

                Ok("ok".into())
            }
            "stop_audio_recording" => {
                debug!(
                    "Received request {:?} on thread {:?}",
                    call,
                    thread::current().id()
                );
                let recorder = self.recorder.borrow_mut().take().unwrap();
                recorder.stop();
                let mut audio = self.audio.lock().unwrap();
                *audio = recorder.audio;

                self.recorder.replace(None);
                Ok("ok".into())
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
