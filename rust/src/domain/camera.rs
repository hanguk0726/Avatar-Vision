use kanal::Sender;
use std::sync::{Arc, Mutex};

use log::{debug, error};
use nokhwa::pixel_format::RgbAFormat;
use nokhwa::utils::{CameraIndex, CameraInfo, RequestedFormat, RequestedFormatType, Resolution};
use nokhwa::{Buffer, CallbackCamera};

use std::fmt::Error;
use std::time::Instant;


use super::channel::ChannelHandler;
use super::resolution_settings::ResolutionSettings;

pub struct Camera {
    pub channel_handler: Arc<Mutex<ChannelHandler>>,
    pub camera: Option<CallbackCamera>,
    pub current_camera_info: Arc<Mutex<Option<CameraInfo>>>,
    pub resolution_settings: Arc<ResolutionSettings>,
}
impl Camera {
    pub fn new(
        channel_handler: Arc<Mutex<ChannelHandler>>,
        resolution_settings: Arc<ResolutionSettings>,
    ) -> Self {
        Self {
            channel_handler,
            camera: None,
            current_camera_info: Arc::new(Mutex::new(None)),
            resolution_settings,
        }
    }
    pub fn infate_camera(&mut self, index: CameraIndex, resolution: Option<&String>) {
        let mut channel_handler = self.channel_handler.lock().unwrap();
        let mut rendering_sender = channel_handler.rendering.0.clone();
        let resolution_settings = self.resolution_settings.clone();
        if rendering_sender.is_closed() {
            channel_handler.reset();
            rendering_sender = channel_handler.rendering.0.clone();
        }

        if let Ok(camera) =
            inflate_camera_conection(index, rendering_sender, resolution, resolution_settings)
        {
            self.camera = Some(camera);
        } else {
            debug!("Failed to inflate camera");
        }
    }

    pub fn health_check(&mut self) -> (bool, String) {
        let camera = self.camera.as_mut().unwrap();
        match camera.poll_frame() {
            Ok(_) => (true, "".to_string()),
            Err(e) => (false, e.to_string()),
        }
    }

    pub fn open_camera_stream(&mut self) {
        if let Some(mut camera) = self.camera.take() {
            if let Err(_) = camera.open_stream() {
                debug!("Failed to open camera");
            } else {
                debug!("camera opened");
            }
            self.camera = Some(camera);
        } else {
            debug!("Failed to open camera");
        }
    }

    pub fn stop_camera_stream(&mut self) {
        if let Some(camera) = self.camera.take() {
            drop(camera);
            self.channel_handler.lock().unwrap().rendering.0.close();
        } else {
            debug!("No camera to stop");
        }
        self.resolution_settings.clear();
    }
}

pub fn inflate_camera_conection(
    index: CameraIndex,
    rendering_sender: Sender<(Buffer, Instant)>,
    requested_resolution: Option<&String>,
    resolution_settings: Arc<ResolutionSettings>,
) -> Result<CallbackCamera, Error> {
    let mut requested: Option<RequestedFormat> = None;
    if let Some(res) = requested_resolution {
        if res.len() != 0 {
            let res = res.split('x').collect::<Vec<&str>>();
            let res = Resolution::new(
                res[0].parse::<u32>().unwrap(),
                res[1].parse::<u32>().unwrap(),
            );
            requested = Some(RequestedFormat::new::<RgbAFormat>(
                RequestedFormatType::HighestResolution(res),
            ));
        }
    }

    if requested.is_none() {
        requested = Some(RequestedFormat::new::<RgbAFormat>(
            RequestedFormatType::AbsoluteHighestFrameRate,
        ));
    }

    let mut camera = CallbackCamera::new(index, requested.unwrap(), move |buf| {
        // debug_time_elasped();
        rendering_sender
            .try_send_realtime((buf, std::time::Instant::now()))
            .unwrap_or_else(|e| {
                error!("Error sending frame: {:?}", e);
                false
            });
    })
    .map_err(|why| {
        error!("Error opening camera: {:?}", why);
        Error
    })?;
    let format = camera.camera_format().map_err(|why| {
        error!("Error reading camera format: {:?}", why);
        Error
    })?;
    let camera_info = camera.info().clone();

    debug!("format :{}", format);
    debug!("camera_info :{}", camera_info);

    let frame_format = camera.frame_format().unwrap();
    let resolutions = camera.compatible_list_by_resolution(frame_format).unwrap();
    let resolutions: Vec<String> = resolutions
        .iter()
        .map(|r| format!("{}x{}", r.0.width(), r.0.height()))
        .collect();
    resolution_settings.set_available_resolutions(&resolutions);
    resolution_settings.set_resolution(&format.resolution().to_string());
    Ok(camera)
}

#[cfg(debug_assertions)]
#[cfg(unsued)]
static TIME_INSTANCE: Mutex<RefCell<Option<Instant>>> = Mutex::new(RefCell::new(None));

#[cfg(unsued)]
#[cfg(debug_assertions)]
fn debug_time_elasped() {
    if let Ok(elapsed) = TIME_INSTANCE.lock() {
        match elapsed.borrow().as_ref() {
            Some(_elapsed) => {
                let duration = _elapsed.elapsed().as_nanos();
                debug!("sending frame {}", duration);
            }
            None => {}
        }
        elapsed.borrow_mut().replace(Instant::now());
    }
}
