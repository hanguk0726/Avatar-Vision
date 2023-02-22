use std::{
    ffi::c_void,
    sync::Once,
    thread::{self},
};

use irondash_message_channel::{irondash_init_message_channel_context, FunctionResult};
use irondash_run_loop::RunLoop;
use log::debug;
use textrue::init_on_main_thread_texture;

use crate::log_::init_logging;

mod addition;
mod http_client;
mod log_;
mod slow;
mod textrue;
mod channel_textrue;
mod capture;
mod channel_capture;

// Entry-point - called from dart. the function name matters.
#[no_mangle]
pub extern "C" fn rust_init_message_channel_context(data: *mut c_void) -> FunctionResult {
    START.call_once(|| {
        init_logging();
        // Run the actual initialization on main (platform) thread.
        RunLoop::sender_for_main_thread().send(init_on_main_thread);
    });

    debug!(
        "Initializing message channel context from dart thread {:?}",
        thread::current().id()
    );
    // init FFI part of message channel from data obtained from Dart side.
    irondash_init_message_channel_context(data)
}

fn init_on_main_thread() {
    debug!(
        "Initializing handlers (on platform thread: {:?})",
        thread::current().id()
    );
    assert!(RunLoop::is_main_thread());

    channel_textrue::init();
    channel_capture::init();
}

static START: Once = Once::new();

#[no_mangle]
pub extern "C" fn rust_init_texture(flutter_engine_id: i64) -> i64 {
    let runner = RunLoop::sender_for_main_thread();
    runner.send_and_wait(
        move || match init_on_main_thread_texture(flutter_engine_id) {
            Ok(id) => id,
            Err(err) => {
                println!("Error {:?}", err);
                0
            }
        },
    )
}
