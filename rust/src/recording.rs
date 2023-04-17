use std::{
    io::{Cursor, Read, Seek, SeekFrom},
    path::Path,
    sync::{atomic::AtomicBool, Arc, Mutex},
};

use log::debug;
use minimp4::Mp4Muxer;
use openh264::{
    encoder::{Encoder, EncoderConfig},
    Error,
};

use crate::{channel_audio::Pcm, domain::image_processing::YUVBuf, tools::ordqueue::OrdQueueIter};

pub struct RecordingInfo {
    pub started: std::time::Instant,
    pub recording: Arc<AtomicBool>,
    pub time_elapsed: f64,
    pub writing_state: Arc<Mutex<WritingState>>,
    pub capture_white_sound: Arc<AtomicBool>,
}

#[derive(Debug, Clone, Copy)]
pub enum WritingState {
    Collecting,
    Encoding,
    Saving,
    Idle,
}

impl WritingState {
    pub fn to_str(&self) -> &'static str {
        match self {
            WritingState::Collecting => "Collecting",
            WritingState::Encoding => "Encoding",
            WritingState::Saving => "Saving",
            WritingState::Idle => "Idle",
        }
    }
}

impl PartialEq for WritingState {
    fn eq(&self, other: &Self) -> bool {
        match (self, other) {
            (WritingState::Collecting, WritingState::Collecting) => true,
            (WritingState::Encoding, WritingState::Encoding) => true,
            (WritingState::Saving, WritingState::Saving) => true,
            (WritingState::Idle, WritingState::Idle) => true,
            _ => false,
        }
    }
}

impl RecordingInfo {
    pub fn new(recording: Arc<AtomicBool>, active_audio_only: Arc<AtomicBool>) -> Self {
        Self {
            started: std::time::Instant::now(),
            recording,
            time_elapsed: 0.0,
            writing_state: Arc::new(Mutex::new(WritingState::Idle)),
            capture_white_sound: active_audio_only,
        }
    }

    pub fn start(&mut self) {
        self.started = std::time::Instant::now();
        self.recording
            .store(true, std::sync::atomic::Ordering::Relaxed);
    }

    pub fn stop(&mut self) {
        self.time_elapsed = self.started.elapsed().as_secs_f64();
        self.recording
            .store(false, std::sync::atomic::Ordering::Relaxed);
    }

    pub fn set_writing_state(&mut self, state: WritingState) {
        let mut state_ = self.writing_state.lock().unwrap();
        *state_ = state;

        let capture_white_sound = state != WritingState::Idle;
        self.capture_white_sound
            .store(capture_white_sound, std::sync::atomic::Ordering::Relaxed);
    }

    pub fn frame_rate(&self, frames: usize) -> u32 {
        debug!("frames: {:?}", frames);
        debug!("time_elapsed: {:?}", self.time_elapsed);
        let frame_rate = frames as f64 / self.time_elapsed;
        frame_rate as u32
    }
}

pub fn encoder(width: u32, height: u32) -> Result<Encoder, Error> {
    let config = EncoderConfig::new(width, height);
    Encoder::with_config(config)
}

pub fn encode_to_h264(
    mut yuv_iter: OrdQueueIter<Vec<u8>>,
    len: usize,
    width: usize,
    height: usize,
) -> Vec<u8> {
    let started = std::time::Instant::now();
    let mut buf_h264 = Vec::new();
    let mut encoder = encoder(width as u32, height as u32).unwrap();
    debug!("encoding to h264...");
    for _ in 0..len {
        // let time_each = std::time::Instant::now();
        let yuv = YUVBuf {
            yuv: yuv_iter.next().unwrap(),
            width,
            height,
        };
        let bitstream = encoder.encode(&yuv).unwrap();

        for l in 0..bitstream.num_layers() {
            let layer = bitstream.layer(l).unwrap();
            for n in 0..layer.nal_count() {
                let nal = layer.nal_unit(n).unwrap();
                buf_h264.extend_from_slice(nal)
            }
        }
        // debug!("encoded to h264: {:?}", time_each.elapsed());
    }

    debug!("encoded to h264: {:?}", started.elapsed());
    buf_h264
}

pub fn to_mp4<P: AsRef<Path>>(
    buf_h264: &[u8],
    file: P,
    frame_rate: u32,
    audio: Pcm,
    width: u32,
    height: u32,
) -> Result<(), std::io::Error> {
    let mut video_buffer = Cursor::new(Vec::new());
    let mut mp4muxer = Mp4Muxer::new(&mut video_buffer);
    mp4muxer.init_video(width as i32, height as i32, false, "diary",);
    mp4muxer.init_audio(
        audio.bit_rate.try_into().unwrap(),
        audio.sample_rate,
        audio.channels.into(),
    );
    let audio_data = audio.data.lock().unwrap();
    debug!(
        "audio :: data: {}, sample_rata: {}, channles: {}, bit_rate: {},",
        &audio_data.len(),
        &audio.sample_rate,
        &audio.channels,
        &audio.bit_rate
    );
    debug!("frame_rate: {}", frame_rate);
    mp4muxer.write_video_with_audio(buf_h264, frame_rate, &audio_data[..]);

    mp4muxer.close();

    video_buffer.seek(SeekFrom::Start(0)).unwrap();
    let mut video_bytes = Vec::new();
    video_buffer.read_to_end(&mut video_bytes).unwrap();
    debug!("{} bytes", video_bytes.len());
    let file = file.as_ref().with_extension("mp4");
    std::fs::write(file, &video_bytes)
}
