use std::sync::{Arc, Mutex};

use kanal::{AsyncReceiver, AsyncSender, Receiver, Sender};
use nokhwa::Buffer;

use crate::tools::{self, ordqueue::new};

pub struct ChannelHandler {
    pub rendering: (Sender<Buffer>, Receiver<Buffer>),
    pub encoding: (AsyncSender<Vec<u8>>, AsyncReceiver<Vec<u8>>),
    pub test: Arc<Mutex<Vec<u8>>>,
    pub queue: (
        Arc<tools::ordqueue::OrdQueue<Vec<u8>>>,
        Arc<Mutex<tools::ordqueue::OrdQueueIter<Vec<u8>>>>,
    ),
}

impl ChannelHandler {
    pub fn new() -> Self {
        let (rendering_sender, rendering_receiver): (Sender<Buffer>, Receiver<Buffer>) =
            kanal::bounded(1);
        let (encoding_sender, encoding_receiver) = kanal::bounded_async(1);
        let (queue, queue_iter) = new();
        Self {
            rendering: (rendering_sender, rendering_receiver),
            encoding: (encoding_sender, encoding_receiver),
            test: Arc::new(Mutex::new(Vec::new())),
            queue: (Arc::new(queue), Arc::new(Mutex::new(queue_iter))),
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
