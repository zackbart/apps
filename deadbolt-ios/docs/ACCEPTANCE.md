# Deadbolt iOS acceptance plan

Build a native personal-use iOS app on the pinned Deadbolt engine, with independently usable encrypted local vaults and system password AutoFill. Publish reviewed, secret-scanned source to `zackbart/apps`. The user authorized private TestFlight distribution through Cursor Kittens; keep the marketing version at 1.0 and increment build numbers only.

Upstream baseline: anomalyco/deadbolt dev, commit `11a56948b453823c9c9c3de1161254df2c00b105`. Preserve upstream licensing and attribution. Do not claim an independent security audit.

## Engine and interoperability

- Compile the actual Rust core/store/net crates for Apple silicon simulators and iPhone.
- Create, unlock, lock, reopen, add, edit, search, and delete credentials with durable encrypted persistence.
- Reject incorrect passphrases and malformed requests without panics or data loss.
- Pair disposable devices using upstream temporary codes and authenticated membership.
- Synchronize changes in both directions, reconnect after offline edits, and exercise concurrent edits and revocation.
- Report real sync outcomes; an unreachable peer must not appear synchronized.
- Preserve the master passphrase recovery route when biometric enrollment changes.

## Native application

- Clear creation and joining flows, usable empty states, inline validation and recoverable errors.
- Searchable vault with credential details, password reveal/copy, editing, deletion confirmation, and password generation.
- Device membership, pairing expiration/cancellation, manual sync, foreground sync, and truthful offline status.
- Face ID/device authentication, automatic lock, protected app switcher image, bounded clipboard lifetime.
- Dynamic Type, VoiceOver labels, keyboard-safe forms, readable contrast, and comfortable touch targets.
- Inspect simulator screenshots and exercise controls; a successful build alone is insufficient.

## System AutoFill

- Embed a real Credential Provider extension with correctly scoped App Group and Keychain entitlements.
- Authenticate extension access and avoid a plaintext credential cache or extension Argon2 allocation.
- Register credential identities, match domains safely, select a credential, and fulfill the system request.
- Handle cancellation, locked vault, unavailable Keychain, missing enrollment, and stale identities safely.
- Serialize cross-process vault access and release the app's store on backgrounding.
- Verify the system AutoFill flow where the simulator supports it; identify remaining physical-device checks explicitly.

## Passkeys, authenticator codes and import

- Native passkey creation and assertion through the Credential Provider extension, with authenticated consent, RP binding, compatible encrypted storage and valid WebAuthn signatures.
- TOTP support tested against standard vectors, with URI validation and correct expiry display.
- Password import from Files with quoted CSV parsing, preview, explicit confirmation and recoverable validation errors.
- Native iOS 26 Credential Exchange import for passwords, TOTP and ES256 passkeys, with destination review, unsupported-data warnings, duplicate handling and atomic encrypted persistence.
- Local signing team confirmed from installed profiles: Cursor Kittens LLC (`F2J8ZU2NQJ`). User authorized local signing and private TestFlight distribution.

## Verification and delivery

Use disposable data only. Keep raw secrets out of logs, screenshots, and committed fixtures. Record actual commands, outcomes and evidence paths, including failures and unverified device behavior. Run focused engine and Swift security-boundary tests, simulator user flows, and an independent code/UI review. Repair findings before handoff. Provide reproducible build, signing, installation and AutoFill-enablement instructions. Do not describe simulator evidence as physical-device validation.
