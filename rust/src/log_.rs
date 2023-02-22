#[cfg(not(any(target_os = "ios", target_os = "android")))]
pub fn init_logging() {
    simple_logger::init_with_level(log::Level::Debug).unwrap();
}

#[cfg(target_os = "android")]
pub fn init_logging() {
    android_logger::init_once(
        android_logger::Config::default()
            .with_min_level(log::Level::Debug)
            .with_tag("flutter"),
    );
}

#[cfg(target_os = "ios")]
pub fn init_logging() {
    oslog::OsLogger::new("irondash_message_channel_example")
        .level_filter(::log::LevelFilter::Debug)
        .init()
        .ok();
}