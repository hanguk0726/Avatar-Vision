use std::{
    cell::{RefCell, UnsafeCell},
    mem::ManuallyDrop,
    rc::{Rc, Weak},
    sync::{Arc, Mutex},
    thread,
};

use async_trait::async_trait;
use cpal::Stream;
use irondash_message_channel::{
    AsyncMethodHandler, MethodCall, PlatformError, PlatformResult, Value,
};
use irondash_run_loop::RunLoop;
use log::debug;

use crate::audio::{record_audio, AudioRecorder};

pub struct AudioHandler {
    pub recorder: RefCell<Option<AudioRecorder>>,
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
