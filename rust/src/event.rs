// use std::sync::atomic::AtomicU16;

// pub struct Event {
//     state: AtomicU16,
// }

// impl Event {
//     pub fn new() -> Self {
//         Self {
//             state: AtomicU16::new(0),
//         }
//     }

//     pub fn state(&self) -> EventState {
//         match self.state.load(std::sync::atomic::Ordering::Relaxed) {
//             0 => EventState::StandBy,
//             1000 => EventState::CameraStreamOpened,
//             2000 => EventState::StoppingCameraStream,
//             _ => EventState::StandBy,
//         }
//     }
//     pub fn set_state(&self, state: EventState) {
//         self.state.store(
//             match state {
//                 EventState::StandBy => 0,
//                 EventState::CameraStreamOpened => 1000,
//                 EventState::StoppingCameraStream => 2000,
//             },
//             std::sync::atomic::Ordering::Relaxed,
//         );
//     }
// }
// #[derive(PartialEq)]
// pub enum EventState {
//     StandBy,
//     CameraStreamOpened,
//     StoppingCameraStream,
// }
