<p align="center">
  <a href="https://github.com/zackbart/apps/tree/main/jellytv">
    <img src="https://shieldcn.dev/header/graph.svg?title=JellyTV&subtitle=native+tvOS+Jellyfin+client+built+for+Live+TV&logo=jellyfin&mode=light&align=center&font=geist-mono&border=false" alt="JellyTV">
  </a>
</p>

<p align="center">
  <a href="https://github.com/zackbart/apps/stargazers">
    <img src="https://shieldcn.dev/github/stars/zackbart/apps.svg" alt="Stars">
  </a>
</p>

A native SwiftUI **tvOS 18** Jellyfin client for Apple TV 4K — a modern replacement
for SwiftFin tvOS, built **Live-TV first**: live guide, on-now, and instant channel
zapping, with playback that leans entirely on the system player.

> **Unofficial client.** Jellyfin and its branding belong to the Jellyfin project;
> this is an independent tvOS front-end for it.

## Features

- **Live TV** — On Now rail, full EPG guide grid, recordings, and debounced channel zapping
- **System-native playback** — `AVPlayerViewController` only; no custom chrome, no VLCKit/MPVKit
- **Home** — hero section with poster shelves
- **Focus-engine native** — trusts the tvOS focus engine end to end (card/borderless styles, focus sections, stable IDs)
- **Fast images** — Nuke `LazyImage` throughout, with per-channel dominant-color theming

## Architecture

Thin app target + Swift Package Manager modules:

| Package | Responsibility |
|---|---|
| `JellyfinAPI` | hand-rolled `actor JellyfinClient` (URLSession + async/await + Codable DTOs); `JellyfinClientAPI` is the seam for test fakes |
| `LiveTV` | On Now, guide grid, recordings, player state machine, `AVPlayerViewController` host |
| `Library` | Home (hero + shelves) |
| `DesignSystem` | theme, typography, `PosterCard`, `Shelf`, `ChannelLogoView`, `JellyfinImage` |
| `Settings` | server connect, sign in, `SessionStore` |
| `Persistence` | Keychain wrapper |

The app target (`JellyTV/`) is intentionally thin: `JellyTVApp`, `RootView`, assets.
`softplan.md` is the founding design doc — read it for the player strategy, DeviceProfile,
and tvOS gotchas.

## Build & test

```bash
# Unit tests (Swift Testing, per package)
swift test --package-path Packages/LiveTV
swift test --package-path Packages/JellyfinAPI

# Full app build
xcodebuild -project JellyTV/JellyTV.xcodeproj -scheme JellyTV \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)'
```

Stack: SwiftUI + `@Observable` + Swift Concurrency (no Combine, no coordinators, no TCA).
See `CLAUDE.md` for the architectural ground rules.
