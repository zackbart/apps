# Deadbolt iOS

Native SwiftUI client for Deadbolt, built on the upstream Rust vault, membership, pairing and synchronization engine. Personal-use app, distributed privately through Cursor Kittens TestFlight.

## Build

Use Xcode 27, XcodeGen, Homebrew Rustup, and runbp 0.0.44 or later. The project targets iOS 18 and later. Apple silicon simulators and arm64 iPhones are supported by the build script.

```sh
brew install rustup xcodegen
export PATH="/opt/homebrew/opt/rustup/bin:$PATH"
rustup toolchain install stable --profile minimal --component rustfmt,clippy
rustup target add aarch64-apple-ios aarch64-apple-ios-sim
cd /Users/zackbart/Dev/apps/apps/deadbolt-ios
./scripts/build-rust.sh all
xcodegen generate
./scripts/run.sh build --check
```

The bootstrap script downloads the pinned upstream revision. Rust dependencies are locked. The generated Xcode project, downloaded upstream source and compilation outputs are ignored; authored source and the required networking portability patches remain in this directory.

`./scripts/run.sh` disables runbp source mirroring because the generated Rust archives are intentionally ignored. Use one simulator session at a time and reuse it while iterating. Do not create extra simulators.

## Signing

The configured team is **Cursor Kittens LLC**, `F2J8ZU2NQJ`. The app identifier is `com.cursorkittens.deadbolt`; its extension is `com.cursorkittens.deadbolt.autofill`. Both targets share `group.dev.zackbart.deadbolt` and a team-scoped Keychain access group. Provisioning must include the App Group and AutoFill Credential Provider entitlement. The user authorized private TestFlight distribution. App Store Connect app ID: `6835505284`.

## Use

Create a vault with a master password, or join an existing vault through the device pairing flow. Keep the master password: device authentication is a convenience and does not replace recovery access. A trusted device must be reachable for synchronization; the local vault works offline.

Enable device authentication in the app before using the extension, then enable Deadbolt in the system AutoFill settings. iOS requires a device passcode for the protected shared unlock key. Native password and passkey requests authenticate through the Keychain; the extension does not keep a plaintext password cache.

Import password-manager CSV files using the Files picker, choose a destination vault, and review the preview before confirming. Apple Passwords, Bitwarden and 1Password column names are recognized. Each import commits together; repeating the same file skips exact matches already in that vault. Imported source files remain wherever you selected them; remove plaintext exports yourself when no longer needed.

On iOS 26 or later, Apple Passwords → More (•••) → Export Data to Another App can transfer credentials directly to Deadbolt without a plaintext export file. Unlock Deadbolt, choose a destination vault, review the items and exclusions, then import. Passwords, supported verification codes, and ES256 passkeys retain their credential material. Unsupported passkey extensions and other credential types are listed before import. Existing items remain in the source app. Leaving Deadbolt clears the preview; restart the transfer if that happens. CSV import remains available on older iOS versions.

Release updates keep marketing version **1.0** and increment only `CURRENT_PROJECT_VERSION`.

When you hold more than one vault, new logins, imports, device approvals, and passkey registrations require a specific destination. Vault filters and labels distinguish private and shared records. If another device changes a login while you are editing it, Deadbolt preserves your draft and offers to load the latest version instead of silently overwriting the remote change.

Sync runs independently of local editing, with bounded network waits and a cancel action. Changes made during an active sync schedule a follow-up. Leaving the app locks the local vault and stops its network work; reopening and unlocking resumes synchronization.

See [the acceptance plan](docs/ACCEPTANCE.md) for the scope and required verification. [Verification results and remaining device checks](docs/VALIDATION.md) include real Safari AutoFill/passkey ceremonies and bidirectional iOS-to-Mac sync. Compilation is not proof of hardware integration or a security audit.

Version **1.0 (2)** is available in the configured internal TestFlight group, including native Credential Exchange import. See [release verification and the upload workflow](docs/VALIDATION.md#private-testflight-release-november-16) for signing, account selection, and remaining hardware checks.

## Connecting your other devices

For laptop-first setup, follow [the laptop setup guide](docs/LAPTOP-SETUP.md): create the vault on your Mac, then approve the iPhone's join request from that Mac.

No Cloudflare tunnel, HTTP endpoint, port forwarding, Tailscale or VPN is required. On the new device, request a temporary pairing code. Approve it from an already trusted Deadbolt device. Iroh uses public discovery, attempts a direct encrypted peer connection, and can fall back to encrypted relaying. Relays do not hold a readable vault. Keep a trusted desktop running and the iPhone app open and unlocked when you want to synchronize; iOS does not keep a permanent background peer running.
