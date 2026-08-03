# CLAUDE.md

Guidance for Claude Code working on the livewall repo.

## What this is

Native macOS live wallpaper app for **macOS 26 (Tahoe)**. SwiftUI + AVFoundation + Liquid Glass. Plays muted looping videos at `desktopWindow + 1` level across multiple displays. Single-user app, no backend, no accounts. See `README.md` for the feature list.

## Build

```bash
xcodebuild -scheme livewall -configuration Debug build
```

Scheme: `livewall`. Target: macOS 26.2. No tests, no linter configured.

For a clean build (recommended when changing `@MainActor` annotations or adding new source files):

```bash
xcodebuild -scheme livewall -configuration Debug clean build
```

Filter logs:

```bash
log stream --predicate 'subsystem == "com.cursorkittens.livewall"' --level debug
```

## Development workflow

The user works through the **motif workflow** (`/motif:dev <task>`) for non-trivial changes. The pattern is Research → Plan → (2 or 3 parallel Critics for medium/heavy) → Build → Validate. The plan is the single approval gate; the user is often in `--auto` mode so the plan auto-approves and the full cycle runs hands-off. **Respect the plan gate anyway** — write a real plan, address critic findings explicitly, and don't skip Validate.

For small, clearly-scoped fixes (one file, one bug, no design question), you can skip the workflow and just edit directly.

## Architecture cheat sheet

### Scenes (`livewallApp.swift`)
- `WindowGroup(id: "main")` → `GalleryView()`
- `WindowGroup(id: "settings")` → `SettingsView()` — **not** `Settings {}` scene (that would break `openWindow(id: "settings")` callers in the gallery and menu bar)
- `WindowGroup(id: "import")` → `ImportView()`
- `MenuBarExtra(.window)` → `MenuBarExtraView()`
- `.appErrorAlert()` is attached once per `WindowGroup` at the scene root

### Services (singletons, all under `Services/`)
- `WallpaperEngine` — owns per-display `WallpaperWindow`s, playback control, battery monitoring, stale-file check (`ensureAvailable`)
- `WallpaperWindow` — NSWindow subclass at `desktop+1` level; contains `WallpaperPlayerView` (NSView with AVPlayerLayer)
- `WallpaperCatalog` — loads `Resources/catalog.json` + `~/Library/Application Support/livewall/imported/` wallpapers; computes `staleLocalWallpaperIDs`; owns `addLocalWallpaper` and `removeLocalWallpaper`
- `DownloadManager` — **`@MainActor`** — downloads catalog wallpapers to `~/Library/Application Support/livewall/wallpapers/`, publishes per-wallpaper `DownloadState`
- `DisplayManager` — wraps `NSScreen.screens`, builds `DisplayInfo` from `CGDirectDisplayID`
- `SettingsManager` — `@Published` UserDefaults-backed properties; owns `launchAtLogin` via `SMAppService.mainApp`
- `ThumbnailGenerator` — `@Observable`, generates thumbnails for imported videos using `AVAssetImageGenerator.image(at:)` (async)
- `VideoPreviewPool` — **`@MainActor`** — caps concurrent `AVPlayer`s at 2, LRU eviction, keyed by wallpaper ID
- `AppLogger` — `os.Logger` namespace (categories: `app`, `engine`, `catalog`, `download`, `playback`, `thumbnail`, `settings`)
- `AppErrorPresenter` — **`@MainActor`** — `@Published var currentError: AppError?` with `title + message` dedup; exposes `nonisolated static func report(title:message:recoverySuggestion:)` for call sites in any context

### Views
- `GalleryView` — `@ObservedObject` on catalog/engine/downloadManager; `LazyVStack` with a **non-pinned** "Now Playing" section above a **pinned** tag-strip section header; `.searchable(.toolbar)`; drag-drop via `.onDrop`; welcome sheet gated by `@AppStorage("hasSeenWelcome")`
- `WallpaperCardView` — takes `wallpaper`, `isActive`, `isStale: Bool = false`, `onTap`; hover preview via `VideoPreviewPlayer` only for cached/local files; `isActive` is passed in (cards don't observe engine directly)
- `WallpaperDetailView` — inline `VideoPreviewPlayer` for cached/local files; static hero with "unlocks after Apply" hint otherwise; per-display Apply/Remove buttons react to `DownloadManager` state; when `isStale`, shows "Remove Missing Entry" instead of Apply
- `VideoPreviewPlayer` — `NSViewRepresentable` wrapping `AVPlayerLayer`; `Coordinator` stashes `wallpaperID` so `dismantleNSView` can release from the pool

## Conventions and gotchas

### Liquid Glass rules
- `.glassEffect(.regular, in: shape)` is for **chrome and controls**: toolbar, tag chips, badges, buttons, row backgrounds.
- **Do not** apply glass to wallpaper cards or other content surfaces — reduces contrast and fights Apple's HIG.
- `GlassEffectContainer` + `glassEffectID` morphing is only for small sibling groups (2–5 items), **never** wrap a `LazyVGrid` with it.
- Buttons use `.buttonStyle(.glass)` for secondary and `.buttonStyle(.glassProminent)` for primary CTAs.
- `ToolbarSpacer(.flexible)` separates toolbar groups if needed.

### Reactive state
- Singletons (`WallpaperEngine.shared`, etc.) that are `ObservableObject` must be referenced via `@ObservedObject`, **never** `@StateObject`. `@StateObject` with an existing instance creates a shadow copy that silently diverges from `.shared`.
- Views that need reactive updates from multiple services declare one `@ObservedObject` per service.
- Cards in a lazy grid should not observe services directly — pass the narrow piece of state they need (like `isActive: Bool`) from a parent that does.

### `os.Logger` privacy interpolation
Every file that uses `AppLogger.<category>.error("\(value, privacy: .public)")` must `import os` at the top, **in addition to** the existing `AppLogger` enum. The privacy string-interpolation machinery lives in the `os` module. Forgetting this causes a dozen confusing "method is not available due to missing import" errors.

### `AppErrorPresenter.report` naming
Do not name a free function `presentError` — it shadows `NSResponder.presentError(_:)` inside any NSView/NSWindow subclass. Use the static `AppErrorPresenter.report(title:message:recoverySuggestion:)` instead. It's `nonisolated` with an internal `Task { @MainActor in }` hop, so it's safe to call from any context including KVO callbacks on arbitrary queues.

### AVPlayer lifecycle
- `NSKeyValueObservation` tokens from `AVPlayerItem.observe(\.status, ...)` **must** be stored on a property or they deallocate immediately and never fire. See `WallpaperPlayerView.statusObservation`.
- `AVPlayer`, `AVAsset`, and `AVPlayerLayer` must be configured on the main thread. `VideoPreviewPool` is `@MainActor` to enforce this.
- Use `AVURLAsset(url:)`, not `AVAsset(url:)` — the latter is deprecated in macOS 15+. For duration/natural-size, use the async `load(.naturalSize)` / `load(.duration)` APIs.

### Stale-file handling
- `WallpaperCatalog.staleLocalWallpaperIDs: Set<String>` is the source of truth.
- `GalleryView` passes `isStale:` down to each `WallpaperCardView`.
- `WallpaperEngine.ensureAvailable(_:)` runs at the top of `apply(_:scope:)` and at the top of the public `setWallpaper(_:forDisplay:)`. The internal `setWallpaperInternal` hot path skips the check. This guarantees "Apply to All" surfaces exactly **one** error dialog even across many displays.

### `@MainActor` and service boundaries
- `DownloadManager`, `AppErrorPresenter`, and `VideoPreviewPool` are `@MainActor`.
- `WallpaperEngine`, `WallpaperCatalog`, `WallpaperWindow`, `ThumbnailGenerator`, `SettingsManager` are plain classes.
- When a plain-class service needs to surface an error to the user, it calls `AppErrorPresenter.report(...)` which handles the hop internally.
- Do **not** call `AppErrorPresenter.shared.present(...)` directly from a non-main context.

### Not a git repo → now is
The repo was originally not under git. Initial commit is `bf7d244`. Remote: `origin → https://github.com/zackbart/livewall.git`. The `.gitignore` excludes Xcode user state, build products, `.motif/` workflow state, and `.claude/`.

### Deliberately NOT doing
- No lock-screen wallpaper feature (requires a separate macOS 26 API surface)
- No AI/semantic search (infrastructure project)
- No AVPlayer stall detection (`timeControlStatus`/`isPlaybackLikelyToKeepUp`) — only explicit `.failed` status is surfaced
- No `URLSessionDownloadDelegate` for real download progress — current indicator is indeterminate
- No crash reporter / telemetry / analytics
- No curated gallery expansion (content pipeline is a separate concern)
- No `Settings {}` scene conversion (would break `openWindow(id: "settings")`)
- No `NavigationStack` in the gallery (feels wrong on macOS — we use a `@State selectedWallpaper` swap instead)
- No red-alarm UI for stale cards (subtle grayscale + orange pill)
- No automated tests (no test target exists)

## When adding new features

1. If it's a bug fix or single-file change, edit directly.
2. If it's a feature or touches more than 2 files, use `/motif:dev <task>`.
3. Run `xcodebuild -scheme livewall -configuration Debug build` after changes. It's fast; use it liberally as a checkpoint.
4. New services that need to log: add a new category to `AppLogger`.
5. New services that can fail user-visibly: call `AppErrorPresenter.report(...)`.
6. New NSView/NSWindow subclasses that need error surfacing: same — but remember the `NSResponder.presentError` name clash.
7. New `ObservableObject` singletons: views observe them with `@ObservedObject`, never `@StateObject`.
8. If you add a new file that uses `AppLogger.<x>.<method>("\(value, privacy: .public)")`, `import os` at the top of the file.
