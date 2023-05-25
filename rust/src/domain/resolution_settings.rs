use std::sync::{atomic::AtomicI32, Mutex};

pub struct ResolutionService {
    pub width: AtomicI32,
    pub height: AtomicI32,
    available_resolutions: Mutex<Vec<String>>,
    current_resolution: Mutex<String>,
}

impl ResolutionService {

    pub fn new() -> Self {
        Self {
            width: AtomicI32::new(0),
            height: AtomicI32::new(0),
            available_resolutions: Mutex::new(Vec::new()),
            current_resolution: Mutex::new(String::new()),
        }
    }

    pub fn set_available_resolutions(&self, resolutions: &Vec<String>) {
        let mut available_resolutions = self.available_resolutions.lock().unwrap();
        *available_resolutions = resolutions.clone();
    }
    
    pub fn set_resolution(&self, resolution: &String) {
        let mut current_resolution = self.current_resolution.lock().unwrap();
        *current_resolution = resolution.clone();
        let resolution: Vec<&str> = resolution.split('x').collect();
        self.width.store(
            resolution[0].parse::<i32>().unwrap(),
            std::sync::atomic::Ordering::Relaxed,
        );
        self.height.store(
            resolution[1].parse::<i32>().unwrap(),
            std::sync::atomic::Ordering::Relaxed,
        );
    }

    pub fn get_available_resolutions(&self) -> Vec<String> {
        self.available_resolutions.lock().unwrap().clone()
    }

    pub fn get_current_resolution(&self) -> String {
        self.current_resolution.lock().unwrap().clone()
    }

    pub fn clear(&self) {
        self.width.store(0, std::sync::atomic::Ordering::Relaxed);
        self.height.store(0, std::sync::atomic::Ordering::Relaxed);
        self.available_resolutions.lock().unwrap().clear();
        self.current_resolution.lock().unwrap().clear();
    }
}
