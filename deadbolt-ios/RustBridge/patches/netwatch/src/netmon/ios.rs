use n0_error::stack_error;
use n0_future::task::AbortOnDropHandle;
use tokio::sync::mpsc;
use super::actor::NetworkMessage;
#[stack_error(derive, add_meta)]
pub struct Error;
#[derive(Debug)]
pub(super) struct RouteMonitor {
    _handle: AbortOnDropHandle<()>,
}
impl RouteMonitor {
    pub(super) fn new(sender:mpsc::Sender<NetworkMessage>)->Result<Self,Error> {
        let handle=tokio::spawn(async move {
            let mut previous=crate::interfaces::State::new().await;
            let mut timer=tokio::time::interval(std::time::Duration::from_secs(5));
            loop {
                timer.tick().await;
                let current=crate::interfaces::State::new().await;
                if current!=previous {
                    previous=current;
                    if sender.send(NetworkMessage::Change).await.is_err(){break;}
                }
            }
        });
        Ok(Self{_handle:AbortOnDropHandle::new(handle)})
    }
}
