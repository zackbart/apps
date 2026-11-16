use super::*;
use p256::elliptic_curve::Generate;
use deadbolt_net::{Node, NodeConfig};
use deadbolt_net::{
    WelcomeSink,
    application::{self, State},
};

#[test]
fn exchange_passkey_survives_import_sync_reopen_and_signs_with_original_key() {
    use p256::{ecdsa::{DerSignature, SigningKey, signature::Verifier}, pkcs8::EncodePrivateKey};
    let key = SigningKey::generate();
    let der = key.to_pkcs8_der().unwrap();
    let source = tempfile::tempdir().unwrap();
    let destination = tempfile::tempdir().unwrap();
    let mut a = create(source.path(), "Importer");
    let mut b = create(destination.path(), "Peer");
    let (vault, _) = Vault::create(&a.secret, "imported").unwrap();
    let id = vault.id();
    a.add_vault(vault).unwrap();
    pair(&mut a, &mut b, id);
    let credential = json!({"type":"passkey","name":"Imported passkey","rp_id":"example.com","username":"alice","display_name":"Alice","credential_id":BASE64.encode(b"existing-id"),"user_handle":BASE64.encode(b"existing-handle"),"private_key":BASE64.encode(der.as_bytes())});
    let login = json!({"type":"login","name":"Imported login","fields":{"username":{"type":"text","value":"alice"},"password":{"type":"secret","value":"disposable-export-password"},"otp":{"type":"otp","value":"otpauth://totp/Example:alice?secret=JBSWY3DPEHPK3PXP&algorithm=SHA256&digits=8&period=60"}}});
    let result = exchange::import(&mut a, id, &[login.clone(), credential.clone()]).unwrap();
    assert_eq!(result["imported"], 2);
    let mut equivalent = credential.clone();
    let mut compact_der = vec![0x30,0x41,0x02,0x01,0x00,0x30,0x13,0x06,0x07,0x2a,0x86,0x48,0xce,0x3d,0x02,0x01,0x06,0x08,0x2a,0x86,0x48,0xce,0x3d,0x03,0x01,0x07,0x04,0x27,0x30,0x25,0x02,0x01,0x01,0x04,0x20];
    compact_der.extend_from_slice(&key.to_bytes());
    equivalent["private_key"] = json!(BASE64.encode(&compact_der));
    equivalent["name"] = json!("Different exporter label");
    let again = exchange::import(&mut a, id, &[login, credential, equivalent]).unwrap();
    assert_eq!(again["imported"], 0);
    assert_eq!(again["skipped"], 3);
    transfer(&mut a, &mut b);
    drop(a);
    let a = Session::open(deadbolt_store::unlock(source.path(), b"a strong local test passphrase").unwrap()).unwrap();
    let hash = deadbolt_core::webauthn::b64(&[83; 32]);
    for session in [&a, &b] {
        let passkey = session.vaults[&id].iter_items().find(|item| item.kind == "passkey").unwrap();
        let signed = deadbolt_core::passkeys::sign_hash(&passkey, "example.com", &hash, true).unwrap();
        assert_eq!(deadbolt_core::webauthn::unb64(&signed.credential_id).unwrap(), b"existing-id");
        assert_eq!(deadbolt_core::webauthn::unb64(&signed.user_handle).unwrap(), b"existing-handle");
        let mut message = deadbolt_core::webauthn::unb64(&signed.authenticator_data).unwrap();
        message.extend_from_slice(&[83; 32]);
        let signature = deadbolt_core::webauthn::unb64(&signed.signature).unwrap();
        key.verifying_key().verify(&message, &DerSignature::from_bytes(&signature).unwrap()).unwrap();
        assert!(deadbolt_core::passkeys::sign_hash(&passkey, "other.example", &hash, true).is_err());
        assert!(item_json(id, passkey)["fields"].get("private-key").is_none());
        let login = session.vaults[&id].iter_items().find(|item| item.kind == "login").unwrap();
        assert!(login.fields["otp"].value.contains("algorithm=SHA256&digits=8&period=60"));
    }
}

#[test]
fn exchange_rejects_invalid_and_conflicting_keys_atomically() {
    use p256::{ecdsa::SigningKey, pkcs8::EncodePrivateKey};
    let key = SigningKey::generate().to_pkcs8_der().unwrap();
    let dir = tempfile::tempdir().unwrap();
    let mut session = create(dir.path(), "Importer");
    let (vault, _) = Vault::create(&session.secret, "imported").unwrap();
    let id = vault.id();
    session.add_vault(vault).unwrap();
    let passkey = json!({"type":"passkey","name":"Passkey","rp_id":"example.com","username":"alice","display_name":"Alice","credential_id":BASE64.encode(b"credential"),"user_handle":BASE64.encode(b"alice"),"private_key":BASE64.encode(key.as_bytes())});
    let login = json!({"type":"login","name":"New login","fields":{"password":{"type":"secret","value":"disposable"}}});
    for (field, invalid) in [("private_key", BASE64.encode(b"not a key")), ("rp_id", "https://example.com".into()), ("user_handle", BASE64.encode(&[0;65])), ("credential_id", String::new())] {
        let mut bad = passkey.clone();
        bad[field] = json!(invalid);
        assert!(exchange::import(&mut session, id, &[login.clone(), bad]).is_err());
        assert_eq!(session.vaults[&id].iter_items().count(), 0);
    }
    exchange::import(&mut session, id, &[passkey.clone()]).unwrap();
    let mut conflicting = passkey.clone();
    conflicting["private_key"] = json!(BASE64.encode(SigningKey::generate().to_pkcs8_der().unwrap().as_bytes()));
    assert!(exchange::import(&mut session, id, &[login.clone(), conflicting]).is_err());
    assert_eq!(session.vaults[&id].iter_items().count(), 1);
    let (other, _) = Vault::create(&session.secret, "other").unwrap();
    let other_id = other.id();
    session.add_vault(other).unwrap();
    assert!(exchange::import(&mut session, other_id, &[login.clone(), passkey]).is_err());
    assert_eq!(session.vaults[&other_id].iter_items().count(), 0);
    assert!(exchange::import(&mut session, id, &[login, json!({"type":"unsupported","name":"Rejected"})]).is_err());
    assert_eq!(session.vaults[&id].iter_items().count(), 1);
}

fn create(path: &Path, name: &str) -> Session {
    Session::create(path, "a strong local test passphrase", name).unwrap()
}
fn pair(a: &mut Session, b: &mut Session, vault: VaultId) {
    let inviter = a.device_id();
    let device = b.device_id();
    let offer = application::offer(a, vault, &device, None).unwrap();
    let (offer, id) = application::read_offer(&offer).unwrap();
    let consent = application::join_blob(&b.secret, &b.name, inviter, &id, None).unwrap();
    let mut history = application::welcome(a, vault, device, &consent, None).unwrap();
    let mut replay = application::WelcomeReplay::default();
    while let Some(blob) = history.next(a, true).unwrap() {
        replay.push(blob).unwrap();
    }
    let welcomed = application::verify_welcome(&device, inviter, offer, replay).unwrap();
    b.add_vault(welcomed.vault).unwrap();
}
fn transfer(a: &mut Session, b: &mut Session) {
    let peer = b.device_id();
    let hello = application::hello(b, &a.device_id(), None).unwrap();
    let mut outgoing = application::missing_for(a, &peer, &hello, true).unwrap();
    let mut frames = vec![];
    while let Some(blob) = outgoing.next(a, true).unwrap() {
        frames.push(blob);
    }
    application::receive(b, &a.device_id(), frames, true).unwrap();
}
#[test]
fn encrypted_crud_reopen_and_biometric_slot() {
    let dir = tempfile::tempdir().unwrap();
    let mut s = create(dir.path(), "iPhone");
    let (vault, _) = Vault::create(&s.secret, "personal").unwrap();
    let id = vault.id();
    s.add_vault(vault).unwrap();
    let fields = BTreeMap::from([(
        "password".into(),
        Field {
            kind: FieldType::Secret,
            value: "hidden-vault-password-123".into(),
        },
    )]);
    let item = s
        .mutate(id, |w, key| {
            Ok(w.create_item(key, "login", Some("Example".into()), fields)?
                .0)
        })
        .unwrap();
    s.mutate(id, |w, key| {
        w.write(
            key,
            vec![
                DataOp::Edit {
                    item,
                    change: Change::Set {
                        field: "username".into(),
                        value: Field {
                            kind: FieldType::Text,
                            value: "updated-user".into(),
                        },
                    },
                },
                DataOp::Edit {
                    item,
                    change: Change::Delete { at: Some(now()) },
                },
            ],
        )?;
        Ok(())
    })
    .unwrap();
    assert!(s.vaults[&id].item(&item).unwrap().deleted);
    let key = deadbolt_store::generate_biometric_key().unwrap();
    s.store.set_biometric(&key, b"test").unwrap();
    drop(s);
    assert!(matches!(
        deadbolt_store::unlock(dir.path(), b"wrong"),
        Err(deadbolt_store::Error::WrongPassphrase)
    ));
    let s = Session::open(deadbolt_store::unlock_biometric(dir.path(), &key).unwrap()).unwrap();
    assert_eq!(
        s.vaults[&id].item(&item).unwrap().fields["password"].value,
        "hidden-vault-password-123"
    );
    drop(s);
    let bytes = std::fs::read(dir.path().join(deadbolt_store::DB_FILE)).unwrap();
    assert!(!bytes.windows(25).any(|b| b == b"hidden-vault-password-123"));
}
#[test]
fn two_peer_pairing_offline_conflict_converges_and_survives_reopen() {
    let da = tempfile::tempdir().unwrap();
    let db = tempfile::tempdir().unwrap();
    let mut a = create(da.path(), "Desktop");
    let mut b = create(db.path(), "iPhone");
    let (vault, _) = Vault::create(&a.secret, "shared").unwrap();
    let id = vault.id();
    a.add_vault(vault).unwrap();
    let item = a
        .mutate(id, |w, key| {
            Ok(w.create_item(
                key,
                "login",
                Some("Login".into()),
                [(
                    "password".into(),
                    Field {
                        kind: FieldType::Secret,
                        value: "original".into(),
                    },
                )],
            )?
            .0)
        })
        .unwrap();
    pair(&mut a, &mut b, id);
    assert!(a.vaults[&id].is_member(&b.device_id()));
    for (s, value) in [
        (&mut a, "desktop offline edit"),
        (&mut b, "phone offline edit"),
    ] {
        s.mutate(id, |w, key| {
            w.write(
                key,
                vec![DataOp::Edit {
                    item,
                    change: Change::Set {
                        field: "password".into(),
                        value: Field {
                            kind: FieldType::Secret,
                            value: value.into(),
                        },
                    },
                }],
            )?;
            Ok(())
        })
        .unwrap();
    }
    assert_ne!(a.vaults[&id].item(&item), b.vaults[&id].item(&item));
    transfer(&mut a, &mut b);
    transfer(&mut b, &mut a);
    assert_eq!(a.vaults[&id].item(&item), b.vaults[&id].item(&item));
    assert!(a.vaults[&id].history(&item).len() >= 3);
    drop(a);
    drop(b);
    let a = Session::open(
        deadbolt_store::unlock(da.path(), b"a strong local test passphrase").unwrap(),
    )
    .unwrap();
    let b = Session::open(
        deadbolt_store::unlock(db.path(), b"a strong local test passphrase").unwrap(),
    )
    .unwrap();
    assert_eq!(a.vaults[&id].item(&item), b.vaults[&id].item(&item));
}
#[test]
fn malformed_json_and_locked_reads_fail_without_panicking() {
    assert_eq!(
        serde_json::from_str::<Value>(&request_json("{")).unwrap()["ok"],
        false
    );
    let dir = tempfile::tempdir().unwrap();
    let response = request_json(&json!({"op":"list","data_dir":dir.path()}).to_string());
    assert_eq!(
        serde_json::from_str::<Value>(&response).unwrap()["ok"],
        false
    );
}
#[tokio::test]
async fn real_iroh_membership_gated_two_peer_sync() {
    let da = tempfile::tempdir().unwrap();
    let db = tempfile::tempdir().unwrap();
    let mut a = create(da.path(), "Desktop");
    let b = create(db.path(), "iPhone");
    let (vault, _) = Vault::create(&a.secret, "shared").unwrap();
    let id = vault.id();
    a.add_vault(vault).unwrap();
    let a = Arc::new(Mutex::new(Some(a)));
    let b = Arc::new(Mutex::new(Some(b)));
    async fn node(shared: Shared) -> Node {
        let key = *shared.lock().unwrap().as_ref().unwrap().secret.to_bytes();
        let members = shared.clone();
        Node::spawn(
            NodeConfig::local_only(key),
            Arc::new(move |peer: &[u8; 32]| {
                members
                    .lock()
                    .unwrap()
                    .as_ref()
                    .unwrap()
                    .vaults
                    .values()
                    .any(|v| v.is_member(&DeviceId::from_bytes(*peer)))
            }),
            Handler(shared),
        )
        .await
        .unwrap()
    }
    let na = node(a.clone()).await;
    let nb = node(b.clone()).await;
    let code = PairingCode::generate().unwrap();
    let listener = nb
        .start_pairing(&code, PairingOptions::default())
        .await
        .unwrap();
    let joiner = network::NewDevice {
        handler: Handler(b.clone()),
        offer: Mutex::new(None),
    };
    let inviter = network::ExistingDevice {
        handler: Handler(a.clone()),
        vault: id,
    };
    let (joined, approved) = tokio::time::timeout(Duration::from_secs(30), async {
        tokio::join!(
            listener.complete(&joiner),
            na.pair(&code, PairingOptions::default(), &inviter)
        )
    })
    .await
    .unwrap();
    joined.unwrap();
    approved.unwrap();
    let item = a
        .lock()
        .unwrap()
        .as_mut()
        .unwrap()
        .mutate(id, |w, key| {
            Ok(w.create_item(
                key,
                "login",
                Some("QUIC".into()),
                [(
                    "password".into(),
                    Field {
                        kind: FieldType::Secret,
                        value: "real transport".into(),
                    },
                )],
            )?
            .0)
        })
        .unwrap();
    let result = tokio::time::timeout(Duration::from_secs(15), na.sync(nb.addr()))
        .await
        .unwrap()
        .unwrap();
    assert!(result.sent > 0);
    assert_eq!(
        b.lock().unwrap().as_ref().unwrap().vaults[&id]
            .item(&item)
            .unwrap()
            .fields["password"]
            .value,
        "real transport"
    );
    let removed = b.lock().unwrap().as_ref().unwrap().device_id();
    a.lock()
        .unwrap()
        .as_mut()
        .unwrap()
        .mutate(id, |w, key| {
            w.remove(key, removed)?;
            Ok(())
        })
        .unwrap();
    na.enforce_membership();
    assert!(matches!(
        na.sync(nb.addr()).await,
        Err(deadbolt_net::Error::NotAMember(_))
    ));
    na.shutdown().await;
    nb.shutdown().await;
}
#[test]
fn native_passkey_registration_assertion_persistence_and_rp_binding() {
    use p256::{
        ecdsa::{DerSignature, VerifyingKey, signature::Verifier},
        pkcs8::DecodePublicKey,
    };
    let dir = tempfile::tempdir().unwrap();
    let call = |mut request: Value| {
        request["data_dir"] = json!(dir.path());
        serde_json::from_str::<Value>(&request_json(&request.to_string())).unwrap()
    };
    assert_eq!(
        call(
            json!({"op":"create","passphrase":"passkey local test passphrase","vault_name":"personal"})
        )["ok"],
        true
    );
    let client = BASE64.encode(&[42; 32]);
    let registered = call(
        json!({"op":"passkey_register","rp_id":"example.com","username":"zack","user_handle":BASE64.encode(b"user-handle"),"client_data_hash":client,"algorithms":[-7],"verified":true}),
    );
    assert_eq!(registered["ok"], true, "{registered}");
    let result = &registered["result"];
    let public = BASE64
        .decode(result["public_key"].as_str().unwrap().as_bytes())
        .unwrap();
    let credential = result["credential_id"].clone();
    let duplicate = call(
        json!({"op":"passkey_register","rp_id":"example.com","username":"zack","user_handle":BASE64.encode(b"user-handle"),"client_data_hash":client,"algorithms":[-7],"exclude":[credential],"verified":true}),
    );
    assert_eq!(duplicate["ok"], false);
    assert_eq!(
        call(json!({"op":"passkey_list"}))["result"]
            .as_array()
            .unwrap()
            .len(),
        1
    );

    let listed = call(json!({"op":"list"}));
    assert!(listed["result"][0]["fields"].get("private-key").is_none());
    assert_eq!(call(json!({"op":"lock"}))["ok"], true);
    assert_eq!(
        call(json!({"op":"unlock","passphrase":"passkey local test passphrase"}))["ok"],
        true
    );
    let assertion = call(
        json!({"op":"passkey_assert","rp_id":"example.com","credential_id":credential,"client_data_hash":client,"verified":true}),
    );
    assert_eq!(assertion["ok"], true, "{assertion}");
    let mut signed = BASE64
        .decode(
            assertion["result"]["authenticator_data"]
                .as_str()
                .unwrap()
                .as_bytes(),
        )
        .unwrap();
    assert_eq!(signed[32] & 0x05, 0x05);
    signed.extend_from_slice(&[42; 32]);
    let signature = BASE64
        .decode(
            assertion["result"]["signature"]
                .as_str()
                .unwrap()
                .as_bytes(),
        )
        .unwrap();
    let verifier = VerifyingKey::from_public_key_der(&public).unwrap();
    verifier
        .verify(&signed, &DerSignature::from_bytes(&signature).unwrap())
        .unwrap();
    signed[0] ^= 1;
    assert!(
        verifier
            .verify(&signed, &DerSignature::from_bytes(&signature).unwrap())
            .is_err()
    );
    assert_eq!(
        call(
            json!({"op":"passkey_assert","rp_id":"evil.example","credential_id":credential,"client_data_hash":client,"verified":true})
        )["ok"],
        false
    );
    assert_eq!(
        call(
            json!({"op":"passkey_assert","rp_id":"example.com","credential_id":credential,"client_data_hash":client,"verified":false})
        )["ok"],
        false
    );
    assert_eq!(call(json!({"op":"lock"}))["ok"], true);
}
#[test]
fn bridge_import_is_atomic_and_save_preserves_custom_fields() {
    let dir = tempfile::tempdir().unwrap();
    let call = |mut v: Value| {
        v["data_dir"] = json!(dir.path());
        serde_json::from_str::<Value>(&request_json(&v.to_string())).unwrap()
    };
    assert_eq!(
        call(
            json!({"op":"create","passphrase":"another local test passphrase","vault_name":"personal"})
        )["ok"],
        true
    );
    let item = json!({"type":"login","name":"Imported","fields":{"password":{"type":"secret","value":"first-password"},"custom":{"type":"text","value":"preserve-me"},"private-key":{"type":"secret","value":"custom-secret"}}});
    assert_eq!(
        call(json!({"op":"import","items":[item,{"type":"not-a-real-type","fields":{}}]}))["ok"],
        false
    );
    assert_eq!(
        call(json!({"op":"list"}))["result"]
            .as_array()
            .unwrap()
            .len(),
        0
    );
    let imported = call(json!({"op":"import","items":[item]}));
    assert_eq!(imported["ok"], true, "{imported}");
    let id = imported["result"]["ids"][0].clone();
    assert_eq!(imported["result"]["imported"], 1);
    let repeated = call(json!({"op":"import","deduplicate":true,"items":[item,item]}));
    assert_eq!(repeated["result"]["imported"], 0);
    assert_eq!(repeated["result"]["skipped"], 2);
    let distinct = json!({"type":"login","name":"Distinct","fields":{"password":{"type":"secret","value":"new"}}});
    let batch = call(json!({"op":"import","deduplicate":true,"items":[distinct,distinct]}));
    assert_eq!(batch["result"]["imported"], 1);
    assert_eq!(batch["result"]["skipped"], 1);
    assert_eq!(
        call(json!({"op":"delete","id":batch["result"]["ids"][0]}))["ok"],
        true
    );
    let reimport = call(json!({"op":"import","deduplicate":true,"items":[distinct]}));
    assert_eq!(reimport["result"]["imported"], 1);
    assert_eq!(reimport["result"]["skipped"], 0);
    assert_eq!(
        call(json!({"op":"delete","id":reimport["result"]["ids"][0]}))["ok"],
        true
    );
    assert_eq!(
        call(
            json!({"op":"import","deduplicate":true,"items":[{"type":"login","name":"valid","fields":{}},{"type":"invalid-kind","fields":{}}]})
        )["ok"],
        false
    );
    assert_eq!(
        call(json!({"op":"list"}))["result"]
            .as_array()
            .unwrap()
            .len(),
        1
    );

    let original = call(json!({"op":"get","id":id}))["result"].clone();
    let saved = call(
        json!({"op":"save","id":id,"expected":{"name":original["name"],"fields":original["fields"]},"name":"Edited","fields":{"password":{"type":"secret","value":"second-password"}}}),
    );
    assert_eq!(saved["result"]["fields"]["custom"]["value"], "preserve-me");
    assert_eq!(
        saved["result"]["fields"]["private-key"]["value"],
        "custom-secret"
    );
    let with_notes = call(
        json!({"op":"save","id":id,"name":"Edited","fields":{"notes":{"type":"note","value":"remove this"}}}),
    );
    assert_eq!(with_notes["ok"], true);
    let cleared = call(
        json!({"op":"save","id":id,"name":"Edited","fields":{},"remove_fields":["notes","url","otp"]}),
    );
    assert_eq!(cleared["ok"], true);
    assert!(cleared["result"]["fields"].get("notes").is_none());
    assert_eq!(
        cleared["result"]["fields"]["custom"]["value"],
        "preserve-me"
    );
    assert_eq!(
        call(json!({"op":"save","id":id,"fields":{},"remove_fields":["custom"]}))["ok"],
        false
    );

    assert_eq!(call(json!({"op":"delete","id":id}))["ok"], true);
    assert_eq!(
        call(json!({"op":"list"}))["result"]
            .as_array()
            .unwrap()
            .len(),
        0
    );
    assert_eq!(call(json!({"op":"lock"}))["ok"], true);
}
#[tokio::test]
async fn remove_device_revokes_every_vault_and_forbids_self_removal() {
    let da = tempfile::tempdir().unwrap();
    let db = tempfile::tempdir().unwrap();
    let mut a = create(da.path(), "Desktop");
    let mut b = create(db.path(), "iPhone");
    for name in ["personal", "work"] {
        let (vault, _) = Vault::create(&a.secret, name).unwrap();
        let id = vault.id();
        a.add_vault(vault).unwrap();
        pair(&mut a, &mut b, id);
    }
    let me = a.device_id();
    let target = b.device_id();
    let mut engine = Engine::new();
    engine.start(a).await.unwrap();
    let removed = engine
        .request(json!({"data_dir":da.path(),"op":"remove_device","id":target.to_string()}))
        .await
        .unwrap();
    assert_eq!(removed["vault_ids"].as_array().unwrap().len(), 2);
    engine
        .with(|s| {
            assert!(s.vaults.values().all(|v| !v.is_member(&target)));
            Ok(())
        })
        .unwrap();
    assert!(
        engine
            .request(json!({"data_dir":da.path(),"op":"remove_device","id":me.to_string()}))
            .await
            .is_err()
    );
    engine.close().await;
}
#[tokio::test]
async fn vault_targeting_creation_validation_and_recovery() {
    let dir = tempfile::tempdir().unwrap();
    let mut engine = Engine::new();
    assert!(engine.request(json!({"data_dir":dir.path(),"op":"create","passphrase":"test passphrase","vault_name":"Invalid Name"})).await.is_err());
    assert!(!deadbolt_store::is_initialized(dir.path()));
    engine.request(json!({"data_dir":dir.path(),"op":"create","passphrase":"test passphrase","vault_name":""})).await.unwrap();
    let first = engine
        .request(json!({"data_dir":dir.path(),"op":"create_vault","name":"personal"}))
        .await
        .unwrap();
    assert_eq!(engine.vault(&json!({})).unwrap().to_string(), first["id"]);
    let second = engine
        .request(json!({"data_dir":dir.path(),"op":"create_vault","name":"work"}))
        .await
        .unwrap();
    assert!(engine.vault(&json!({})).is_err());
    assert!(engine.vault(&json!({"vault_id":"00".repeat(32)})).is_err());
    assert_eq!(
        engine
            .vault(&json!({"vault_id":second["id"]}))
            .unwrap()
            .to_string(),
        second["id"]
    );
    let saved=engine.request(json!({"data_dir":dir.path(),"op":"save","vault_id":second["id"],"name":"Only work","fields":{"password":{"type":"secret","value":"password"}}})).await.unwrap();
    assert_eq!(saved["vault_id"], second["id"]);
    let work = VaultId::from_bytes(unhex(second["id"].as_str().unwrap()).unwrap());
    engine
        .with(|s| {
            s.mutate(work, |w, key| {
                w.remove(key, key.device_id())?;
                Ok(())
            })
        })
        .unwrap();
    assert!(engine.vault(&json!({"vault_id":second["id"]})).is_err());
    engine.close().await;
}
#[tokio::test]
async fn stale_snapshots_and_deleted_items_cannot_be_overwritten() {
    let dir = tempfile::tempdir().unwrap();
    let mut engine = Engine::new();
    engine
        .request(json!({"data_dir":dir.path(),"op":"create","passphrase":"test passphrase"}))
        .await
        .unwrap();
    let saved=engine.request(json!({"data_dir":dir.path(),"op":"save","name":"Original","fields":{"password":{"type":"secret","value":"password"},"custom":{"type":"text","value":"hidden"}}})).await.unwrap();
    let expected = json!({"name":saved["name"],"fields":saved["fields"]});
    engine.request(json!({"data_dir":dir.path(),"op":"save","id":saved["id"],"name":"Remote edit","fields":{"password":{"type":"secret","value":"changed"}}})).await.unwrap();
    assert!(engine.request(json!({"data_dir":dir.path(),"op":"save","id":saved["id"],"name":"Stale edit","expected":expected,"fields":{"password":{"type":"secret","value":"stale"}}})).await.is_err());
    let fresh = engine
        .request(json!({"data_dir":dir.path(),"op":"get","id":saved["id"]}))
        .await
        .unwrap();
    engine.request(json!({"data_dir":dir.path(),"op":"save","id":saved["id"],"name":"Fresh edit","expected":{"name":fresh["name"],"fields":fresh["fields"]},"fields":{"password":{"type":"secret","value":"fresh"}}})).await.unwrap();
    engine
        .request(json!({"data_dir":dir.path(),"op":"delete","id":saved["id"]}))
        .await
        .unwrap();
    assert!(engine.request(json!({"data_dir":dir.path(),"op":"save","id":saved["id"],"name":"Undelete","fields":{}})).await.is_err());
    assert!(
        engine
            .request(json!({"data_dir":dir.path(),"op":"list"}))
            .await
            .unwrap()
            .as_array()
            .unwrap()
            .is_empty()
    );
    engine.close().await;
}
#[tokio::test]
async fn offline_sync_does_not_block_crud_and_lock_cancels_jobs() {
    use deadbolt_net::application::{Addr, Hint};
    let dir = tempfile::tempdir().unwrap();
    let mut session = create(dir.path(), "iPhone");
    let (vault, _) = Vault::create(&session.secret, "personal").unwrap();
    let id = vault.id();
    session.add_vault(vault).unwrap();
    let mut sinks = Vec::new();
    for _ in 0..8 {
        let key = deadbolt_core::DeviceSecret::generate();
        let peer = key.device_id();
        let inviter = session.secret.device_id();
        session
            .mutate(id, |v, secret| {
                v.add(secret, peer, key.join_consent(&id, &inviter))?;
                Ok(())
            })
            .unwrap();
        let sink = std::net::UdpSocket::bind("127.0.0.1:0").unwrap();
        session.peers.insert(
            peer.to_string(),
            Hint {
                name: None,
                addr: Some(Addr {
                    relay: None,
                    direct: vec![sink.local_addr().unwrap()],
                }),
                addr_seen: now(),
            },
        );
        sinks.push(sink);
    }
    session.ready = false;
    let key = *session.secret.to_bytes();
    let mut engine = Engine::new();
    engine.start(session).await.unwrap();
    let members = engine.session.clone();
    let node = Node::spawn(
        NodeConfig::local_only(key),
        Arc::new(move |p: &[u8; 32]| {
            members.lock().unwrap().as_ref().is_some_and(|s| {
                s.vaults
                    .values()
                    .any(|v| v.is_member(&DeviceId::from_bytes(*p)))
            })
        }),
        Handler(engine.session.clone()),
    )
    .await
    .unwrap();
    *engine.transport.node.lock().unwrap() = Some(node);
    let start = tokio::time::Instant::now();
    assert_eq!(
        engine
            .request(json!({"data_dir":dir.path(),"op":"sync"}))
            .await
            .unwrap()["state"],
        "running"
    );
    tokio::task::yield_now().await;
    engine.request(json!({"data_dir":dir.path(),"op":"save","name":"Offline edit","fields":{"password":{"type":"secret","value":"local"}}})).await.unwrap();
    assert!(start.elapsed() < Duration::from_secs(1));
    engine
        .request(json!({"data_dir":dir.path(),"op":"sync_cancel"}))
        .await
        .unwrap();
    assert!(engine.sync_task.is_none());
    engine
        .request(json!({"data_dir":dir.path(),"op":"sync"}))
        .await
        .unwrap();
    tokio::task::yield_now().await;
    engine.close().await;
    assert!(engine.sync_task.is_none());
    assert!(engine.transport.current().is_none());
    assert!(deadbolt_store::unlock(dir.path(), b"a strong local test passphrase").is_ok());
}

#[tokio::test]
async fn standalone_sync_never_starts_network() {
    let dir = tempfile::tempdir().unwrap();
    let mut engine = Engine::new();
    engine
        .request(json!({"data_dir":dir.path(),"op":"create","passphrase":"standalone passphrase"}))
        .await
        .unwrap();
    let result = engine
        .request(json!({"data_dir":dir.path(),"op":"sync"}))
        .await
        .unwrap();
    assert_eq!(result, json!({"state":"complete","results":[]}));
    assert!(engine.transport.current().is_none());
    assert!(engine.sync_task.is_none());
    engine.close().await;
}
