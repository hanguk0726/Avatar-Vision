#[cfg(not(any(target_os = "ios", target_os = "android")))]
pub fn init_logging() {
    simple_logger::init_with_level(log::Level::Debug).unwrap();
}
