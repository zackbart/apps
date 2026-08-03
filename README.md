# Native apps

A collection of native apps built to solve problems I have.

## Apps

| App | Platform | Description |
| --- | --- | --- |
| [Barr](barr/) | macOS | A second home for menu bar apps. |
| [Windo](windo/) | macOS | A floating, always-on-top web window. |
| [Loadout](loadout/) | macOS and iOS | Inspect AI-agent skills and MCP servers configured on a machine. |
| [Livewall](livewall/) | macOS | Native live wallpapers for macOS. |
| [MrMouse](mrmouse/) | macOS | A lightweight Logitech MX Master 3S driver. |
| [Herdr iOS](herdr-ios/) | iOS | A SwiftUI client for Herdr. |
| [JellyTV](jellytv/) | tvOS | A Live-TV-first Jellyfin client for Apple TV. |

Each app owns its project files, documentation, and license. Run development
commands from the app directory unless its README says otherwise.

## Releases

Barr, Windo, and Loadout are built, signed, notarized, published to GitHub
Releases, and submitted to the Homebrew tap by the shared release workflow.
Release tags are app-scoped to keep versions independent:

```text
barr-v0.0.10
windo-v0.1.7
loadout-v0.1.3
```

The workflow requires these repository Actions secrets:

- `BUILD_CERTIFICATE_BASE64`
- `P12_PASSWORD`
- `APPLE_TEAM_ID`
- `AC_API_KEY_BASE64`
- `AC_API_KEY_ID`
- `AC_API_ISSUER_ID`
- `HOMEBREW_TAP_TOKEN`

Historical releases and assets are preserved here under `legacy-<app>-v*`
tags. See [LEGACY.md](LEGACY.md) for the migration map.
