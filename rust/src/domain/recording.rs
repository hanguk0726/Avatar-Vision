use log::debug;
use minimp4::Mp4Muxer;
use openh264::{
    encoder::{Encoder, EncoderConfig, RateControlMode},
    Error,
};
use std::{
    fs::File,
    io::{Cursor, Read, Seek, SeekFrom, Write},
    path::Path,
    sync::{atomic::AtomicBool, Arc, Mutex},
};

use crate::{
    message_channel::audio_message_channel::Pcm, tools::image_processing::YUVBuf,
    tools::ordqueue::OrdQueueIter,
};

pub struct RecordingService {
    pub started: std::time::Instant,
    pub recording: Arc<AtomicBool>,
    pub time_elapsed: f64,
    pub writing_state: Arc<Mutex<WritingState>>,
}

#[derive(Debug, Clone, Copy)]
pub enum WritingState {
    Encoding,
    Saving,
    Idle,
}

impl WritingState {
    pub fn to_str(&self) -> &'static str {
        match self {
            WritingState::Encoding => "Encoding",
            WritingState::Saving => "Saving",
            WritingState::Idle => "Idle",
        }
    }
    pub fn from_str(s: &str) -> Self {
        match s {
            "Encoding" => WritingState::Encoding,
            "Saving" => WritingState::Saving,
            "Idle" => WritingState::Idle,
            _ => WritingState::Idle,
        }
    }
}

impl PartialEq for WritingState {
    fn eq(&self, other: &Self) -> bool {
        match (self, other) {
            (WritingState::Encoding, WritingState::Encoding) => true,
            (WritingState::Saving, WritingState::Saving) => true,
            (WritingState::Idle, WritingState::Idle) => true,
            _ => false,
        }
    }
}

impl RecordingService {
    pub fn new(recording: Arc<AtomicBool>) -> Self {
        Self {
            started: std::time::Instant::now(),
            recording,
            time_elapsed: 0.0,
            writing_state: Arc::new(Mutex::new(WritingState::Idle)),
        }
    }

    pub fn start(&mut self) {
        self.recording
            .store(true, std::sync::atomic::Ordering::Relaxed);
        self.started = std::time::Instant::now();
        self.time_elapsed = 0.0;
    }

    pub fn stop(&mut self) {
        self.recording
            .store(false, std::sync::atomic::Ordering::Relaxed);
        self.time_elapsed = self.started.elapsed().as_secs_f64();
    }

    pub fn set_writing_state(&mut self, state: WritingState) {
        let mut state_ = self.writing_state.lock().unwrap();
        *state_ = state;
    }
}

fn encoder(width: u32, height: u32) -> Result<Encoder, Error> {
    let config = EncoderConfig::new(width, height)
        .rate_control_mode(RateControlMode::Timestamp)
        .enable_skip_frame(false)
        .set_bitrate_bps(360000)
        .debug(false);

    Encoder::with_config(config)
}

pub fn encode_to_h264(
    mut yuv_iter: OrdQueueIter<Vec<u8>>,
    buffer_file_name: &str,
    width: usize,
    height: usize,
) {
    debug!("encoding to h264");
    let mut inner_count = 0;

    let mut encoder = encoder(width as u32, height as u32).unwrap();

    let started = std::time::Instant::now();
    let mut timer = std::time::Instant::now();

    // if 'buffer_file_name' exists, delete it
    if Path::new(buffer_file_name).exists() {
        std::fs::remove_file(buffer_file_name).unwrap();
    }
    let mut file = File::create(buffer_file_name).unwrap();

    while let Some(el) = yuv_iter.next() {
        inner_count += 1;
        if timer.elapsed().as_secs() > 3 {
            debug!("encoding...");
            timer = std::time::Instant::now();
        }
        let yuv = YUVBuf {
            yuv: el,
            width,
            height,
        };

        let bitstream = encoder.encode(&yuv).unwrap();
        for l in 0..bitstream.num_layers() {
            let layer = bitstream.layer(l).unwrap();
            for n in 0..layer.nal_count() {
                let nal = layer.nal_unit(n).unwrap();

                file.write_all(nal).unwrap();
            }
        }
        // don't let the momery explode
        file.flush().unwrap();
    }

    debug!(
        "encoding h264 done: {:?}, count {}",
        started.elapsed(),
        inner_count,
    );
}

pub fn to_mp4<P: AsRef<Path>>(
    buf_h264: &[u8],
    file_path: P,
    frame_rate: u32,
    audio: Pcm,
    width: u32,
    height: u32,
) -> Result<(), std::io::Error> {
    let mut video_buffer = Cursor::new(Vec::new());
    let mut mp4muxer = Mp4Muxer::new(&mut video_buffer);
    mp4muxer.init_video(width as i32, height as i32, false, "diary");
    mp4muxer.init_audio(
        audio.bit_rate.try_into().unwrap(),
        audio.sample_rate,
        audio.channels.into(),
    );

    debug!(
        "audio :: sample_rata: {}, channles: {}, bit_rate: {},",
        &audio.sample_rate, &audio.channels, &audio.bit_rate
    );

    debug!("frame_rate: {}", frame_rate);
    // read data from file 'temp.pcm'
    let audio_data = std::fs::read("temp.pcm").unwrap();
    mp4muxer.write_video_with_audio(buf_h264, frame_rate, &audio_data[..]);

    mp4muxer.close();

    video_buffer.seek(SeekFrom::Start(0)).unwrap();
    let mut video_bytes = Vec::new();
    video_buffer.read_to_end(&mut video_bytes).unwrap();

    let file_path = file_path.as_ref().with_extension("mp4");
    std::fs::write(file_path, &video_bytes)
}
