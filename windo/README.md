<p align="center">
  <a href="https://github.com/zackbart/apps/tree/main/windo">
    <img src="https://shieldcn.dev/header/graph.svg?title=Windo&subtitle=floating+always-on-top+web+window+for+macOS&logo=apple&mode=light&align=center&font=geist-mono&border=false" alt="Windo">
  </a>
</p>

<p align="center">
  <a href="https://github.com/zackbart/apps/releases/download/windo-v0.1.7/Windo-0.1.7.dmg">
    <img src="https://shieldcn.dev/badge/Download-Windo.dmg-blue.svg?logo=apple&size=lg" alt="Download the latest Windo.dmg">
  </a>
  <a href="https://github.com/zackbart/apps/releases/tag/windo-v0.1.7">
    <img src="https://shieldcn.dev/badge/Release-0.1.7-blue.svg" alt="Latest Windo release">
  </a>
  <a href="https://github.com/zackbart/apps/blob/main/windo/LICENSE">
    <img src="https://shieldcn.dev/badge/License-MIT-blue.svg" alt="MIT license">
  </a>
  <a href="https://github.com/zackbart/apps/stargazers">
    <img src="https://shieldcn.dev/github/stars/zackbart/apps.svg" alt="Stars">
  </a>
</p>

A floating, always-on-top web window for macOS — watch YouTube, live sports, or
any non-DRM web video on top of other apps, including over full-screen apps.

A menu-bar utility (no Dock icon). Liquid Glass control pill, ambient title bar
that tints to the video, global hotkey, favorites, opacity, and compact mode.

Pause When Hidden (menu-bar toggle, on by default): hiding the window pauses
whatever is playing, and showing it again resumes it.

## Install

Grab the `.dmg` from the [latest Windo release](https://github.com/zackbart/apps/releases/tag/windo-v0.1.7), or install via Homebrew:

```bash
brew install --cask zackbart/tap/windo
```

Requires macOS 26 (Tahoe) — uses the native Liquid Glass APIs.

## Develop

```bash
brew install xcodegen
xcodegen generate && open Windo.xcodeproj   # then ⌘R
```

`project.yml` is the source of truth; `Windo.xcodeproj` is generated and gitignored.
All app code is one file: `Sources/main.swift` (AppKit + WKWebView, no dependencies).

## Shortcuts

| Action | Key |
|---|---|
| Show/hide from anywhere | ⌃⌘H |
| Focus URL | ⌘L |
| Reload | ⌘R |
| Add to favorites | ⌘D |
| Compact mode | ⌘. |

Drag the title bar to move; hold ⌥ and drag anywhere as a backup. The control
pill (bottom-left) expands on hover.

## Releasing

Tag-driven. Bump `MARKETING_VERSION` in `project.yml`, commit, then:

```bash
git tag windo-v0.1.8
git push origin windo-v0.1.8
```

The repository release workflow builds on `macos-26`, signs with Developer ID,
notarizes + staples, publishes a `Windo-<version>.dmg` to GitHub Releases, and
bumps the Homebrew cask in `zackbart/homebrew-tap`.

## License

MIT
