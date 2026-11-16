use super::{import_identity, parse_fields, text};
use crate::state::Session;
use anyhow::{Context, Result, bail, ensure};
use data_encoding::{BASE64, BASE64URL_NOPAD};
use deadbolt_core::{DataOp, Field, FieldType, VaultId};
use p256::{ecdsa::SigningKey, pkcs8::DecodePrivateKey};
use serde_json::{Value, json};
use std::collections::{BTreeMap, BTreeSet};
use zeroize::Zeroizing;

type PasskeyIdentity = (String, String);
type PasskeyMaterial = (String, Vec<u8>);

fn passkey_identity(fields: &BTreeMap<String, Field>) -> Result<(PasskeyIdentity, PasskeyMaterial)> {
    let value = |name: &str| {
        fields
            .get(name)
            .map(|field| field.value.clone())
            .context("Incomplete passkey")
    };
    let der = Zeroizing::new(BASE64URL_NOPAD.decode(value("private-key")?.as_bytes())?);
    let key = SigningKey::from_pkcs8_der(&der).context("Invalid existing passkey key")?;
    Ok((
        (value("rp-id")?, value("credential-id")?),
        (value("user-handle")?, key.verifying_key().to_sec1_point(false).as_bytes().to_vec()),
    ))
}

fn passkey_fields(item: &Value) -> Result<BTreeMap<String, Field>> {
    let rp = text(item, "rp_id")?;
    let valid_rp = deadbolt_core::site::valid_rp_id(rp).map_err(anyhow::Error::msg)?;
    ensure!(valid_rp == rp, "Passkey relying party must be a canonical domain");
    ensure!(text(item, "credential_id")?.len() <= 1364, "Invalid passkey credential identifier");
    let credential = BASE64.decode(text(item, "credential_id")?.as_bytes())?;
    ensure!(!credential.is_empty() && credential.len() <= 1023, "Invalid passkey credential identifier");
    ensure!(text(item, "user_handle")?.len() <= 88, "Invalid passkey user handle");
    let handle = BASE64.decode(text(item, "user_handle")?.as_bytes())?;
    ensure!(!handle.is_empty() && handle.len() <= 64, "Invalid passkey user handle");
    ensure!(text(item, "private_key")?.len() <= 5464, "Unsupported passkey key format");
    let der = Zeroizing::new(BASE64.decode(text(item, "private_key")?.as_bytes())?);
    ensure!(der.len() <= 4096, "Unsupported passkey key format");
    let _key = SigningKey::from_pkcs8_der(&der).context("Only valid ES256 PKCS8 passkeys can be imported")?;
    let username = text(item, "username")?;
    let display_name = text(item, "display_name")?;
    ensure!(username.chars().count() <= 256 && display_name.chars().count() <= 256, "Passkey account name is too long");
    let mut fields = BTreeMap::from([
        ("rp-id".into(), Field::new(FieldType::Text, rp)),
        ("credential-id".into(), Field::new(FieldType::Text, BASE64URL_NOPAD.encode(&credential))),
        ("user-handle".into(), Field::new(FieldType::Text, BASE64URL_NOPAD.encode(&handle))),
        ("private-key".into(), Field::new(FieldType::Secret, BASE64URL_NOPAD.encode(&der))),
        ("created".into(), Field::new(FieldType::Date, time::OffsetDateTime::now_utc().date().to_string())),
    ]);
    for (name, value) in [("username", username), ("display-name", display_name)] {
        if !value.is_empty() {
            fields.insert(name.into(), Field::new(FieldType::Text, value));
        }
    }
    Ok(fields)
}

pub fn import(session: &mut Session, vault_id: VaultId, items: &[Value]) -> Result<Value> {
    ensure!(items.len() <= 10_000, "Import is limited to 10,000 credentials");
    let mut passkeys = BTreeMap::new();
    let mut existing = BTreeSet::new();
    for vault in session.vaults.values() {
        for item in vault.iter_items() {
            if item.kind == "passkey" {
                let (id, material) = passkey_identity(&item.fields)?;
                passkeys.entry(id).or_insert_with(Vec::new).push((vault.id(), material));
            } else if vault.id() == vault_id {
                existing.insert(import_identity(&item.kind, &item.name, &item.fields)?);
            }
        }
    }
    let mut planned = Vec::new();
    let mut skipped = 0;
    for item in items {
        let name = Some(text(item, "name")?.to_owned());
        let kind = text(item, "type")?;
        let fields = match kind {
            "login" => {
                let fields = parse_fields(&item["fields"])?;
                if !existing.insert(import_identity(kind, &name, &fields)?) {
                    skipped += 1;
                    continue;
                }
                fields
            }
            "passkey" => {
                let fields = passkey_fields(item)?;
                let (id, material) = passkey_identity(&fields)?;
                if let Some(held) = passkeys.get(&id) {
                    ensure!(held.iter().all(|(vault, _)| *vault == vault_id), "This passkey is already in another vault. Choose its existing vault");
                    ensure!(held.iter().all(|(_, key)| *key == material), "A different passkey already uses this credential identifier. Nothing was imported");
                    skipped += 1;
                    continue;
                }
                passkeys.insert(id, vec![(vault_id, material)]);
                fields
            }
            _ => bail!("Unsupported credential type"),
        };
        planned.push(DataOp::create(kind, name, fields));
    }
    if planned.is_empty() {
        return Ok(json!({"ids":[],"imported":0,"skipped":skipped}));
    }
    session.mutate(vault_id, |vault, secret| {
        let (ids, _) = vault.create_items(secret, planned)?;
        Ok(json!({"ids":ids.iter().map(ToString::to_string).collect::<Vec<_>>(),"imported":ids.len(),"skipped":skipped}))
    })
}
