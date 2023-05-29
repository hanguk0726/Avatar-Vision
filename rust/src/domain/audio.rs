use cpal::traits::{DeviceTrait, StreamTrait};
use cpal::Stream;
use log::debug;

use std::sync::atomic::AtomicBool;
use std::sync::{Arc, Mutex};

use crate::message_channel::audio_message_channel::{cpal_available_inputs, Pcm};

pub struct AudioService {
    pub stream: SendableStream,
    pub pcm: Pcm,
}
pub struct SendableStream(Stream);

unsafe impl Sync for SendableStream {}
unsafe impl Send for SendableStream {}

impl AudioService {
    pub fn play(&self) -> Result<(), anyhow::Error> {
        self.stream.0.play()?;
        Ok(())
    }

    pub fn stop(&self) {
        drop(&self.stream);
        debug!("audio stream dropped");
    }
}

pub fn open_audio_stream(
    device_name: &str,
    recording: Arc<AtomicBool>,
) -> Result<AudioService, anyhow::Error> {
    let devices = cpal_available_inputs();
    let device = devices
        .iter()
        .find(|d| d.name().unwrap() == device_name)
        .unwrap();

    debug!("Input device: {}", device.name()?);
    let config = device
        .default_input_config()
        .expect("Failed to get default input config");

    // let config = cpal::SupportedStreamConfig::new(
    //     config.channels(),
    //     config.sample_rate(),
    //     config.buffer_size().clone(),
    //     cpal::SampleFormat::I16,
    // );

    debug!("Default input config: {:?}", config);
    let buffer: Arc<Mutex<Vec<u8>>> = Arc::new(Mutex::new(Vec::new()));

    let buffer_clone = Arc::clone(&buffer);

    let stream = match config.sample_format() {
        cpal::SampleFormat::I16 => device.build_input_stream(
            &config.config(),
            move |data: &[i16], _: &cpal::InputCallbackInfo| {
                let mut buffer = buffer_clone.lock().unwrap();
                // trying to distinguish between silence and human voice for a wavy pattern UI in the 'setting' tab
                // only when it's not recording
                const ACTIVE_AUDIO_AMPLITUDE: f32 = 10000.0;
                let amplitude = data
                    .iter()
                    .fold(0.0, |max: f32, &sample| max.max(f32::abs(sample as f32)));
                // debug!("amplitude: {}", amplitude);

                for &sample in data.iter() {
                    let sample = sample.to_le_bytes();
                    if recording.load(std::sync::atomic::Ordering::Relaxed) {
                        buffer.push(sample[0]);
                        buffer.push(sample[1]);
                    } else {
                        if amplitude > ACTIVE_AUDIO_AMPLITUDE {
                            buffer.push(sample[0]);
                            buffer.push(sample[1]);
                        }
                    }
                }
            },
            move |err| eprintln!("an error occurred on stream: {}", err),
            None,
        )?,
        cpal::SampleFormat::F32 => device.build_input_stream(
            &config.config(),
            move |data: &[f32], _: &cpal::InputCallbackInfo| {
                let mut buffer = buffer_clone.lock().unwrap();
                const ACTIVE_AUDIO_AMPLITUDE: f32 = 0.03;
                let amplitude = data
                    .iter()
                    .fold(0.0, |max: f32, &sample| max.max(f32::abs(sample)));
                // debug!("amplitude: {}", amplitude);

                for &sample in data.iter() {
                    let i16_sample = (sample * i16::MAX as f32) as i16;
                    let sample = i16_sample.to_le_bytes();
                    if recording.load(std::sync::atomic::Ordering::Relaxed) {
                        buffer.push(sample[0]);
                        buffer.push(sample[1]);
                    } else {
                        if amplitude > ACTIVE_AUDIO_AMPLITUDE {
                            buffer.push(sample[0]);
                            buffer.push(sample[1]);
                        }
                    }
                }

                // debug!("audio buffer size: {}", buffer.len());
            },
            move |err| eprintln!("an error occurred on stream: {}", err),
            None,
        )?,
        _ => {
            return Err(anyhow::anyhow!("Unsupported sample format"));
        }
    };
    Ok(AudioService {
        stream: SendableStream(stream),
        pcm: Pcm {
            data: Arc::clone(&buffer),
            sample_rate: config.sample_rate().0,
            channels: config.channels(),
            bit_rate: 128000,
        },
    })
}
