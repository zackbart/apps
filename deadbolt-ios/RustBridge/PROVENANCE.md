# Sources

The Deadbolt engine is https://github.com/anomalyco/deadbolt at commit
`11a56948b453823c9c9c3de1161254df2c00b105`. Run `scripts/bootstrap-deadbolt.sh`
to restore the exact source checkout. Its original license, source headers,
and repository instructions remain in the checkout. The upstream manifest
marks the project UNLICENSED; this local integration does not grant distribution
rights.

`patches/netdev` contains crates.io netdev 0.46.3 with its original LICENSE.
`patches/netwatch` contains crates.io netwatch 0.19.3 with its original licenses.
These are Cargo patches because their Darwin routing code currently references
libc bindings available only on macOS. The netdev patch uses its existing
unknown-flags representation on iOS. The netwatch patch enumerates real
interfaces through netdev, obtains the real default interface, and polls real interface state every five seconds while the node is active. Crypto, pairing, QUIC, relay discovery and sync
protocols are unchanged.

Passkeys call upstream `deadbolt_core::passkeys::{register_hash,sign_hash}`.
Private ES256 keys persist in encrypted signed vault items and never appear in
generic item JSON or passkey metadata.

## Exact portability changes

Cargo.lock pins the complete dependency graph. Both patched crates retain their
original packaged source and Cargo manifests, including license declarations.

netdev 0.46.3 (MIT, LICENSE):

- `src/os/darwin/ipv6_addr_flags.rs`: retain macOS ioctl implementation; on iOS,
  report optional IPv6 address flags as unknown because libc exposes in6_ifreq
  only on macOS. Real interface and address enumeration remains unchanged.

netwatch 0.19.3 (MIT OR Apache-2.0, LICENSE-MIT and LICENSE-APACHE):

- `build.rs`: exclude iOS from the BSD routing-socket alias because libc omits
  the route message constants and structs it assumes exist.
- `src/interfaces.rs`: select the iOS platform module.
- `src/interfaces/ios.rs`: reuse real netdev interface enumeration and default
  interface detection.
- `src/interfaces/netdev_impl.rs`: expose the existing home-router lookup on iOS.
- `src/netmon.rs` and `src/netmon/actor.rs`: select the iOS route monitor.
- `src/netmon/ios.rs`: compare real interface state every five seconds while the
  node is active, notifying Iroh only when state changes; dropping the monitor
  cancels polling. Locking the app closes the node.

The netwatch package omits license text files, so the repository's MIT and
Apache-2.0 texts are included alongside its original license declaration.

Final archives are self-contained. Build intermediates were removed after
validation, reducing the Rust build footprint from 7.6 GB of intermediates to
249 MB of retained device/simulator archives. Running scripts/build-rust.sh all
with the unchanged sources succeeds without recreating target; changing source
rebuilds from the pinned checkout and Cargo.lock.
