

use kanal::{AsyncReceiver,  Receiver, Sender};
use nokhwa::Buffer;

pub struct ChannelHandler {
    pub rendering: (Sender<Buffer>, Receiver<Buffer>),
    pub encoding: (Sender<Vec<u8>>,Receiver<Vec<u8>>),
}

impl ChannelHandler {
    pub fn new() -> Self {
        let (rendering_sender, rendering_receiver): (Sender<Buffer>, Receiver<Buffer>) =
            kanal::bounded(1);
        let (encoding_sender, encoding_receiver) = kanal::unbounded();

        Self {
            rendering: (rendering_sender, rendering_receiver),
            encoding: (encoding_sender, encoding_receiver),
        }
    }

    pub fn reset_encoding(&mut self) {
        let (encoding_sender, encoding_receiver) = kanal::unbounded();
        self.encoding = (encoding_sender, encoding_receiver);
    }

    pub fn reset_rendering(&mut self) {
        let (rendering_sender, rendering_receiver): (Sender<Buffer>, Receiver<Buffer>) =
            kanal::bounded(1);
        self.rendering = (rendering_sender, rendering_receiver);
    }

    pub fn reset(&mut self) {
        self.reset_encoding();
        self.reset_rendering();
    }
}
