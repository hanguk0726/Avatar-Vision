use std::{
    io::{Cursor, Read, Seek, SeekFrom},
    path::Path,
};


use log::{debug};
use minimp4::Mp4Muxer;
use openh264::{
    encoder::{Encoder, EncoderConfig},
    Error,
};

pub fn encoder(width: u32, height: u32) -> Result<Encoder, Error> {
    let config = EncoderConfig::new(width, height);
    Encoder::with_config(config)
}

fn rgba_to_rgb(rgba: &[u8]) -> Vec<u8> {
    let mut rgb = Vec::new();
    for i in 0..rgba.len() / 4 {
        rgb.push(rgba[i * 4]);
        rgb.push(rgba[i * 4 + 1]);
        rgb.push(rgba[i * 4 + 2]);
    }
    rgb
}

pub fn encode_to_h264(encoder: &mut Encoder, rgba_frame: &[u8], buf_h264: &mut Vec<u8>) {
    // Convert RGB into YUV.
    let mut yuv = openh264::formats::YUVBuffer::new(1280, 720);
    let rgb = rgba_to_rgb(rgba_frame);
    yuv.read_rgb(&rgb[..]);

    // Encode YUV into H.264.
    let bitstream = encoder.encode(&yuv).unwrap();
    bitstream.write_vec(buf_h264);
}

pub fn to_mp4<P: AsRef<Path>>(buf_h264: &[u8], file: P) -> Result<(), std::io::Error> {
    let mut video_buffer = Cursor::new(Vec::new());
    let mut mp4muxer = Mp4Muxer::new(&mut video_buffer);
    mp4muxer.init_video(1280, 720, false, "diary");
    mp4muxer.write_video_with_fps(buf_h264, 30);
    // mp4muxer.write_video(&buf_h264[..]);
    mp4muxer.close();
    video_buffer.seek(SeekFrom::Start(0)).unwrap();
    let mut video_bytes = Vec::new();
    video_buffer.read_to_end(&mut video_bytes).unwrap();
    debug!("{} bytes", video_bytes.len());
    std::fs::write(file, &video_bytes)
}
