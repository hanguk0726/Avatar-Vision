//! Records a WAV file (roughly 3 seconds long) using the default input device and config.
//!
//! The input data is recorded to "$CARGO_MANIFEST_DIR/recorded.wav".

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cpal::{Stream, SupportedStreamConfig};
use log::debug;
use std::io::Write;
use std::sync::{Arc, Mutex};

use crate::channel_audio::Pcm;

pub struct AudioStream {
    pub stream: SendableStream,
    pub audio: Pcm,
}
pub struct SendableStream(Stream);

unsafe impl Sync for SendableStream {}
unsafe impl Send for SendableStream {}

impl AudioStream {
    pub fn play(&self) -> Result<(), anyhow::Error> {
        self.stream.0.play()?;
        Ok(())
    }

    pub fn stop(&self) {
        drop(&self.stream);
        debug!("Audio recording complete!");
    }
}
//TODO if failed to create stream, UI should know that sounds are not available
pub fn open_audio_stream() -> Result<AudioStream, anyhow::Error> {
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

    let device = host.default_input_device().unwrap();

    debug!("Input device: {}", device.name()?);
    let config = device
        .default_input_config()
        .expect("Failed to get default input config");

    debug!("Default input config: {:?}", config);

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
    Ok(AudioStream {
        stream: SendableStream(stream),
        audio: Pcm {
            data: Arc::clone(&buffer),
            sample_rate: config.sample_rate().0,
            channels: config.channels(),
            bit_rate: 128000,
        },
    })
}
