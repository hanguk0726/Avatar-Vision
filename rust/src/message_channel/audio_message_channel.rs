use std::{
    collections::HashMap,
    fs::File,
    io::Write,
    mem::ManuallyDrop,
    path::Path,
    sync::{atomic::AtomicBool, Arc, Mutex},
    thread,
    time::Duration,
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

use crate::domain::audio::{open_audio_stream, AudioService};

pub struct AudioHandler {
    pub audio_service: Arc<Mutex<Option<AudioService>>>,
    pub pcm: Arc<Mutex<Pcm>>,
    pub current_device: Arc<Mutex<Option<String>>>,
    pub recording: Arc<AtomicBool>,
    pub playing: Arc<AtomicBool>,
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
                let recording = self.recording.clone();
                let recording2 = self.recording.clone();
                let audio_service = open_audio_stream(device_name, recording).unwrap();

                let mut pcm = self.pcm.lock().unwrap();
                *pcm = audio_service.pcm.clone();
                let pcm = audio_service.pcm.clone().data;

                audio_service.play().unwrap();
                self.playing
                    .store(true, std::sync::atomic::Ordering::Relaxed);
                let playing = self.playing.clone();
                thread::spawn(move || {
                    let buffer_file_name = "temp.pcm";

                    if Path::new(buffer_file_name).exists() {
                        std::fs::remove_file(buffer_file_name).unwrap();
                    }
                    let mut file = File::create(buffer_file_name).unwrap();
                    while playing.load(std::sync::atomic::Ordering::Relaxed) {
                        thread::sleep(Duration::from_millis(1000));
                        if recording2.load(std::sync::atomic::Ordering::Relaxed) {
                            let data = pcm.lock().unwrap().drain(..).collect::<Vec<u8>>();
                            file.write_all(&data).unwrap();
                            file.flush().unwrap();
                        }
                    }
                });
                self.audio_service.lock().unwrap().replace(audio_service);
                PlatformResult::Ok("ok".into())
            }
            "stop_audio_stream" => {
                debug!(
                    "Received request {:?} on thread {:?}",
                    call,
                    thread::current().id()
                );
                if let Some(recorder) = self.audio_service.lock().unwrap().take() {
                    recorder.stop();
                }
                self.playing
                    .store(false, std::sync::atomic::Ordering::Relaxed);
                return PlatformResult::Ok("ok".into());
            }

            "get_audio_buffer" => {
                // debug!(
                //     "Received request {:?} on thread {:?}",
                //     call,
                //     thread::current().id()
                // );
                let mut data = vec![];

                if let Some(_) = self.current_device.lock().unwrap().as_ref() {
                    let audio = self.pcm.lock().unwrap();
                    data = audio.data.lock().unwrap().drain(..).collect::<Vec<u8>>();
                }
                // debug!("data len: {}", data.len());

                let has_active_audio = data.iter().any(|&x| x != 0);
                Ok(has_active_audio.into())
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
