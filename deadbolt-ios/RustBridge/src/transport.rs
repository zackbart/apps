use crate::{
    network::{Handler, Shared},
    unhex,
};
use anyhow::{Context, Result};
use deadbolt_core::DeviceId;
use deadbolt_net::{Node, NodeConfig, PeerAddr, application::Addr};
use serde_json::{Value, json};
use std::{
    collections::{BTreeMap, BTreeSet},
    sync::{Arc, Mutex},
    time::Duration,
};
#[derive(Clone, Default)]
pub struct Transport {
    pub node: Arc<Mutex<Option<Node>>>,
    gate: Arc<tokio::sync::Mutex<()>>,
    contacted: Arc<Mutex<BTreeSet<String>>>,
}
impl Transport {
    pub fn current(&self) -> Option<Node> {
        self.node.lock().ok().and_then(|n| n.clone())
    }
    pub async fn ensure(&self, session: Shared) -> Result<Node> {
        let _guard = self.gate.lock().await;
        let handler = Handler(session.clone());
        if let Some(node) = self.current() {
            if handler
                .with(|s| Ok(s.ready))
                .map_err(|e| anyhow::anyhow!(e.to_string()))?
            {
                return Ok(node);
            }
        }
        let node = if let Some(node) = self.current() {
            node
        } else {
            let key = handler
                .with(|s| {
                    s.ready = false;
                    Ok(*s.secret.to_bytes())
                })
                .map_err(|e| anyhow::anyhow!(e.to_string()))?;
            let members = session.clone();
            let membership = Arc::new(move |peer: &[u8; 32]| {
                members
                    .lock()
                    .ok()
                    .and_then(|s| {
                        s.as_ref().map(|s| {
                            !s.poisoned
                                && s.vaults
                                    .values()
                                    .any(|v| v.is_member(&DeviceId::from_bytes(*peer)))
                        })
                    })
                    .unwrap_or(false)
            });
            let node = tokio::time::timeout(
                Duration::from_secs(10),
                Node::spawn(NodeConfig::new(key), membership, handler.clone()),
            )
            .await
            .context("Network startup timed out")??;
            *self
                .node
                .lock()
                .map_err(|_| anyhow::anyhow!("Network unavailable"))? = Some(node.clone());
            handler
                .with(|s| {
                    s.addr = Some(Addr::from_peer(node.addr()));
                    Ok(())
                })
                .map_err(|e| anyhow::anyhow!(e.to_string()))?;
            node
        };
        let contacted = self
            .contacted
            .lock()
            .map_err(|_| anyhow::anyhow!("Network unavailable"))?
            .clone();
        let pending = targets(&session)?
            .into_iter()
            .filter(|peer| !contacted.contains(&crate::HEXLOWER.encode(&peer.id)))
            .collect();
        let (_, complete, finished) = round(
            &node,
            pending,
            Duration::from_secs(5),
            Duration::from_secs(12),
        )
        .await;
        self.contacted
            .lock()
            .map_err(|_| anyhow::anyhow!("Network unavailable"))?
            .extend(finished);
        anyhow::ensure!(
            complete,
            "Membership sync interrupted; retry before sharing vault data"
        );
        handler
            .with(|s| {
                s.ready = true;
                Ok(())
            })
            .map_err(|e| anyhow::anyhow!(e.to_string()))?;
        Ok(node)
    }
    pub async fn close(&self) {
        if let Ok(mut contacted) = self.contacted.lock() {
            contacted.clear();
        }
        let node = self.node.lock().ok().and_then(|mut n| n.take());
        if let Some(node) = node {
            let _ = tokio::time::timeout(Duration::from_secs(3), node.shutdown()).await;
        }
    }
}
pub fn targets(shared: &Shared) -> Result<Vec<PeerAddr>> {
    let guard = shared
        .lock()
        .map_err(|_| anyhow::anyhow!("State unavailable"))?;
    let session = guard.as_ref().context("Vault is locked")?;
    let me = session.secret.device_id();
    let mut peers = BTreeMap::new();
    for vault in session.vaults.values().filter(|v| v.is_member(&me)) {
        for id in vault.members().filter(|id| *id != me) {
            let bytes = unhex(&id.to_string())?;
            let addr = session
                .peers
                .get(&id.to_string())
                .and_then(|p| p.addr.as_ref())
                .map(|a| a.peer(bytes))
                .unwrap_or_else(|| PeerAddr::from(bytes));
            peers.insert(id, addr);
        }
    }
    Ok(peers.into_values().collect())
}
pub async fn round(
    node: &Node,
    peers: Vec<PeerAddr>,
    per_peer: Duration,
    total: Duration,
) -> (Vec<Value>, bool, Vec<String>) {
    let ids = peers
        .iter()
        .map(|p| crate::HEXLOWER.encode(&p.id))
        .collect::<Vec<_>>();
    let count = peers.len();
    let mut peers = peers.into_iter();
    let mut tasks = tokio::task::JoinSet::new();
    let deadline = tokio::time::Instant::now() + total;
    let mut results = Vec::new();
    let mut complete = true;
    let mut contacted = Vec::new();
    loop {
        while tasks.len() < 4 {
            let Some(peer) = peers.next() else {
                break;
            };
            let node = node.clone();
            tasks.spawn(async move {
                let id = crate::HEXLOWER.encode(&peer.id);
                let until = tokio::time::Instant::now() + per_peer;
                let connection = match tokio::time::timeout_at(until, node.connect(peer)).await {
                    Ok(Ok(connection)) => connection,
                    Ok(Err(deadbolt_net::Error::Rejected(error))) => {
                        return (json!({"id":id,"ok":false,"error":error}), false);
                    }
                    Ok(Err(error)) => {
                        return (json!({"id":id,"ok":false,"error":error.to_string()}), true);
                    }
                    Err(_) => {
                        return (json!({"id":id,"ok":false,"error":"Peer unreachable"}), true);
                    }
                };
                let result = tokio::time::timeout_at(until, connection.sync()).await;
                connection.close();
                match result {
                    Ok(Ok(out)) => (
                        json!({"id":id,"ok":true,"sent":out.sent,"received":out.received}),
                        true,
                    ),
                    Ok(Err(deadbolt_net::Error::MembershipRejected(error))) => {
                        (json!({"id":id,"ok":false,"error":error}), true)
                    }
                    Ok(Err(error)) => {
                        (json!({"id":id,"ok":false,"error":error.to_string()}), false)
                    }
                    Err(_) => (json!({"id":id,"ok":false,"error":"Sync timed out"}), false),
                }
            });
        }
        if tasks.is_empty() {
            break;
        }
        match tokio::time::timeout_at(deadline, tasks.join_next()).await {
            Ok(Some(Ok((result, finished)))) => {
                if finished {
                    if let Some(id) = result["id"].as_str() {
                        contacted.push(id.to_string());
                    }
                }
                results.push(result);
                complete &= finished;
            }
            Ok(Some(Err(_))) => complete = false,
            _ => {
                complete = false;
                break;
            }
        }
    }
    tasks.abort_all();
    complete &= results.len() == count;
    for id in ids {
        if !results.iter().any(|r| r["id"].as_str() == Some(&id)) {
            results.push(json!({"id":id,"ok":false,"error":"Global sync deadline reached"}));
        }
    }
    (results, complete, contacted)
}
