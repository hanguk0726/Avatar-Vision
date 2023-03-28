use std::sync::Arc;

use kanal::{AsyncReceiver, AsyncSender, Receiver, Sender};
use nokhwa::Buffer;

pub struct ChannelHandler {
    pub rendering: (Sender<Buffer>, Receiver<Buffer>),
    pub encoding: (AsyncSender<Vec<u8>>, AsyncReceiver<Vec<u8>>),
}

impl ChannelHandler {
    pub fn new() -> Self {
        let (rendering_sender, rendering_receiver): (Sender<Buffer>, Receiver<Buffer>) =
            kanal::bounded(1);
        let (encoding_sender, encoding_receiver) = kanal::unbounded_async();

        Self {
            rendering: (rendering_sender, rendering_receiver),
            encoding: (encoding_sender, encoding_receiver),
        }
    }

    pub fn reset_encoding(&mut self) {
        let (encoding_sender, encoding_receiver) = kanal::unbounded_async();
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
