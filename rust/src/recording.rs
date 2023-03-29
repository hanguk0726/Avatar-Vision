use std::{
    io::{Cursor, Read, Seek, SeekFrom},
    path::Path,
    sync::{atomic::AtomicBool, Arc},
};

use log::debug;
use minimp4::Mp4Muxer;
use openh264::{
    encoder::{Encoder, EncoderConfig},
    formats::YUVSource,
    Error,
};

use crate::channel_audio::Pcm;

pub struct RecordingInfo {
    pub started: std::time::Instant,
    pub recording: Arc<AtomicBool>,
    pub time_elapsed: f64,
}

impl RecordingInfo {
    pub fn new(recording: Arc<AtomicBool>) -> Self {
        Self {
            started: std::time::Instant::now(),
            recording,
            time_elapsed: 0.0,
        }
    }

    pub fn start(&mut self) {
        self.started = std::time::Instant::now();
        self.recording.store(true, std::sync::atomic::Ordering::Relaxed);
    }

    pub fn stop(&mut self) {
        self.time_elapsed = self.started.elapsed().as_secs_f64();
        self.recording.store(false, std::sync::atomic::Ordering::Relaxed);
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

pub fn encode_to_h264(yuv_vec: Vec<Vec<u8>>) -> Vec<u8> {
    let started = std::time::Instant::now();
    let mut buf_h264 = Vec::new();
    let mut encoder = encoder(1280, 720).unwrap();
    debug!("encoding to h264...");
    for yuv in yuv_vec {
        let yuv = YUVBuf {
            yuv: yuv.clone(),
            width: 1280,
            height: 720,
        };
        let bitstream = encoder.encode(&yuv).unwrap();

        for l in 0..bitstream.num_layers() {
            let layer = bitstream.layer(l).unwrap();
            for n in 0..layer.nal_count() {
                let nal = layer.nal_unit(n).unwrap();
                buf_h264.extend_from_slice(nal)
            }
        }
    }

    debug!("encoded to h264: {:?}", started.elapsed());
    buf_h264
}

pub fn to_mp4<P: AsRef<Path>>(
    buf_h264: &[u8],
    file: P,
    frame_rate: u32,
    audio: Pcm,
) -> Result<(), std::io::Error> {
    let mut video_buffer = Cursor::new(Vec::new());
    let mut mp4muxer = Mp4Muxer::new(&mut video_buffer);
    mp4muxer.init_video(1280, 720, false, "diary");
    mp4muxer.init_audio(
        audio.bit_rate.try_into().unwrap(),
        audio.sample_rate,
        audio.channels.into(),
    );
    let audio_data = audio.data.to_owned();
    let audio_data = audio_data.lock().unwrap();
    debug!(
        "audio\ndata: {}, sample_rata: {}, channles: {}, bit_rate: {},",
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

pub fn rgba_to_yuv(rgba: &[u8], width: usize, height: usize) -> Vec<u8> {
    let size = (3 * width * height) / 2;
    let mut yuv = vec![0; size];

    let u_base = width * height;
    let v_base = u_base + u_base / 4;
    let half_width = width / 2;

    // y is full size, u, v is quarter size
    let pixel = |x: usize, y: usize| -> (f32, f32, f32) {
        // two dim to single dim
        let base_pos = (x + y * width) * 4;
        (
            rgba[base_pos] as f32,
            rgba[base_pos + 1] as f32,
            rgba[base_pos + 2] as f32,
        )
    };

    let write_y = |yuv: &mut [u8], x: usize, y: usize, rgb: (f32, f32, f32)| {
        yuv[x + y * width] =
            (0.2578125 * rgb.0 + 0.50390625 * rgb.1 + 0.09765625 * rgb.2 + 16.0) as u8;
    };

    let write_u = |yuv: &mut [u8], x: usize, y: usize, rgb: (f32, f32, f32)| {
        yuv[u_base + x + y * half_width] =
            (-0.1484375 * rgb.0 + -0.2890625 * rgb.1 + 0.4375 * rgb.2 + 128.0) as u8;
    };

    let write_v = |yuv: &mut [u8], x: usize, y: usize, rgb: (f32, f32, f32)| {
        yuv[v_base + x + y * half_width] =
            (0.4375 * rgb.0 + -0.3671875 * rgb.1 + -0.0703125 * rgb.2 + 128.0) as u8;
    };
    for i in 0..width / 2 {
        for j in 0..height / 2 {
            let px = i * 2;
            let py = j * 2;
            let pix0x0 = pixel(px, py);
            let pix0x1 = pixel(px, py + 1);
            let pix1x0 = pixel(px + 1, py);
            let pix1x1 = pixel(px + 1, py + 1);
            let avg_pix = (
                (pix0x0.0 as u32 + pix0x1.0 as u32 + pix1x0.0 as u32 + pix1x1.0 as u32) as f32
                    / 4.0,
                (pix0x0.1 as u32 + pix0x1.1 as u32 + pix1x0.1 as u32 + pix1x1.1 as u32) as f32
                    / 4.0,
                (pix0x0.2 as u32 + pix0x1.2 as u32 + pix1x0.2 as u32 + pix1x1.2 as u32) as f32
                    / 4.0,
            );
            write_y(&mut yuv[..], px, py, pix0x0);
            write_y(&mut yuv[..], px, py + 1, pix0x1);
            write_y(&mut yuv[..], px + 1, py, pix1x0);
            write_y(&mut yuv[..], px + 1, py + 1, pix1x1);
            write_u(&mut yuv[..], i, j, avg_pix);
            write_v(&mut yuv[..], i, j, avg_pix);
        }
    }
    yuv
}

pub struct YUVBuf {
    yuv: Vec<u8>,
    width: usize,
    height: usize,
}

impl YUVSource for YUVBuf {
    fn width(&self) -> i32 {
        self.width as i32
    }

    fn height(&self) -> i32 {
        self.height as i32
    }

    fn y(&self) -> &[u8] {
        &self.yuv[0..self.width * self.height]
    }

    fn u(&self) -> &[u8] {
        let base_u = self.width * self.height;
        &self.yuv[base_u..base_u + base_u / 4]
    }

    fn v(&self) -> &[u8] {
        let base_u = self.width * self.height;
        let base_v = base_u + base_u / 4;
        &self.yuv[base_v..]
    }

    fn y_stride(&self) -> i32 {
        self.width as i32
    }

    fn u_stride(&self) -> i32 {
        (self.width / 2) as i32
    }

    fn v_stride(&self) -> i32 {
        (self.width / 2) as i32
    }
}
