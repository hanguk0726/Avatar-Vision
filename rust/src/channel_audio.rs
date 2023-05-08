use std::{
    cell::RefCell,
    collections::HashMap,
    mem::ManuallyDrop,
    sync::{atomic::AtomicBool, Arc, Mutex},
    thread,
};

use async_trait::async_trait;
use cpal::{
    traits::{DeviceTrait, HostTrait},
    Device, SupportedStreamConfigRange,
};
use irondash_message_channel::{
    AsyncMethodHandler, MethodCall, PlatformError, PlatformResult, Value,
};
use irondash_run_loop::RunLoop;
use log::debug;

use crate::audio::{open_audio_stream, AudioStream};

pub struct AudioHandler {
    pub capture_white_sound: Arc<AtomicBool>,
    pub stream: Arc<Mutex<Option<AudioStream>>>,
    pub audio: Arc<Mutex<Pcm>>,
    pub current_device: Arc<Mutex<Option<String>>>,
}
#[derive(Debug, Clone)]
pub struct Pcm {
    pub data: Arc<Mutex<Vec<u8>>>,
    pub sample_rate: u32,
    pub channels: u16,
    pub bit_rate: usize,
}

impl Pcm {
    pub fn new() -> Self {
        Self {
            data: Arc::new(Mutex::new(vec![])),
            sample_rate: 0,
            channels: 0,
            bit_rate: 0,
        }
    }
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
                let map: HashMap<String, String> = call.args.try_into().unwrap();
                let device_name = map.get("device_name").unwrap().as_str();
                let capture_white_sound = self.capture_white_sound.clone();

                let recorder = open_audio_stream(device_name, capture_white_sound).unwrap();

                let mut audio = self.audio.lock().unwrap();
                *audio = recorder.audio.clone();

                recorder.play().unwrap();

                self.stream.lock().unwrap().replace(recorder);
                PlatformResult::Ok("ok".into())
            }
            "stop_audio_stream" => {
                debug!(
                    "Received request {:?} on thread {:?}",
                    call,
                    thread::current().id()
                );
                if let Some(recorder) = self.stream.lock().unwrap().take() {
                    recorder.stop();
                }

                return PlatformResult::Ok("ok".into());
            }

            "clear_audio_buffer" => {
                // debug!(
                //     "Received request {:?} on thread {:?}",
                //     call,
                //     thread::current().id()
                // );
                let mut data = vec![];

                if let Some(_) = self.current_device.lock().unwrap().as_ref() {
                    let audio = self.audio.lock().unwrap();
                    data = audio.data.lock().unwrap().drain(..).collect::<Vec<u8>>();
                }
                // debug!("data len: {}", data.len());

                let has_audio = data.iter().any(|&x| x != 0);
                Ok(has_audio.into())
            }

            "available_audios" => {
                debug!(
                    "Received request {:?} on thread {:?}",
                    call,
                    thread::current().id()
                );

                let names = cpal_available_inputs()
                    .iter()
                    .map(|d| d.name().unwrap())
                    .collect::<Vec<String>>();

                PlatformResult::Ok(names.into())
            }
            "current_audio_device" => {
                debug!(
                    "Received request {:?} on thread {:?}",
                    call,
                    thread::current().id()
                );
                let device = self.current_device.lock().unwrap();
                if let Some(device) = device.as_ref() {
                    PlatformResult::Ok(device.clone().into())
                } else {
                    PlatformResult::Ok("".into())
                }
            }
            "select_audio_device" => {
                debug!(
                    "Received request {:?} on thread {:?}",
                    call,
                    thread::current().id()
                );
                let map: HashMap<String, String> = call.args.try_into().unwrap();
                let device_name = map.get("device_name").unwrap().as_str();

                let inputs = cpal_available_inputs();
                if let Some(_) = inputs.iter().find(|d| d.name().unwrap() == device_name) {
                    let mut current_device = self.current_device.lock().unwrap();
                    *current_device = Some(device_name.to_string());
                }

                PlatformResult::Ok("ok".into())
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

pub fn cpal_available_inputs() -> Vec<Device> {
    let available_hosts = cpal::available_hosts();
    println!("Available hosts:\n  {:?}", available_hosts);
    let mut available_inputs: Vec<Device> = Vec::new();
    for host_id in available_hosts {
        println!("{}", host_id.name());
        let host = cpal::host_from_id(host_id).unwrap();
        let devices = host.devices().unwrap();
        available_inputs = devices
            .filter(|d| {
                if let Ok(configs) = d.supported_input_configs() {
                    let configs = configs.collect::<Vec<SupportedStreamConfigRange>>();
                    !configs.is_empty()
                } else {
                    false
                }
            })
            .collect::<Vec<Device>>();
    }
    available_inputs
}
