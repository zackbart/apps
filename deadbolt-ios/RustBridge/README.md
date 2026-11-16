# Deadbolt iOS bridge

Build with `scripts/build-rust.sh all` using Homebrew rustup, stable Rust and
`aarch64-apple-ios` / `aarch64-apple-ios-sim` targets. Archives land under
`RustBridge/lib/{iphoneos,iphonesimulator}/libdeadbolt_ios.a`. The simulator
archive is arm64. Link Security, SystemConfiguration, Network, z and iconv. Import `include/DeadboltBridge.h` in the Swift bridging header.

`deadbolt_request` accepts a NUL-terminated UTF-8 JSON object and returns owned
UTF-8 JSON. Always pass the response to `deadbolt_free`, which wipes its buffer.
Never pass temporary or invalid C pointers. All requests contain `data_dir` (the
App Group store directory) and `op`. Responses are `{ok:true,result:...}` or
`{ok:false,error:"..."}`. Errors never include request bodies or secret values.
Call from a background queue.

`deadbolt_cancel(data_dir)` immediately signals the in-flight request; call it
before queueing `lock` on backgrounding. Cancellation closes the session/node.
Independent directories have independent engine locks. An unlocked store holds
redb's process-exclusive lock; the app must lock when backgrounding before the
AutoFill extension independently unlocks and locks it.

- `status`: initialized, locked, device_id, device_name, vaults and pairing.
- `create`: passphrase, device_name, vault_name. Empty vault_name creates only a
  device, ready to join. Vault names are validated before creating the store.
  create_vault {name} creates a signed vault on an unlocked device, including
  recovery after an abandoned join. Names follow upstream lowercase ASCII rules.
- `unlock`: passphrase. `lock` destroys the unlocked store and stops networking.
- `biometric_enable`: returns `{key:hex}` for the authenticated Keychain slot.
  `unlock_key` takes key; `biometric_disable` removes the slot. The random key
  wraps the upstream biometric store slot; it is not a cached master password.
- `list` / `export`: live items with id, vault_id, type, name, fields, favorite,
  tags. Each field contains type and value. Passkey private keys are omitted.
- `import`: items (the generic item shape) and optional vault_id, atomically
  creates signed vault entries and returns {ids,imported,skipped}. Optional
  deduplicate:true skips exact live kind/name/typed-field matches and repeats
  within the request using an in-memory ordered identity set. Deleted entries
  do not suppress reimport. A retry after an uncertain reply safely skips exact
  committed matches. Passkeys transfer via pairing.
- `get`: id and optional vault_id, returns one item. Implicit vault selection
  works only with exactly one held vault; otherwise supply vault_id. Explicit
  targeting verifies that the vault is held and this device remains a member.
- `save`: optional existing id, optional vault_id, type, name, fields and optional
  favorite. New items omit id. Updates preserve unspecified fields and tags.
  Optional remove_fields explicitly removes optional known schema fields; unknown
  desktop/custom fields remain intact. Omit empty optional values. Existing items
  reject tombstones. Optional expected:{name,fields} compares the original name
  and complete typed fields transactionally before writing; stale snapshots fail
  instead of silently overwriting synchronized edits.
- `delete`: id and optional vault_id. Writes the upstream tombstone.
- `devices`: id, name, this, connected for current members.
- `remove_device`: id revokes the device from all held vaults; optional vault_id
  scopes the signed removal. Own-device removal is forbidden.
- `join_start`: returns waiting state and five-word code. Poll `pairing_status`
  for waiting/complete/failed. The code expires after five minutes.
  pair_cancel aborts the outstanding listener/code and returns idle, keeping
  the existing unlocked vault available.
- `approve`: code and optional vault_id, performs actual SPAKE2 pairing and
  signed membership admission.

Unlock and CRUD are offline and never start Iroh. Pairing/sync start the upstream
Iroh transport lazily with its real n0 discovery, rendezvous, and relays. The
startup membership phase precedes application data.

`sync` starts a background job and immediately returns {state:"running"}. Poll
`sync_status` for idle/running/complete/failed, results (per-peer status), and an
optional error. `sync_cancel` aborts the job without locking the vault. No eligible
peers returns complete with empty results and never starts networking. Targets
come from current shared membership, excluding revoked and unrelated hints.
Network startup is bounded to ten seconds; membership rounds use four concurrent
peers and a twelve-second budget, preserving completed contacts across retries.
Data sync uses four concurrent peers and a twenty-second global budget. The
whole job is bounded to forty-five seconds. Local CRUD never waits for this job;
lock cancels it and releases the encrypted store before bounded node shutdown.

Native passkeys use standard padded Base64 for every binary JSON value:

- `passkey_list`: metadata entries id, vault_id, rp_id, username, credential_id,
  user_handle, without private keys.
- `passkey_register`: rp_id, username, user_handle, client_data_hash, verified,
  optional algorithms (must include -7), exclude (credential IDs), vault_id.
  Returns id, vault_id, credential_id, attestation_object, authenticator_data,
  public_key (SPKI). The vault commit completes before returning attestation.
- `passkey_assert`: rp_id, client_data_hash, verified and optional credential_id.
  If multiple credentials match, an explicit choice is required. Returns
  credential_id, user_handle, authenticator_data and signature (DER ES256).

The Swift adapter must establish actual user presence/verification with
AuthenticationServices/LocalAuthentication before passing verified:true.
Upstream validates the RP, user handle, hash length and excluded credentials;
Apple provides origin authorization. These use the original signed passkey item
schema and crypto, interoperable with other Deadbolt devices.

Run `cargo test --manifest-path RustBridge/Cargo.toml` for encrypted persistence,
wrong passphrases, biometric unlock, offline merge convergence, real local Iroh
pairing/sync, and native WebAuthn signature verification with RP/UV failures.

## Disposable host interoperability peer

`RustBridge/bin/deadbolt-test-peer /absolute/path/to/disposable-vault` is a
local development utility, excluded from version control and distribution. It
runs the same bridge and upstream Iroh engine as the iOS app. Keep its stdin open
for the pairing/sync session; EOF closes the vault and exits.

Send one JSON object per input line; data_dir defaults to the command argument.
Each line receives one JSON response. For example, create a disposable host vault
with create, enter the simulator's five-word code through approve, then exchange
save, sync and list requests. No mock transports or fixtures replace the engine.
Use a disposable passphrase, since an interactive terminal may echo stdin.

Rebuild the utility when needed:

```
cargo build --locked --release --manifest-path RustBridge/Cargo.toml --example console
mkdir -p RustBridge/bin
cp RustBridge/target/release/examples/console RustBridge/bin/deadbolt-test-peer
```

The console uses production NodeConfig::new with n0 discovery, signed rendezvous
publication and relay support. It does not use the unit tests' local-only node
configuration. Pairing a simulator and peer on the same host may select a direct
local route; success there does not by itself prove cross-network relay traversal.
