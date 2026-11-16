use crate::state::Session;
use deadbolt_core::{DeviceId, VaultId};
use deadbolt_net::{
    Blob, HandlerError, Inviter, Joiner, PairingContext, PeerId, SyncHandler,
    application::{self, State},
};
use std::sync::{Arc, Mutex};
pub type Shared = Arc<Mutex<Option<Session>>>;
#[derive(Clone)]
pub struct Handler(pub Shared);
impl Handler {
    pub fn with<T>(
        &self,
        f: impl FnOnce(&mut Session) -> anyhow::Result<T>,
    ) -> Result<T, HandlerError> {
        let mut guard = self.0.lock().map_err(|_| "State unavailable")?;
        let s = guard.as_mut().ok_or("Vault is locked")?;
        if s.poisoned {
            return Err("Unlock again to authenticate the store".into());
        }
        f(s).map_err(|e| format!("{e:#}").into())
    }
}
impl SyncHandler for Handler {
    type ReceiveState = ();
    async fn heads(&self, peer: PeerId) -> Result<Vec<u8>, HandlerError> {
        self.with(|s| {
            Ok(application::hello(
                s,
                &DeviceId::from_bytes(peer),
                s.addr.clone(),
            )?)
        })
    }
    async fn missing_for(
        &self,
        peer: PeerId,
        heads: Vec<u8>,
    ) -> Result<deadbolt_net::Outgoing<'_>, HandlerError> {
        let mut history = self
            .with(|s| application::missing_for(s, &DeviceId::from_bytes(peer), &heads, s.ready))?;
        Ok(Box::new(std::iter::from_fn(move || {
            self.with(|s| Ok(history.next(s, s.ready)?)).transpose()
        })))
    }
    async fn receive(
        &self,
        peer: PeerId,
        entries: Vec<Blob>,
        _: &mut (),
        _: bool,
    ) -> Result<(), HandlerError> {
        self.with(|s| {
            application::receive(s, &DeviceId::from_bytes(peer), entries, s.ready)?;
            Ok(())
        })
    }
}
pub struct NewDevice {
    pub handler: Handler,
    pub offer: Mutex<Option<application::Offer>>,
}
impl Joiner for NewDevice {
    type Welcome = application::WelcomeReplay;
    async fn join(&self, ctx: &PairingContext, bytes: Vec<u8>) -> Result<Vec<u8>, HandlerError> {
        let (offer, vault) = application::read_offer(&bytes)?;
        let join = self.handler.with(|s| {
            anyhow::ensure!(!s.vaults.contains_key(&vault), "Vault already held");
            Ok(application::join_blob(
                &s.secret,
                &s.name,
                DeviceId::from_bytes(ctx.remote),
                &vault,
                s.addr.clone(),
            )?)
        })?;
        *self.offer.lock().map_err(|_| "State unavailable")? = Some(offer);
        Ok(join)
    }
    async fn receive(
        &self,
        ctx: &PairingContext,
        welcome: Self::Welcome,
    ) -> Result<(), HandlerError> {
        let offer = self
            .offer
            .lock()
            .map_err(|_| "State unavailable")?
            .take()
            .ok_or("Missing offer")?;
        let welcomed = application::verify_welcome(
            &DeviceId::from_bytes(ctx.local),
            DeviceId::from_bytes(ctx.remote),
            offer,
            welcome,
        )?;
        self.handler.with(|s| {
            s.learn(
                &welcomed.inviter,
                &welcomed.inviter_name,
                welcomed.inviter_addr,
                welcomed.peers,
            )?;
            s.add_vault(welcomed.vault)
        })
    }
}
pub struct ExistingDevice {
    pub handler: Handler,
    pub vault: VaultId,
}
impl Inviter for ExistingDevice {
    async fn offer(&self, ctx: &PairingContext) -> Result<Vec<u8>, HandlerError> {
        self.handler.with(|s| {
            Ok(application::offer(
                s,
                self.vault,
                &DeviceId::from_bytes(ctx.remote),
                s.addr.clone(),
            )?)
        })
    }
    async fn welcome(
        &self,
        ctx: &PairingContext,
        join: Vec<u8>,
    ) -> Result<deadbolt_net::Outgoing<'_>, HandlerError> {
        let mut history = self.handler.with(|s| {
            application::welcome(s, self.vault, DeviceId::from_bytes(ctx.remote), &join, None)
        })?;
        Ok(Box::new(std::iter::from_fn(move || {
            self.handler
                .with(|s| Ok(history.next(s, s.ready)?))
                .transpose()
        })))
    }
}
