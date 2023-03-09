use std::{
    io::{Cursor, Read, Seek, SeekFrom},
    path::Path,
};


use log::{debug};
use minimp4::Mp4Muxer;
use nokhwa::{utils::FrameFormat, Buffer, NokhwaError};
use openh264::{
    encoder::{Encoder, EncoderConfig},
    formats::YUVBuffer,
    Error,
};

use crate::capture::decode_to_rgb;

pub fn encoder(width: u32, height: u32) -> Result<Encoder, Error> {
    let config = EncoderConfig::new(width, height);
    Encoder::with_config(config)
}

pub fn encode_to_h264(encoder: &mut Encoder, buffer: Buffer, buf_h264: &mut Vec<u8>) {
    let yuv = encode_to_yuv(buffer.buffer(), &buffer.source_frame_format()).unwrap();
    // Encode YUV into H.264.
    let bitstream = encoder.encode(&yuv).unwrap();
    bitstream.write_vec(buf_h264);
}

pub fn to_mp4<P: AsRef<Path>>(buf_h264: &[u8], file: P, fps: u32) -> Result<(), std::io::Error> {
    let mut video_buffer = Cursor::new(Vec::new());
    let mut mp4muxer = Mp4Muxer::new(&mut video_buffer);
    mp4muxer.init_video(1280, 720, false, "diary");
    mp4muxer.write_video_with_fps(buf_h264, fps);
    mp4muxer.close();
    video_buffer.seek(SeekFrom::Start(0)).unwrap();
    let mut video_bytes = Vec::new();
    video_buffer.read_to_end(&mut video_bytes).unwrap();
    debug!("{} bytes", video_bytes.len());
    std::fs::write(file, &video_bytes)
}

fn encode_to_yuv(data: &[u8], frame_format: &FrameFormat) -> Result<YUVBuffer, NokhwaError> {
    let width = 1280;
    let height = 720;
    let start = std::time::Instant::now();

    let rgb = decode_to_rgb(data, frame_format, false).unwrap();
    debug!("time1 elapsed: {:?}", start.elapsed());
    let start = std::time::Instant::now();
    let buf = YUVBuffer::with_rgb(width, height, &rgb);
    debug!("time2 elapsed: {:?}", start.elapsed());
    return Ok(buf);
}
