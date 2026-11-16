# Set up your laptop first

The Mac creates the first vault. The iPhone joins that vault afterward. There is no central server to configure.

## Install on the Mac

Upstream currently ships development builds, with no stable release. Its documented Homebrew formula and cask are for future stable releases. Use the [official installer](https://github.com/anomalyco/deadbolt#install) for now:

```sh
curl -fsSL https://deadbolt.pw/install | DEADBOLT_CHANNEL=dev sh
export PATH="$HOME/.local/bin:$PATH"
deadbolt init personal
deadbolt app
```

`init` asks for the Mac's master password interactively and creates the `personal` vault. Keep that password somewhere safe. Alternatively, install the [official Mac app](https://anoma.ly/release/deadbolt/desktop/dev/macos-arm64-dmg), open it, and choose **Create a vault**; you do not need to initialize twice.

The custom iOS build uses upstream revision `11a56948b453823c9c9c3de1161254df2c00b105`. Our interoperability tests used that engine, and the upstream `dev` head matched it when checked on November 16, 2026. The installer fetches the latest upstream development build, so compatibility with later protocol changes is not guaranteed. If pairing fails, record the laptop version with `deadbolt --version` and check it against the iOS engine revision before changing or resetting any vault.

## Add the iPhone

1. Keep the Mac's Deadbolt vault open and unlocked.
2. Install Deadbolt iOS from TestFlight. On its welcome screen choose **Join an existing vault**. If already set up, unlock it and choose **Devices → Join another vault**.
3. Choose the iPhone's local master password if prompted; it may differ from the Mac's. Tap **Get pairing code**.
4. On the Mac, approve the code shown on the iPhone:

   ```sh
   deadbolt --vault personal approve <five-word-code>
   ```

   Replace the placeholder with the actual code; do not type the angle brackets. Codes expire after five minutes and work once. If the Mac has locked, run `deadbolt unlock` first.

5. Keep both devices open until pairing finishes. Create one disposable login on the Mac, use **Sync now** on the iPhone, and confirm it arrives. Edit it on the iPhone and verify the change on the Mac before moving important credentials.

Do not create a separate iPhone vault when you intend to join the laptop's vault. If you already did, it can coexist: choose the joined laptop vault explicitly when adding or importing credentials. Two vaults with the same display name are still different vaults; compare the short IDs shown by the app when needed.

## Import from Apple Passwords

After pairing, on iOS 26 or later use **Passwords → More (•••) → Export Data to Another App → Deadbolt**. Unlock promptly, select the vault joined from your laptop, review the items and exclusions, then import. Keep both Deadbolt devices unlocked and run sync so the Mac receives the imported items. Credentials remain in Apple Passwords.

## Browser AutoFill on the Mac

The [upstream regular browser extension](https://github.com/anomalyco/deadbolt#the-browser-extension) uses the Mac's existing vault and supports Chromium browsers including Helium:

```sh
deadbolt browser install --extension-dir "$HOME/deadbolt-extension"
deadbolt update
```

Choose a new, empty extension folder. Open `chrome://extensions`, enable **Developer mode**, choose **Load unpacked**, and select that folder. Reload the extension after updating. `deadbolt update` also updates the desktop development build. Upstream macOS Safari AutoFill is not yet in releases.

No Cloudflare endpoint, Tailscale, or VPN is needed. Devices connect through Iroh and may use encrypted relays when direct connections are unavailable. The Mac is a peer, not a mandatory cloud server; each paired device keeps its own encrypted local copy.
