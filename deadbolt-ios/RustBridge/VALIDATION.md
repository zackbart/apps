# Rust polish validation — 2026-11-16

`cargo test --locked --manifest-path RustBridge/Cargo.toml`: **11 passed, 0 failed**
in 9.50 seconds. Durable concise evidence: `docs/evidence/rust-tests.txt`.
Full log: `/tmp/deadbolt-polish-verified-tests.log`.

Added regressions cover invalid initial names leaving no initialized store;
empty-device recovery with create_vault; explicit multi-vault targeting and
removed-membership rejection; transactional stale snapshot and deleted-item
edit rejection; actual silent UDP peers during background sync while local
CRUD completes in under one second; sync cancellation, lock/store release;
standalone sync completing without spawning a node; atomic duplicate-safe imports
including same-batch repeats and deleted-item reimports; and preservation of a
non-passkey custom private-key field through expected-snapshot saves.
The final custom-field expected-snapshot regression also passed a focused
one-test run (1.41 seconds). The original real
SPAKE2/QUIC pairing, offline convergence and WebAuthn signature tests still pass.

Sync is now a bounded background job with pollable status. Startup membership
synchronization remains a barrier before sharing data. Current shared membership
determines targets; unrelated and revoked address-book entries are excluded.
No-peers sync does not start the network. Network jobs are aborted before the
store is released on lock.

# Rust validation — 2026-11-15

Upstream: anomalyco/deadbolt at
`11a56948b453823c9c9c3de1161254df2c00b105`.
Toolchain: Rust stable 1.100.0, Apple Silicon macOS.

`cargo test --locked --manifest-path RustBridge/Cargo.toml` passed:
**7 passed, 0 failed**, 8.97 seconds.

- `encrypted_crud_reopen_and_biometric_slot`: real redb encrypted persistence,
  create/edit/delete, no plaintext password in the file, wrong-passphrase
  rejection, biometric-key unlock and replay.
- `two_peer_pairing_offline_conflict_converges_and_survives_reopen`: upstream
  offer/consent/welcome replay, two offline edits to the same password, convergence
  with retained history and matching state after reopening both stores.
- `real_iroh_membership_gated_two_peer_sync`: two actual Iroh nodes, five-word
  code, SPAKE2 confirmation, signed membership admission, real QUIC sync of a
  newly created password, and rejected dial after signed device revocation.
  This uses upstream local-only transport/rendezvous configuration; no crypto or
  protocol bypasses are enabled.
- `native_passkey_registration_assertion_persistence_and_rp_binding`: upstream
  ES256 registration, encrypted signed persistence, lock/unlock, assertion
  verified against its SPKI public key, rejected tampered data, RP mismatch and
  missing user verification, exclusion-list duplicate prevention, and private
  key omission from generic JSON.
- `remove_device_revokes_every_vault_and_forbids_self_removal`: real pairing
  into two vaults, device-wide signed removal from both, own-device rejection.
- `bridge_import_is_atomic_and_save_preserves_custom_fields`: invalid batch
  imports leave no items, valid import, partial field update preserves a desktop
  custom field, explicit optional-field clearing, rejected custom-field removal,
  then tombstone deletion.
- `malformed_json_and_locked_reads_fail_without_panicking`: JSON boundary and
  locked state errors.

Evidence log: `docs/evidence/rust-tests.txt` (durable concise copy) and
`/tmp/deadbolt-rust-final-validation2.log` (full compiler output).

`scripts/build-rust.sh all` produces optimized static archives for
`aarch64-apple-ios` and `aarch64-apple-ios-sim`; no x86 simulator was built.
The real-device archive compiles against the iPhoneOS SDK and the simulator
archive against the iPhoneSimulator SDK. Swift/Xcode integration and UI testing
are recorded separately by the app implementation.

Public n0 relay traversal and an installed credential-provider extension on a
physical iPhone are outside these host integration tests.

Final optimized archives rebuilt at 22:27 local time after pair_cancel, optional
field clearing and device-wide revocation fixes. Both archives verified arm64
with xcrun lipo. Build log: `/tmp/deadbolt-rust-final-archives2.log`.
