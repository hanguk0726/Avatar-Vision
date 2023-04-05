use std::{
    cell::RefCell,
    collections::HashMap,
    io::Read,
    mem::ManuallyDrop,
    sync::{Arc, Mutex, atomic::AtomicBool},
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

use crate::{audio::{open_audio_stream, AudioStream}, recording::WritingState};

pub struct AudioHandler {
    pub capture_white_sound: Arc<AtomicBool>,
    pub stream: RefCell<Option<AudioStream>>,
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

                self.stream.replace(Some(recorder));
                PlatformResult::Ok("ok".into())
            }
            "stop_audio_stream" => {
                debug!(
                    "Received request {:?} on thread {:?}",
                    call,
                    thread::current().id()
                );
                if let Some(recorder) = self.stream.borrow_mut().take() {
                    recorder.stop();
                }
                self.stream.replace(None);
                return PlatformResult::Ok("ok".into());
            }

            "clear_audio_buffer" => {
                // debug!(
                //     "Received request {:?} on thread {:?}",
                //     call,
                //     thread::current().id()
                // );
                let mut data = vec![];
                let mut channels = 0;
                {
                    let audio = self.audio.lock().unwrap();
                    channels = audio.channels;
                    data = audio.data.lock().unwrap().drain(..).collect::<Vec<u8>>();
                }
                // debug!("data len: {}", data.len());
                let processed = pcm_data_to_waveform(&data, channels);
                Ok(processed.into())
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

fn pcm_data_to_waveform(pcm_data: &[u8], channel_count: u16) -> Vec<f32> {
    //get  last 256 
    let mut pcm_data = pcm_data.to_vec();
    let mut waveform = vec![];
    let mut pcm_data = pcm_data.split_off(pcm_data.len() - 256 * channel_count as usize);
    let mut pcm_data = pcm_data.chunks_exact(2);
    while let Some(chunk) = pcm_data.next() {
        let mut bytes = [0; 2];
        bytes.copy_from_slice(chunk);
        let sample = i16::from_le_bytes(bytes);
        let sample = sample as f32 / i16::MAX as f32;
        waveform.push(sample);
    }
    waveform
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
