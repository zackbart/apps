use anyhow::{Context, Result};
use deadbolt_core::{DeviceId, DeviceSecret, Entry, Vault, VaultId, VaultWrite};
use deadbolt_net::application::{self, Addr, Hint, State};
use deadbolt_store::Unlocked;
use std::{collections::BTreeMap, path::Path};

pub struct Session {
    pub store: Unlocked,
    pub secret: DeviceSecret,
    pub name: String,
    pub vaults: BTreeMap<VaultId, Vault>,
    pub peers: BTreeMap<String, Hint>,
    pub addr: Option<Addr>,
    pub poisoned: bool,
    pub ready: bool,
}

impl Session {
    pub fn open(store: Unlocked) -> Result<Self> {
        let secret = DeviceSecret::from_bytes(store.device_secret());
        let name = store
            .meta_get("cli/device-name")?
            .map(|b| serde_json::from_slice(&b))
            .transpose()?
            .unwrap_or_else(|| "iPhone".into());
        let peers = store
            .meta_get("cli/peers")?
            .map(|b| serde_json::from_slice(&b))
            .transpose()?
            .unwrap_or_default();
        let mut grouped: BTreeMap<VaultId, Vec<Entry>> = BTreeMap::new();
        for row in store.iter_all()? {
            let entry = Entry::decode(&row?)?;
            grouped.entry(entry.vault()).or_default().push(entry);
        }
        let vaults = grouped
            .into_iter()
            .map(|(id, entries)| Ok((id, Vault::load(entries)?)))
            .collect::<Result<_>>()?;
        Ok(Self {
            store,
            secret,
            name,
            peers,
            vaults,
            addr: None,
            poisoned: false,
            ready: true,
        })
    }
    pub fn create(dir: &Path, pass: &str, name: &str) -> Result<Self> {
        let key = DeviceSecret::generate();
        let store = deadbolt_store::init(dir, pass.as_bytes(), *key.to_bytes())?;
        store.meta_set("cli/device-name", &serde_json::to_vec(name)?)?;
        Self::open(store)
    }
    pub fn add_vault(&mut self, vault: Vault) -> Result<()> {
        if let Err(error) = self
            .store
            .append_batch(vault.iter_entries().map(Entry::encode))
        {
            if error.append_diagnostic().is_some() {
                self.poisoned = true;
                self.vaults.clear();
            }
            return Err(error.into());
        }
        self.vaults.insert(vault.id(), vault);
        Ok(())
    }
    pub fn mutate<T>(
        &mut self,
        id: VaultId,
        change: impl FnOnce(&mut VaultWrite<'_>, &DeviceSecret) -> Result<T>,
    ) -> Result<T> {
        anyhow::ensure!(!self.poisoned, "Unlock again to authenticate the store");
        let store = &self.store;
        let secret = &self.secret;
        let result = self
            .vaults
            .get_mut(&id)
            .context("Vault not held")?
            .transact(
                |v| change(v, secret),
                |entries| {
                    store.append_batch(entries.iter().map(|e| e.encode()))?;
                    Ok(())
                },
            );
        if result
            .as_ref()
            .err()
            .and_then(|e| e.downcast_ref::<deadbolt_store::Error>())
            .and_then(|e| e.append_diagnostic())
            .is_some()
        {
            self.poisoned = true;
            self.vaults.clear();
        }
        result
    }
    pub fn persist_peers(&self) -> Result<()> {
        self.store
            .meta_set("cli/peers", &serde_json::to_vec(&self.peers)?)?;
        Ok(())
    }
}
impl State for Session {
    type Error = anyhow::Error;
    fn device_id(&self) -> DeviceId {
        self.secret.device_id()
    }
    fn device_name(&self) -> &str {
        &self.name
    }
    fn vaults(&self) -> impl Iterator<Item = &Vault> {
        self.vaults.values()
    }
    fn hints_for(&self, peer: &DeviceId) -> BTreeMap<String, Hint> {
        self.vaults
            .values()
            .filter(|v| v.is_member(peer))
            .flat_map(|v| v.members())
            .filter(|id| id != peer && *id != self.device_id())
            .filter_map(|id| {
                self.peers
                    .get(&id.to_string())
                    .map(|hint| (id.to_string(), hint.clone()))
            })
            .collect()
    }
    fn update<T>(
        &mut self,
        id: VaultId,
        change: impl FnOnce(
            &mut VaultWrite<'_>,
            &DeviceSecret,
        ) -> std::result::Result<T, application::Error>,
    ) -> Result<T> {
        self.mutate(id, |v, s| Ok(change(v, s)?))
    }
    fn learn(
        &mut self,
        peer: &DeviceId,
        name: &str,
        addr: Option<Addr>,
        hints: BTreeMap<String, Hint>,
    ) -> Result<()> {
        for (id, hint) in hints {
            self.peers.entry(id).or_insert(hint);
        }
        self.peers.insert(
            peer.to_string(),
            Hint {
                name: Some(application::clean_name(name)),
                addr,
                addr_seen: super::now(),
            },
        );
        self.persist_peers()
    }
    fn received(&mut self, _: &DeviceId) -> Result<()> {
        Ok(())
    }
}
