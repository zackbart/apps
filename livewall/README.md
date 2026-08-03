# livewall

A native macOS live wallpaper app for macOS 26 (Tahoe), built with SwiftUI + AVFoundation and Apple's Liquid Glass design system.

Play muted, looping video wallpapers behind your desktop across any number of displays. Import your own MP4/MOV files, browse a curated catalog, or drop videos onto the window. Previews play live on hover and in the detail view. Designed to be lightweight and battery-aware.

## Features

- **Multi-display playback** — set a different wallpaper on each connected display, or apply one to all at once. Windows sit at `desktopWindow + 1` level and stay behind everything else.
- **Video preview on card hover** — cached wallpapers play a muted preview when you hover. Pooled to cap concurrent players, debounced to avoid thrash.
- **Live preview in detail view** — the full detail pane plays the wallpaper inline so you can see exactly what you're about to apply.
- **Drag-and-drop import** — drop any MP4 or MOV onto the gallery window. A glass drop overlay confirms the target.
- **"Now Playing" section** — shows what's currently set on each display, with per-display stop buttons and a Pause All/Resume toggle.
- **Liquid Glass chrome** — toolbar, tag filter, badges, buttons, and row backgrounds use macOS 26's `.glassEffect` + `.buttonStyle(.glass)`. Cards themselves stay opaque per Apple HIG for content legibility.
- **First-launch welcome sheet** — brief orientation and a one-click path into the gallery.
- **Menu bar extra** — quick pause/resume, active wallpaper list, and shortcuts to Import, Settings, and quit.
- **Battery-aware auto-pause** — automatically pauses playback when you unplug or enable Low Power Mode (configurable in Settings). Polls every 30 seconds + observes `NSProcessInfoPowerStateDidChange` and `NSWorkspace.didWakeNotification`.
- **Stale file detection** — imported wallpapers whose files have been moved or deleted are shown with a subtle "Missing" badge; the detail view offers a one-click "Remove Missing Entry".
- **Centralized error surfacing** — one `AppErrorPresenter` attached once per window. Services log via `os.Logger` (subsystem `com.cursorkittens.livewall`) and surface user-visible errors through a single deduped alert path.

## Requirements

- **macOS 26.0 (Tahoe) or later** — the app uses Liquid Glass APIs (`glassEffect`, `buttonStyle(.glass)`, etc.) that are only available on macOS 26.
- **Xcode 17** or later (for the macOS 26 SDK).
- Apple Silicon or Intel Mac.

## Building

Clone the repo and open in Xcode, or build from the command line:

```bash
git clone https://github.com/zackbart/livewall.git
cd livewall
xcodebuild -scheme livewall -configuration Debug build
```

To run:

1. Open `livewall.xcodeproj` in Xcode 17+.
2. Select the `livewall` scheme.
3. ⌘R.

## Project structure

```
livewall/
├── livewallApp.swift              # App entry — 3 WindowGroup scenes + MenuBarExtra
├── Models/
│   └── Wallpaper.swift             # Wallpaper model + catalog/local variants
├── Services/                       # Singleton services (@MainActor where needed)
│   ├── AppLogger.swift             # os.Logger namespace (engine, catalog, playback, ...)
│   ├── AppErrorPresenter.swift     # Shared error state + .appErrorAlert() modifier
│   ├── WallpaperEngine.swift       # Per-display NSWindow lifecycle, battery monitor
│   ├── WallpaperWindow.swift       # NSWindow at desktop+1 level, AVPlayerLayer playback
│   ├── WallpaperCatalog.swift      # catalog.json + local imports + stale-file detection
│   ├── DownloadManager.swift       # Catalog wallpaper downloads (with state publishing)
│   ├── DisplayManager.swift        # NSScreen enumeration
│   ├── SettingsManager.swift       # UserDefaults-backed settings (@Published)
│   ├── ThumbnailGenerator.swift    # AVAssetImageGenerator thumbnails for local imports
│   └── VideoPreviewPool.swift      # Pooled AVPlayer instances for hover previews (cap: 2)
├── Views/
│   ├── GalleryView.swift           # Main browser + toolbar + Now Playing + drag-drop
│   ├── WallpaperCardView.swift     # Grid card with hover preview + stale badge
│   ├── WallpaperDetailView.swift   # Full detail + live preview + apply/remove
│   ├── SettingsView.swift          # TabView: General / Displays / About
│   ├── MenuBarExtraView.swift      # Menu bar popover
│   ├── ImportView.swift            # File picker import flow
│   ├── WelcomeSheet.swift          # First-launch welcome
│   └── VideoPreviewPlayer.swift    # NSViewRepresentable around AVPlayerLayer + pool
└── Resources/
    └── catalog.json                # Bundled seed catalog (optional)
```

## Architecture notes

- **Scenes**: three `WindowGroup`s (`main`, `settings`, `import`) plus a `MenuBarExtra(.window)`. Settings is a regular `WindowGroup` (not the `Settings {}` scene) so `openWindow(id: "settings")` continues to work from the menu bar and gallery toolbar.
- **Services as singletons**: `WallpaperEngine.shared`, `WallpaperCatalog.shared`, `DownloadManager.shared`, `SettingsManager.shared`, `ThumbnailGenerator.shared`, `VideoPreviewPool.shared`. Views observe with `@ObservedObject`, **not** `@StateObject` — `@StateObject` with a singleton silently creates a shadow copy.
- **Display detection of active wallpapers** is scoped: `GalleryView` computes `activeWallpaperIDs: Set<String>` once and passes it to each card as a plain `Bool`, so card re-renders are localized when the engine updates.
- **Hover video previews** only play for files that already exist on disk (local imports or cached downloads). Remote URLs never auto-stream on hover. The pool caps at 2 concurrent players.
- **Error handling**: services call `AppErrorPresenter.report(title:message:recoverySuggestion:)`, a `nonisolated static` method that handles the main-actor hop internally. One `.appErrorAlert()` modifier is attached per WindowGroup at the scene root in `livewallApp.swift` — never per-view. The presenter dedupes by `title + message` so simultaneous failures from multiple displays don't stomp each other.
- **Catalog stale detection**: `WallpaperCatalog.loadLocalWallpapers()` flags any imported wallpaper whose backing file is missing. Cards show a subtle grayscale + "Missing" badge. `WallpaperEngine.apply(_:scope:)` also guards with `ensureAvailable(_:)` so a missing file surfaces a single alert regardless of how many displays were targeted.
- **Battery monitoring**: `WallpaperEngine.setupBatteryMonitoring()` combines `NSWorkspace.didWakeNotification`, `NSProcessInfoPowerStateDidChange`, and a 30-second polling `Timer` to catch plug/unplug events between notifications. Auto-pause is gated on `SettingsManager.shared.pauseOnBattery`.

## Logs

Filter livewall's logs in Console.app by **Subsystem: `com.cursorkittens.livewall`**, or from the terminal:

```bash
log stream --predicate 'subsystem == "com.cursorkittens.livewall"' --level debug
```

Categories: `app`, `engine`, `catalog`, `download`, `playback`, `thumbnail`, `settings`.

## License

Not yet specified — all rights reserved for now.
