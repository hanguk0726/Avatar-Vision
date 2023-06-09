use std::time::Instant;

use kanal::{Receiver, Sender};
use nokhwa::Buffer;

pub struct ChannelService {
    pub rendering: (Sender<(Buffer, Instant)>, Receiver<(Buffer, Instant)>),
    pub recording: (Sender<(Buffer, Instant)>, Receiver<(Buffer, Instant)>),
    pub encoding: (Sender<Buffer>, Receiver<Buffer>),
}

impl ChannelService {
    pub fn new() -> Self {
        let (rendering_sender, rendering_receiver): (
            Sender<(Buffer, Instant)>,
            Receiver<(Buffer, Instant)>,
        ) = kanal::bounded(1);
        let (recording_sender, recording_receiver): (
            Sender<(Buffer, Instant)>,
            Receiver<(Buffer, Instant)>,
        ) = kanal::bounded(1);
        let (encoding_sender, encoding_receiver) = kanal::unbounded();
        Self {
            rendering: (rendering_sender, rendering_receiver),
            recording: (recording_sender, recording_receiver),
            encoding: (encoding_sender, encoding_receiver),
        }
    }

    pub fn reset_encoding(&mut self) {
        let (encoding_sender, encoding_receiver) = kanal::unbounded();
        self.encoding = (encoding_sender, encoding_receiver);
    }

    pub fn reset_recording(&mut self) {
        let (recording_sender, recording_receiver): (
            Sender<(Buffer, Instant)>,
            Receiver<(Buffer, Instant)>,
        ) = kanal::bounded(1);
        self.recording = (recording_sender, recording_receiver);
    }

    pub fn reset_rendering(&mut self) {
        let (rendering_sender, rendering_receiver): (
            Sender<(Buffer, Instant)>,
            Receiver<(Buffer, Instant)>,
        ) = kanal::bounded(1);
        self.rendering = (rendering_sender, rendering_receiver);
    }

    pub fn reset(&mut self) {
        self.reset_encoding();
        self.reset_recording();
        self.reset_rendering();
    }
}
