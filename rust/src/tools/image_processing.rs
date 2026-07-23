use log::error;
use nokhwa::utils::{mjpeg_to_rgb, nv12_to_rgb, FrameFormat, Resolution};
use openh264::formats::YUVSource;

pub fn decode_to_rgb(
    data: &[u8],
    frame_format: &FrameFormat,
    rgba: bool,
    width: u32,
    height: u32,
) -> Result<Vec<u8>, anyhow::Error> {
    match frame_format {
        FrameFormat::MJPEG => mjpeg_to_rgb(data, rgba)
            .map_err(|why| anyhow::anyhow!("Error converting MJPEG to RGB: {:?}", why)),
        FrameFormat::YUYV => Ok(yuyv422_to_rgb_(data, rgba)),
        FrameFormat::GRAY => Ok(data
            .iter()
            .flat_map(|x| {
                let pxv = *x;
                [pxv, pxv, pxv]
            })
            .collect()),
        FrameFormat::RAWRGB => Ok(rgb_to_rgba(data)),
        FrameFormat::NV12 => nv12_to_rgb(
            Resolution {
                width_x: (width),
                height_y: (height),
            },
            data,
            rgba,
        )
        .map_err(|why| anyhow::anyhow!("Error converting NV12 to RGB: {:?}", why)),
        _ => {
            // let data = data.decode_image::<RgbAFormat>().unwrap();
            // Ok(data.to_vec())
            error!("Error converting to RGB: {:?}", frame_format);
            Ok(vec![])
        }
    }
}

fn rgb_to_rgba(data: &[u8]) -> Vec<u8> {
    let mut rgba = Vec::with_capacity(data.len() * 2);
    for chunk in data.chunks_exact(3) {
        rgba.extend_from_slice(&[chunk[0], chunk[1], chunk[2], 255]);
    }
    rgba
}

fn yuyv422_to_rgb_(data: &[u8], rgba: bool) -> Vec<u8> {
    let mut rgb = Vec::with_capacity(data.len() * 2);
    for chunk in data.chunks_exact(4) {
        let y0 = chunk[0] as f32;
        let u = chunk[1] as f32;
        let y1 = chunk[2] as f32;
        let v = chunk[3] as f32;

        let r0 = y0 + 1.370705 * (v - 128.);
        let g0 = y0 - 0.698001 * (v - 128.) - 0.337633 * (u - 128.);
        let b0 = y0 + 1.732446 * (u - 128.);

        let r1 = y1 + 1.370705 * (v - 128.);
        let g1 = y1 - 0.698001 * (v - 128.) - 0.337633 * (u - 128.);
        let b1 = y1 + 1.732446 * (u - 128.);

        if rgba {
            rgb.extend_from_slice(&[
                r0 as u8, g0 as u8, b0 as u8, 255, r1 as u8, g1 as u8, b1 as u8, 255,
            ]);
        } else {
            rgb.extend_from_slice(&[r0 as u8, g0 as u8, b0 as u8, r1 as u8, g1 as u8, b1 as u8]);
        }
    }
    rgb
}

pub fn rgba_to_yuv(rgba: &[u8], width: usize, height: usize) -> Vec<u8> {
    let size = (3 * width * height) / 2;
    let mut yuv = vec![0u8; size];

    let u_base = width * height;
    let half_width = width / 2;

    // Split the destination into its three planes so each is a distinct
    // mutable slice. This lets the loop write straight into the plane without
    // recomputing plane offsets per pixel, and lets the compiler keep the Y
    // writes together for better cache behaviour.
    let (y_plane, uv_plane) = yuv.split_at_mut(u_base);
    let (u_plane, v_plane) = uv_plane.split_at_mut(u_base / 4);

    #[inline(always)]
    fn rgb_at(rgba: &[u8], base_pos: usize) -> (f32, f32, f32) {
        (
            rgba[base_pos] as f32,
            rgba[base_pos + 1] as f32,
            rgba[base_pos + 2] as f32,
        )
    }

    #[inline(always)]
    fn write_y(rgb: (f32, f32, f32)) -> u8 {
        (0.2578125 * rgb.0 + 0.50390625 * rgb.1 + 0.09765625 * rgb.2 + 16.0) as u8
    }

    // Iterate the 2x2 chroma blocks in row-major order (row `j` outer, column
    // `i` inner). The original walked column-major, so each inner step jumped
    // `2 * width` bytes in the row-major Y plane and thrashed the cache; walking
    // rows keeps the accessed bytes contiguous. The arithmetic below is
    // byte-for-byte identical to the previous implementation.
    for j in 0..height / 2 {
        let py = j * 2;
        let row0 = py * width;
        let row1 = (py + 1) * width;
        for i in 0..width / 2 {
            let px = i * 2;
            let b00 = (row0 + px) * 4;
            let b10 = (row1 + px) * 4;
            let pix0x0 = rgb_at(rgba, b00);
            let pix0x1 = rgb_at(rgba, b10);
            let pix1x0 = rgb_at(rgba, b00 + 4);
            let pix1x1 = rgb_at(rgba, b10 + 4);

            let avg_pix = (
                (pix0x0.0 as u32 + pix0x1.0 as u32 + pix1x0.0 as u32 + pix1x1.0 as u32) as f32
                    / 4.0,
                (pix0x0.1 as u32 + pix0x1.1 as u32 + pix1x0.1 as u32 + pix1x1.1 as u32) as f32
                    / 4.0,
                (pix0x0.2 as u32 + pix0x1.2 as u32 + pix1x0.2 as u32 + pix1x1.2 as u32) as f32
                    / 4.0,
            );

            y_plane[row0 + px] = write_y(pix0x0);
            y_plane[row1 + px] = write_y(pix0x1);
            y_plane[row0 + px + 1] = write_y(pix1x0);
            y_plane[row1 + px + 1] = write_y(pix1x1);

            let c = j * half_width + i;
            u_plane[c] =
                (-0.1484375 * avg_pix.0 + -0.2890625 * avg_pix.1 + 0.4375 * avg_pix.2 + 128.0) as u8;
            v_plane[c] =
                (0.4375 * avg_pix.0 + -0.3671875 * avg_pix.1 + -0.0703125 * avg_pix.2 + 128.0) as u8;
        }
    }
    yuv
}

pub struct YUVBuf {
    pub yuv: Vec<u8>,
    pub width: usize,
    pub height: usize,
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
