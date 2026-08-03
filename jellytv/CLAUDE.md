# JellyTV

Native SwiftUI **tvOS 18** Jellyfin client (Apple TV 4K only). Goal: a modern replacement for SwiftFin tvOS. Live TV (guide, on-now, channel zapping) is the flagship feature. `softplan.md` is the founding design doc — read it for the player strategy, DeviceProfile, and tvOS gotchas.

## Architecture

Thin app target + SPM packages:

- `JellyTV/` — app target (JellyTVApp, RootView, Info.plist, assets)
- `Packages/JellyfinAPI` — hand-rolled `actor JellyfinClient` (URLSession + async/await + Codable DTOs); `JellyfinClientAPI` protocol is the seam for test fakes
- `Packages/LiveTV` — On Now, Guide grid, Recordings, player state machine (`PlayerViewModel`), `AVPlayerViewController` host
- `Packages/Library` — Home (hero + shelves)
- `Packages/DesignSystem` — `LiveTVTheme`, `LiveTVTypography`, `PosterCard`, `Shelf`, `ChannelLogoView`, `JellyfinImage` (Nuke), `ChannelDominantColor`
- `Packages/Settings` — server connect, sign in, `SessionStore`
- `Packages/Persistence` — Keychain wrapper

## Hard rules (from softplan.md — do not relitigate)

- **Playback:** `AVPlayerViewController` only. No custom chrome, no AVPlayerLayer, no VLCKit/MPVKit.
- **UI:** SwiftUI + `@Observable` + Swift Concurrency. No Combine `ObservableObject`, no coordinators, no TCA.
- **Focus:** trust the focus engine — `.buttonStyle(.card)`/`.borderless` for focus effects; never hand-roll `scaleEffect`/stroke focus indicators on top of them. `.focusSection()` on shelf rows; stable IDs so focus survives reloads.
- **Images:** Nuke `LazyImage` (never `AsyncImage`).
- **Models:** created in the owning root view via `State(initialValue:)`, passed down as `@Bindable`; client injected as `let client: JellyfinClientAPI`.

## Build & test

```bash
# Unit tests (Swift Testing, per package)
swift test --package-path Packages/LiveTV
swift test --package-path Packages/JellyfinAPI

# Full app build
xcodebuild -project JellyTV/JellyTV.xcodeproj -scheme JellyTV \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)'
```

Test doubles live next to the tests: `FakeJellyfinClient` (Result-based stubs that capture call args), `MockPlayerHost`/`MockNetworkMonitor` (AsyncStream continuations).

## Conventions

- DTOs decode defensively; unknown server fields are dropped silently.
- Live TV state machine: `.idle → .resolving → .splash → .buffering → .playing`; channel zap is debounced 400ms (intentional UX — keep it).
- Focus propagation pattern: leaf `@FocusState` → `.focusedValue(\.key, isFocused ? value : nil)` → parent `@FocusedValue` (see `FocusedOnNowChannelKey`, `FocusedGuideProgramKey`).
- `AGENTS.md` is a symlink to this file — edit `CLAUDE.md` only.
