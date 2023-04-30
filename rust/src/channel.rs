use std::sync::{Arc, Mutex};

use kanal::{AsyncReceiver, AsyncSender, Receiver, Sender};
use nokhwa::Buffer;

use crate::tools::{self, ordqueue::new};

pub struct ChannelHandler {
    pub rendering: (Sender<Buffer>, Receiver<Buffer>),
    pub encoding: (AsyncSender<Vec<u8>>, AsyncReceiver<Vec<u8>>),
}

impl ChannelHandler {
    pub fn new() -> Self {
        let (rendering_sender, rendering_receiver): (Sender<Buffer>, Receiver<Buffer>) =
            kanal::bounded(1);
        let (encoding_sender, encoding_receiver) = kanal::bounded_async(1);
        Self {
            rendering: (rendering_sender, rendering_receiver),
            encoding: (encoding_sender, encoding_receiver),
        }
    }

    pub fn reset_encoding(&mut self) {
        let (encoding_sender, encoding_receiver) = kanal::bounded_async(1);
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
