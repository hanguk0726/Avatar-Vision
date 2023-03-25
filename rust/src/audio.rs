//! Records a WAV file (roughly 3 seconds long) using the default input device and config.
//!
//! The input data is recorded to "$CARGO_MANIFEST_DIR/recorded.wav".

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cpal::{Stream, SupportedStreamConfig};
use log::debug;
use std::io::Write;
use std::sync::{Arc, Mutex};

use crate::channel_audio::Pcm;

pub struct AudioRecorder {
    pub stream: SendableStream,
    pub audio: Pcm,
    pub data: Arc<Mutex<Vec<u8>>>,
}
pub struct SendableStream(Stream);

unsafe impl Sync for SendableStream {}
unsafe impl Send for SendableStream {}

impl AudioRecorder {
    pub fn play(&self) -> Result<(), anyhow::Error> {
        self.stream.0.play()?;
        Ok(())
    }

    pub fn stop(&self) {
        drop(&self.stream);
        debug!("Audio recording complete!");
    }
}

pub fn record_audio() -> Result<AudioRecorder, anyhow::Error> {
    #[cfg(any(
        not(any(
            target_os = "linux",
            target_os = "dragonfly",
            target_os = "freebsd",
            target_os = "netbsd"
        )),
        not(feature = "jack")
    ))]
    let host = cpal::default_host();

    // Set up the input device and stream with the default input config.
    let device = host.default_input_device().unwrap();

    debug!("Input device: {}", device.name()?);
    let config = device
        .default_input_config()
        .expect("Failed to get default input config");

    debug!("Default input config: {:?}", config);

    // let config = SupportedStreamConfig::new(
    //     config.channels(),
    //     config.sample_rate(),
    //     config.buffer_size().clone(),
    //     cpal::SampleFormat::F32,
    // );

    let buffer: Arc<Mutex<Vec<u8>>> = Arc::new(Mutex::new(Vec::new()));

    let buffer_clone = Arc::clone(&buffer);

    let stream = match config.sample_format() {
        cpal::SampleFormat::I16 => device.build_input_stream(
            &config.config(),
            move |data: &[i16], _: &cpal::InputCallbackInfo| {
                let mut buffer = buffer_clone.lock().unwrap();
                for &sample in data.iter() {
                    let sample = sample.to_le_bytes();
                    buffer.push(sample[0]);
                    buffer.push(sample[1]);
                }
            },
            move |err| eprintln!("an error occurred on stream: {}", err),
            None,
        )?,
        cpal::SampleFormat::F32 => device.build_input_stream(
            &config.config(),
            move |data: &[f32], _: &cpal::InputCallbackInfo| {
                let mut buffer = buffer_clone.lock().unwrap();
                for &sample in data.iter() {
                    //let f32_data = [0.1, 0.2, 0.3, 0.4]; // example f32 data
                    // let i16_data: Vec<i16> = f32_data.iter().map(|&f| (f * i16::MAX as f32) as i16).collect(); // convert f32 data to i16 data

                    let i16_sample = (sample * i16::MAX as f32) as i16;
                    let sample = i16_sample.to_le_bytes();
                    buffer.push(sample[0]);
                    buffer.push(sample[1]);
                }
            },
            move |err| eprintln!("an error occurred on stream: {}", err),
            None,
        )?,
        _ => {
            return Err(anyhow::anyhow!("Unsupported sample format"));
        }
    };
    Ok(AudioRecorder {
        stream: SendableStream(stream),
        audio: Pcm {
            data: vec![],
            sample_rate: config.sample_rate().0,
            channels: config.channels(),
            bit_rate: 128000,
        },
        data: Arc::clone(&buffer),
    })
}
