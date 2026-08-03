# JellyTV — Soft Plan

**Goal:** Build a modern, native SwiftUI **tvOS** Jellyfin client that doesn't suck. A replacement for SwiftFin tvOS, which is stuck on a year-old App Store build (v1.0.1) and has well-known live bugs.

**Constraints (decided):**
- **Hardware:** Apple TV 4K only (A10X / A12 / A15). Drop Apple TV HD (A8).
- **Deployment target:** tvOS 18.
- **Networking:** LAN-only for v1. Plan for remote/HTTPS in a later phase.
- **Accounts:** Single user, single server. Multi-user/multi-server deferred.

**Date:** 2026-04-06

---

## 1. Why this project exists

### The tvOS Jellyfin landscape (April 2026)

- **SwiftFin tvOS App Store build is stuck on v1.0.1** (build 70, over a year old). Every 2026 crash report lists 1.0.1. The iOS target shipped 1.4 in Dec 2025; the tvOS binary has not shipped a real update in over a year.
- The next SwiftFin tvOS release is gated on two unfinished pieces of work:
  - [#1774 Device Profile rewrite](https://github.com/jellyfin/Swiftfin/issues/1774) — iOS got a device-profile fix in PRs #519/#1169 that was never backported to tvOS. Until that lands, tvOS asks the server for wrong codecs and transcoding breaks.
  - [#1853](https://github.com/jellyfin/Swiftfin/issues/1853) + [PR #1902](https://github.com/jellyfin/Swiftfin/pull/1902) — maintainers are rebuilding the tvOS player from scratch on `AVPlayerLayer` with custom transport chrome. Open since late 2025, last updated 2026-03-27, unmerged.
- **No other native tvOS Jellyfin client exists.** Streamyfin's tvOS support is an open issue with zero implementation ([streamyfin#137](https://github.com/streamyfin/streamyfin/issues/137)). Macfin is abandoned. Jellyfin Media Player is Electron+mpv (desktop only).
- **Infuse** (closed source) is the UX benchmark to match.

### Live bugs on SwiftFin tvOS 1.0.1

These become our "must not regress" acceptance criteria:

| Issue | Symptom |
|---|---|
| [#1755](https://github.com/jellyfin/Swiftfin/issues/1755) | All audio tracks playing simultaneously |
| [#1862](https://github.com/jellyfin/Swiftfin/issues/1862) | Crashes on "Connect" |
| [#1906](https://github.com/jellyfin/Swiftfin/issues/1906) | Timeout + crash after scrolling Movies on Jellyfin 10.11 |
| [#780](https://github.com/jellyfin/Swiftfin/issues/780) | External subtitles don't play |
| [#1962](https://github.com/jellyfin/Swiftfin/issues/1962), [#1515](https://github.com/jellyfin/Swiftfin/issues/1515) | Touchpad FF/RW broken |
| [#1948](https://github.com/jellyfin/Swiftfin/issues/1948) | Live TV LAN-only (out of v1 scope, tracked for later) |
| [#1872](https://github.com/jellyfin/Swiftfin/issues/1872) | No audio for ~1s on resume |

### Architectural lessons from SwiftFin (what NOT to copy)

- **Coordinator-based navigation** — predates `NavigationStack`/`NavigationSplitView`. Legacy.
- **Custom `@Stateful` macro + Combine + Factory DI** — too much bespoke machinery. Use `@Observable` + Swift Concurrency.
- **CoreStore (Core Data wrapper)** — use SwiftData instead.
- **Dual AVPlayer+VLCKit abstraction leaks** through DeviceProfile and causes real bugs ([#1852](https://github.com/jellyfin/Swiftfin/issues/1852), [#1943](https://github.com/jellyfin/Swiftfin/issues/1943)).
- **Rebuilding the tvOS player on `AVPlayerLayer` with custom chrome** (PR #1902 direction) — throws away everything `AVPlayerViewController` gives you for free on tvOS.
- **UIKit-isms** sprinkled through `Shared/` (`UIScreen.main.*`, `UIFocusGuide` bridges).

### Architectural lessons from SwiftFin (what IS worth reading as reference)

Do *not* fork — read as design reference:

- `Shared/Objects/PlaybackDeviceProfile.swift` + `PlaybackCapabilities.swift` + `CustomDeviceProfileAction.swift` — DeviceProfile with user overrides
- `Shared/Services/Keychain.swift` — token storage
- `Shared/SwiftfinStore/V2Schema/` — multi-server/user store shape
- `Shared/ServerDiscovery/` — UDP broadcast discovery
- `Swiftfin tvOS/Views/HomeView/`, `PagingLibraryView/`, `ItemView/`, `SelectUserView/`, `UserSignInView.swift` — current tvOS UI patterns (reference only; many will change)

---

## 2. Technical decisions (locked)

| Layer | Choice | Why |
|---|---|---|
| **Deployment target** | tvOS 18, Apple TV 4K only | A8 lacks HEVC HW decode; tvOS 18 layout APIs (`TabView(.sidebarAdaptable)`, `containerRelativeFrame`, `onScrollVisibilityChange`, `scrollTargetBehavior`) are transformational |
| **UI** | SwiftUI, `@Observable` (Observation framework) | 2026 idiomatic; skip `ObservableObject`, skip TCA, skip coordinators |
| **Navigation** | `NavigationStack` + `TabView(.sidebarAdaptable)` | Matches Apple TV app pattern |
| **Project layout** | Thin app target + SPM packages | Faster incremental builds, enforced module boundaries |
| **Persistence** | SwiftData | Skip CoreStore |
| **Networking** | Hand-rolled `JellyfinClient` actor (~500 LOC, ~20 endpoints), `URLSession` + async/await + Codable | Avoid pinning to pre-1.0 churning `jellyfin-sdk-swift`; clean DTOs for SwiftData |
| **Auth header** | `Authorization: MediaBrowser Client="JellyTV", Device="<Apple TV name>", DeviceId="<persistent UUID>", Version="<app version>", Token="<access token>"` | Old `X-Emby-Authorization` / `?api_key=` deprecated, removed in Jellyfin 12.0 |
| **Secrets** | `KeychainAccess` SPM package — server URL + access token + persistent DeviceId UUID | Keyed by server URL so multi-server works later |
| **Image cache** | Nuke (`LazyImage`) with downsampling to poster size | `AsyncImage` has no caching — grid will OOM without this |
| **Player** | `AVPlayerViewController` only, with `externalMetadata`, `navigationMarkerGroups`, `contentProposalViewController` | See §3 |
| **VLCKit / MPVKit** | **None in v1.** Reconsider in v1.1 only if users have Profile 7 DV / PGS / TrueHD | Avoid the dual-player abstraction leak that bit SwiftFin |

### Proposed SPM structure

```
JellyTV/                        (app target, tvOS 18)
  JellyTVApp.swift
  RootView.swift
  Info.plist                    (NSLocalNetworkUsageDescription, NSBonjourServices)

Packages/
  JellyfinAPI/                  actor JellyfinClient + Codable DTOs + DeviceProfile
  DesignSystem/                 colors, typography, shelf/card primitives, focus styles
  Library/                      Home (hero + shelves), library grid, item detail, search
  Player/                       AVPlayerViewController host + progress reporter + metadata injector
  Settings/                     server connect, sign in, about
  TopShelf/                     TVTopShelfContentProvider extension + shared App Group
  Persistence/                  SwiftData models + KeychainAccess wrapper
```

---

## 3. The player, in detail

**Decision:** `AVPlayerViewController` only. Do NOT build custom chrome. Do NOT follow SwiftFin PR #1902 down the `AVPlayerLayer` path.

### What `AVPlayerViewController` gives you free on tvOS (and only tvOS)

- Transport scrubber with thumbnail preview
- Audio / subtitle picker panel
- Chapter list (inject via `AVPlayerItem.navigationMarkerGroups` + `AVNavigationMarkersGroup`)
- **Info panel** (press up on Siri Remote) — inject metadata via `AVPlayerItem.externalMetadata` with `AVMetadataItem`s carrying `identifier`, `value`, `extendedLanguageTag`
- **Up Next / Skip Intro / Skip Credits / Next Episode** — sanctioned path is `contentProposalViewController` + `AVContentProposal` (WWDC21 session 10191)
- `transportBarCustomMenuItems` (tvOS 15+) — custom menu items like "Audio Delay" in the transport bar
- `customInfoViewController` — arbitrary SwiftUI in the Info panel's right pane (cast list, related items)
- Automatic frame-rate matching (`appliesPreferredDisplayCriteriaAutomatically = true`)
- Automatic HDR / Dolby Vision switching on HLS streams tagged with `VIDEO-RANGE`
- Siri Remote touchpad scrubbing
- `AVInterstitialTimeRange` for ad/promo markers

**None of this is reachable from `AVPlayerLayer`, VLCKit, or MPVKit.** Reproducing it is a months-long project and will feel wrong.

### Codec / HDR matrix (Apple TV 4K only)

| Codec / feature | Apple TV 4K gen 1/2 (A10X/A12) | Apple TV 4K gen 3 (A15) |
|---|---|---|
| H.264 High@L4.2 | HW, 1080p60 | HW, 1080p60 |
| HEVC Main/Main10 | HW, 2160p60 10-bit | HW, 2160p60 10-bit |
| AV1 | ❌ | ❌ SW only (no HW AV1 on any Apple TV as of April 2026) |
| VP9 | ❌ (AVFoundation) | ❌ (AVFoundation) |
| HDR10 / HDR10+ / HLG | ✅ | ✅ |
| Dolby Vision Profile 5, 8.1, 8.4 | ✅ | ✅ |
| **Dolby Vision Profile 7** (UHD BD rips) | ❌ | ❌ |
| E-AC-3 / Dolby Digital Plus | ✅ | ✅ |
| Atmos (E-AC-3 JOC in HLS) | ✅ | ✅ |
| **TrueHD / DTS / DTS-HD MA** | ❌ (no AVFoundation passthrough) | ❌ |
| AAC, ALAC, FLAC, Opus | ✅ | ✅ |
| WebVTT / CEA-608/708 subs | ✅ | ✅ |
| **PGS / ASS / SSA subs** | ❌ (must server-encode/burn-in) | ❌ |

For anything that falls off this matrix, let Jellyfin server-side transcode to HLS. Set a generous `MaxStreamingBitrate` in the DeviceProfile.

### Reference DeviceProfile (for `POST /Items/{id}/PlaybackInfo`)

Modeled on jellyfin-web's `isAppleTv()` branch and SwiftFin [PR #519](https://github.com/jellyfin/Swiftfin/pull/519):

```json
{
  "Name": "JellyTV tvOS (Native)",
  "MaxStreamingBitrate": 120000000,
  "MaxStaticBitrate": 100000000,
  "MusicStreamingTranscodingBitrate": 384000,
  "DirectPlayProfiles": [
    { "Container": "mp4,m4v,mov", "Type": "Video",
      "VideoCodec": "h264,hevc",
      "AudioCodec": "aac,ac3,eac3,mp3,alac,flac,opus" },
    { "Container": "mp3,aac,m4a,flac,alac,wav,opus", "Type": "Audio" }
  ],
  "TranscodingProfiles": [
    { "Container": "mp4", "Type": "Video", "Protocol": "hls",
      "VideoCodec": "h264,hevc", "AudioCodec": "aac,ac3,eac3",
      "Context": "Streaming", "MinSegments": 2, "BreakOnNonKeyFrames": true }
  ],
  "CodecProfiles": [
    { "Type": "Video", "Codec": "h264",
      "Conditions": [
        { "Condition": "LessThanEqual", "Property": "VideoLevel", "Value": "52", "IsRequired": true },
        { "Condition": "LessThanEqual", "Property": "VideoBitDepth", "Value": "8" }
      ]},
    { "Type": "Video", "Codec": "hevc",
      "Conditions": [
        { "Condition": "LessThanEqual", "Property": "VideoLevel", "Value": "153" },
        { "Condition": "LessThanEqual", "Property": "VideoBitDepth", "Value": "10" }
      ]}
  ],
  "SubtitleProfiles": [
    { "Format": "vtt",    "Method": "External" },
    { "Format": "ttml",   "Method": "External" },
    { "Format": "srt",    "Method": "External" },
    { "Format": "cc_dec", "Method": "Embed" },
    { "Format": "pgssub", "Method": "Encode" },
    { "Format": "ass",    "Method": "Encode" },
    { "Format": "ssa",    "Method": "Encode" }
  ],
  "ResponseProfiles": [
    { "Type": "Video", "Container": "m4v", "MimeType": "video/mp4" }
  ]
}
```

### Playback reporting cadence

- `POST /Sessions/Playing` on start
- `POST /Sessions/Playing/Progress` every ~10s with `PositionTicks` (seconds × 10,000,000) and `IsPaused`
- `POST /Sessions/Playing/Stopped` on end
- Route an `actor` to serialize these so the main actor doesn't block

---

## 4. UI / Layout

### The canonical tvOS 18 shelf+hero pattern

From Apple's [tvOS media catalog SwiftUI sample](https://developer.apple.com/documentation/SwiftUI/Creating-a-tvOS-media-catalog-app-in-SwiftUI):

```swift
ScrollView(.vertical) {
  LazyVStack(alignment: .leading, spacing: 60) {
    HeroSection()
      .onScrollVisibilityChange { belowFold = !$0 }
    Shelf("Continue Watching", items: resume)
    Shelf("Latest Movies",     items: latest)
    Shelf("Recommended",       items: recs)
  }
  .scrollTargetLayout()
}
.scrollClipDisabled()                     // critical — focused posters clip without this
.scrollTargetBehavior(.viewAligned)       // snap shelves

// each Shelf:
VStack(alignment: .leading) {
  Text(title).font(.title3)
  ScrollView(.horizontal) {
    LazyHStack(spacing: 40) {
      ForEach(items) { item in
        Button { open(item) } label: {
          item.poster
            .aspectRatio(2/3, contentMode: .fit)
            .containerRelativeFrame(.horizontal, count: 6, spacing: 40)
          Text(item.title)
        }
      }
    }
  }
  .scrollClipDisabled()
  .buttonStyle(.borderless)               // free parallax/lift/shadow — do NOT roll your own
}
.focusSection()                            // critical — keeps up/down between shelves
```

### Focus engine rules

- Use `.buttonStyle(.borderless)` (or `.card`) for focus effects. Do NOT hand-roll `scaleEffect` + `shadow`.
- `.focusSection()` on every shelf row and nav cluster.
- `@FocusState` + `.focused($id, equals:)` for programmatic focus.
- `.prefersDefaultFocus($state, in: ns)` + `@Namespace` on the Play button in detail views.
- `@FocusedValue(\.item)` to propagate the currently-focused item up the tree for the hero backdrop fade.
- Stable IDs on all list/grid data so focus survives reloads.
- Avoid `.onMoveCommand` — flaky on tvOS 18.0. Prefer focus sections.

### Search

- Use `.searchable(text: $query)` + `.searchSuggestions`. The tvOS system keyboard is good enough — do NOT build a custom one.
- Landing state: `query.isEmpty` → show "Recent searches" + "Top results" LazyVGrid.

### Detail page

- Backdrop image `.background` with gradient mask
- Metadata row + Play button with `.prefersDefaultFocus`
- Episode picker (for series) as a horizontal `LazyHStack` of episode cards
- Segmented picker: Episodes / Extras / More Like This / Cast

---

## 5. tvOS-specific gotchas

1. **`NSLocalNetworkUsageDescription` required** in Info.plist (tvOS 17+). Add `NSBonjourServices` entries for Jellyfin's `_jellyfin._tcp` if we do Bonjour discovery. SwiftFin hits real first-run edge cases here ([#467](https://github.com/jellyfin/Swiftfin/issues/467)).
2. **No PiP, no AirPlay-from-tvOS.** Both don't exist. Don't wire the UI. (`AVPictureInPictureController.isPictureInPictureSupported` returns false on tvOS.)
3. **No background playback.** Don't try. tvOS suspends aggressively by design.
4. **Caches directory is volatile.** System can evict at any time. Design poster cache with re-fetch as the normal path, not the error path.
5. **4K HDR memory pressure.** 3–4 GB RAM. Clear Nuke cache before pushing the player; cap `AVPlayerItem.preferredPeakBitRate` and `preferredMaximumResolution` based on TV resolution.
6. **Top Shelf extension is the single biggest engagement lever.** `TVTopShelfContentProvider` reading Continue Watching from a shared App Group container. App Group ID decided during scaffolding.
7. **Siri Remote contract:** if you consume `.onExitCommand`, you MUST provide a visible way back. Never swallow on the root screen.
8. **Game controller support:** skip it for v1. Near-zero user base for Jellyfin use cases.
9. **`onPlayPauseCommand` only fires when the view is focused** — chain `.focusable(true)` on container views that listen for it.

---

## 6. Phased plan

### Phase 0 — Scaffolding (day 1)

The existing `Jelly TV/` project is a fresh tvOS SwiftUI scaffold. Keep the target but set it up properly.

- [ ] Set deployment target to tvOS 18, Apple TV 4K only
- [ ] Add SPM packages: `JellyfinAPI`, `DesignSystem`, `Library`, `Player`, `Settings`, `Persistence`
- [ ] Add external deps: `Nuke`, `KeychainAccess`
- [ ] Info.plist: `NSLocalNetworkUsageDescription`, `NSBonjourServices`
- [ ] App Group entitlement (ID: `group.com.<you>.jellytv`) — reserved for Top Shelf in Phase 7
- [ ] Set up an `.env`/config-free pattern for dev server URL
- [ ] Basic CI (xcodebuild + unit test target) — optional but cheap

### Phase 1 — Connect + sign in (vertical slice foundation)

**Goal:** user can point the app at their LAN Jellyfin server and log in. Token persists across launches.

- [ ] `JellyfinClient` actor skeleton (`URLSession`, async/await, Codable DTOs)
- [ ] `MediaBrowserAuthorization` middleware builds the `Authorization: MediaBrowser …` header
- [ ] Persist a `DeviceId` UUID in Keychain on first launch
- [ ] `GET /System/Info/Public` — validate server reachability + version
- [ ] `POST /Users/AuthenticateByName` — username/password flow
- [ ] `GET /QuickConnect/Enabled` + `/Initiate` + `/Connect` polling + `AuthenticateWithQuickConnect` — Quick Connect flow (arguably easier than typing a password on a Siri Remote)
- [ ] Store access token in Keychain keyed by server URL
- [ ] `GET /Users/Me` — sanity check on app launch, auto-restore session
- [ ] Simple Settings screen: server URL, signed-in user, sign out
- [ ] **Must-not-regress test:** [#1862](https://github.com/jellyfin/Swiftfin/issues/1862) crash on Connect, [#1657](https://github.com/jellyfin/Swiftfin/pull/1657) persistent login

### Phase 2 — Home screen (hero + shelves)

**Goal:** signed-in user sees their libraries, Continue Watching, Next Up, Latest.

- [ ] `GET /UserViews` — libraries
- [ ] `GET /UserItems/Resume` — Continue Watching
- [ ] `GET /Shows/NextUp` — Next Up
- [ ] `GET /Items/Latest?parentId=…` — Latest per library
- [ ] `DesignSystem`: `PosterCard`, `Shelf`, `HeroSection` primitives
- [ ] Home view: `ScrollView` + `LazyVStack` + hero + shelves, with `.focusSection()` wiring
- [ ] `@FocusedValue` → hero backdrop crossfade
- [ ] Nuke `LazyImage` + downsampling helper for poster / backdrop images
- [ ] Image URL builder from item's `ImageTags[.Primary]` + `?maxWidth=`
- [ ] **Must-not-regress test:** [#1906](https://github.com/jellyfin/Swiftfin/issues/1906) Movies scroll crash

### Phase 3 — Library browse + search + item detail

**Goal:** user can browse a full library grid, search, open an item, see metadata.

- [ ] `GET /Items?parentId=…&includeItemTypes=…&recursive=true&sortBy=…` with paging
- [ ] Library grid view: `LazyVGrid`, poster cards, filters (genre, year, unplayed)
- [ ] `.searchable` + `GET /Items?searchTerm=…` — search across libraries
- [ ] `GET /Items/{id}?fields=Overview,Genres,People,Studios,Chapters,MediaSources`
- [ ] Item detail view: backdrop, metadata, Play button (`.prefersDefaultFocus`), segmented tabs (Episodes/Extras/More Like This/Cast) — scope "Extras" and "More Like This" as nice-to-haves for this phase
- [ ] For Series: `GET /Shows/{id}/Seasons` + `/Episodes?seasonId=…`, season/episode picker

### Phase 4 — Playback (the hard part)

**Goal:** user presses Play, the video plays with correct audio, subs, and progress reporting.

- [ ] DeviceProfile builder matching §3 spec
- [ ] `POST /Items/{id}/PlaybackInfo` with DeviceProfile → receive `MediaSources` with ready `TranscodingUrl` / DirectPlay URL
- [ ] `PlayerHost`: `UIViewControllerRepresentable` wrapping `AVPlayerViewController`
- [ ] Inject `AVPlayerItem.externalMetadata` (title, overview, artwork, year, genre)
- [ ] Inject chapters via `AVPlayerItem.navigationMarkerGroups`
- [ ] `PlaybackReporter` actor: start → progress (10s tick) → stopped, with `PositionTicks`
- [ ] Mark watched on reaching 90% (`POST /UserPlayedItems/{itemId}`)
- [ ] `MPNowPlayingInfoCenter` + `MPRemoteCommandCenter` wiring
- [ ] Memory pressure: clear Nuke cache before pushing player
- [ ] **Must-not-regress tests:** [#1755](https://github.com/jellyfin/Swiftfin/issues/1755) single audio track, [#780](https://github.com/jellyfin/Swiftfin/issues/780) external subs, [#1962](https://github.com/jellyfin/Swiftfin/issues/1962) touchpad FF/RW, [#1872](https://github.com/jellyfin/Swiftfin/issues/1872) no audio on resume

### Phase 5 — Polish pass

- [ ] Error states (network down, server unreachable, login failed, playback failed)
- [ ] Empty states (no libraries, no results)
- [ ] Loading skeletons for shelves
- [ ] Pull-the-thread on focus bugs: scroll-past-focus on LazyHStack, focus loss on reload, clip edges
- [ ] Settings: DeviceProfile override sliders (bitrate cap, force transcode)
- [ ] Sign out / switch server

### Phase 6 — Skip Intro / Up Next

- [ ] `AVContentProposal` + `contentProposalViewController` subclass
- [ ] Read Jellyfin's intro markers (if available — check `Chapters` for "Intro Start"/"Intro End" or the Intro Skipper plugin format)
- [ ] Next episode auto-queue on end-of-episode for series

### Phase 7 — Top Shelf extension

- [ ] `TVTopShelfContentProvider` target
- [ ] App Group container — main app writes Continue Watching JSON on every refresh
- [ ] Extension reads from App Group, returns `TVTopShelfSectionedContent`
- [ ] Deep link back into the app → jump to item detail / resume playback

### Phase 8 — Remote access (post-v1)

- [ ] HTTPS support (already works via `URLSession`; verify TLS cert handling, self-signed cert UX)
- [ ] Jellyfin "Remote Access" server URL storage — separate from LAN URL, with fallback logic
- [ ] Adaptive bitrate for slower connections (dynamic `MaxStreamingBitrate`)
- [ ] Reachability detection to pick LAN vs remote URL automatically
- [ ] Potentially: UDP broadcast discovery via `Shared/ServerDiscovery/` pattern from SwiftFin

### Deferred (not in v1, probably not v1.1)

- Multi-user / multi-server
- Offline downloads (tvOS's volatile caches directory + no real persistent storage makes this painful)
- Live TV (needs its own DeviceProfile work and SwiftFin's [#1948](https://github.com/jellyfin/Swiftfin/issues/1948) WAN bug to learn from)
- VLCKit / MPVKit fallback player — only if real users have Profile 7 DV / PGS / TrueHD / DTS libraries
- Game controller support
- visionOS target

---

## 7. "Must not regress" acceptance checklist

Every one of these is a real SwiftFin tvOS bug on the v1.0.1 App Store build. v1 of JellyTV ships when all are green on a real Apple TV 4K against a real Jellyfin server:

- [ ] No crash on Connect / sign in
- [ ] No crash / timeout scrolling a large Movies library
- [ ] Only one audio track plays at a time
- [ ] External SRT / VTT subtitles render correctly
- [ ] Touchpad FF / RW works during playback
- [ ] Persistent login — app relaunches into the last session
- [ ] No audio dropouts on resume
- [ ] DeviceProfile causes DirectPlay when possible, HLS transcode otherwise
- [ ] Progress reporting shows up on server's "Now Playing" immediately
- [ ] Continue Watching surfaces the thing you were just watching within 10s
- [ ] Focus survives content reload in all grids/shelves
- [ ] `.onExitCommand` always returns to a sensible place

---

## 8. Reading list (do this before writing code)

### Apple sources
- [Apple sample: "Creating a tvOS media catalog app in SwiftUI"](https://developer.apple.com/documentation/SwiftUI/Creating-a-tvOS-media-catalog-app-in-SwiftUI) — *the* layout pattern
- [Apple sample: "Destination Video"](https://developer.apple.com/documentation/visionOS/destination-video) — `PlayerView` / `PlayerModel` wrapping `AVPlayerViewController` with `externalMetadata`
- [WWDC24 10207 "Migrate your TVML app to SwiftUI"](https://developer.apple.com/videos/play/wwdc2024/10207/) — best 2024 tvOS layout session
- [WWDC24 10144 "What's new in SwiftUI"](https://developer.apple.com/videos/play/wwdc2024/10144/) — new Tab/TabView syntax, sidebar
- [WWDC23 10162 "The SwiftUI cookbook for focus"](https://developer.apple.com/videos/play/wwdc2023/10162/) — canonical focus reference
- [WWDC21 10191 "Deliver a great playback experience on tvOS"](https://developer.apple.com/videos/play/wwdc2021/10191/) — `externalMetadata`, content proposals, transport bar items
- [Apple HDR + Dolby Vision PDF](https://developer.apple.com/av-foundation/Incorporating-HDR-video-with-Dolby-Vision-into-your-apps.pdf)
- [TVTopShelfContentProvider docs](https://developer.apple.com/documentation/tvservices/tvtopshelfcontentprovider)

### Jellyfin sources
- [Jellyfin codec support matrix](https://jellyfin.org/docs/general/clients/codec-support/)
- [Jellyfin OpenAPI spec](https://api.jellyfin.org/openapi/jellyfin-openapi-stable.json)
- [nielsvanvelzen Jellyfin Authorization gist](https://gist.github.com/nielsvanvelzen/ea047d9028f676185832e51ffaf12a6f) — canonical auth header + deprecations
- [jellyfin-web DeviceProfile reference](https://github.com/jellyfin/jellyfin-web/blob/master/src/scripts/browserDeviceProfile.js) — `isAppleTv()` branch
- [Jellyfin Quick Connect docs](https://jellyfin.org/docs/general/server/quick-connect/)
- [jmshrv.com "The Jellyfin API"](https://jmshrv.com/posts/jellyfin-api/) — practical API walkthrough

### SwiftFin (reference only, do not fork)
- [jellyfin/Swiftfin](https://github.com/jellyfin/Swiftfin)
- [Discussion #1294 — tvOS status](https://github.com/jellyfin/Swiftfin/discussions/1294)
- [PR #519 — DeviceProfile revamp](https://github.com/jellyfin/Swiftfin/pull/519)
- [PR #1902 — tvOS Media Player rewrite](https://github.com/jellyfin/Swiftfin/pull/1902) (the direction we're NOT taking)

### Community
- [jellyfin/jellyfin-sdk-swift](https://github.com/jellyfin/jellyfin-sdk-swift) — live API reference
- [Showmax: "Our experience with SwiftUI on tvOS"](https://showmax.engineering/articles/our-experience-with-swiftui-on-tvos) — candid rough edges
- [streamyfin/streamyfin](https://github.com/streamyfin/streamyfin) — RN/MPVKit, no tvOS yet ([#137](https://github.com/streamyfin/streamyfin/issues/137))
- [kean/Nuke](https://github.com/kean/Nuke)
- [kishikawakatsumi/KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess)

---

## 9. Open questions / risks

- **Server Jellyfin version matrix.** We should test against Jellyfin 10.9 and 10.11 both. 10.11 is where [#1906](https://github.com/jellyfin/Swiftfin/issues/1906) surfaces on SwiftFin.
- **Quick Connect vs username/password.** Quick Connect is dramatically better UX on tvOS (no Siri Remote typing). Should be the default sign-in path with password as fallback. Confirm the server has it enabled via `GET /QuickConnect/Enabled`.
- **Intro Skipper plugin format.** Jellyfin has a community "Intro Skipper" plugin that exposes intro chapters. Format needs verification before Phase 6.
- **Bonjour discovery vs manual URL entry.** SwiftFin's `Shared/ServerDiscovery/` does UDP broadcast. On LAN this is nicer UX but adds complexity and a known Bonjour failure mode ([SwiftFin #467](https://github.com/jellyfin/Swiftfin/issues/467)). Start with manual URL; add Bonjour in polish pass.
- **Chapter thumbnails.** Jellyfin exposes `Chapters[].ImageTag` for chapter images but you have to build the URL yourself. Worth the polish for the scrubber thumbnail preview.
- **App Store review.** No blockers foreseen, but first submission should budget a week of review churn.

---

## 10. Next step

Drop into `/motif:dev build a tvOS Jellyfin client — Phase 0 and Phase 1` to run the formal Plan stage on the first executable chunk, with tradeoff analysis and an approval gate, before any code gets written. This doc becomes the research artifact the Plan stage cites from.
