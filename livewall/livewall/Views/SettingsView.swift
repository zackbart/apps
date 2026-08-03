import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var engine = WallpaperEngine.shared
    @ObservedObject private var displayManager = DisplayManager.shared

    var body: some View {
        ZStack {
            AppAmbientBackground()

            TabView {
                generalTab
                    .tabItem {
                        Label("General", systemImage: "gearshape")
                    }

                displaysTab
                    .tabItem {
                        Label("Displays", systemImage: "display.2")
                    }

                aboutTab
                    .tabItem {
                        Label("About", systemImage: "info.circle")
                    }
            }
        }
        .frame(minWidth: 520, minHeight: 360)
    }

    private var generalTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.spacingXL) {
                settingsHero(
                    title: "Playback, without the clutter.",
                    detail: "Keep LiveWall responsive, battery-aware, and quietly present in the background.",
                    systemImage: "dial.low"
                )

                settingsSection(
                    title: "Performance",
                    detail: "Control how aggressively LiveWall yields to power conditions."
                ) {
                    preferenceRow(
                        title: "Pause on battery or low power",
                        detail: "Automatically pause wallpapers when running on battery power or in Low Power Mode.",
                        systemImage: "bolt.slash",
                        isOn: $settings.pauseOnBattery
                    )

                    Divider()

                    preferenceRow(
                        title: "Low power mode",
                        detail: "Reduce CPU usage by pausing wallpaper playback while you focus on heavier tasks.",
                        systemImage: "leaf",
                        isOn: $settings.lowPowerMode
                    )
                }

                settingsSection(
                    title: "System",
                    detail: "Choose whether LiveWall should already be waiting for you after login."
                ) {
                    preferenceRow(
                        title: "Launch at login",
                        detail: "Automatically start LiveWall when you log in.",
                        systemImage: "power",
                        isOn: $settings.launchAtLogin
                    )
                }
            }
            .padding(Metrics.spacingXXL)
        }
    }

    private var displaysTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.spacingXL) {
                settingsHero(
                    title: "Displays at a glance.",
                    detail: "See what is connected, what is playing, and refresh the layout when your setup changes.",
                    systemImage: "display.2"
                )

                HStack(spacing: Metrics.spacingS) {
                    StatusPill(
                        title: "\(displayManager.displays.count) connected",
                        systemImage: "display"
                    )
                    StatusPill(
                        title: "\(engine.activeWallpapers.count) active",
                        systemImage: "play.circle.fill",
                        tint: engine.activeWallpapers.isEmpty ? nil : .green
                    )

                    Spacer()

                    Button {
                        displayManager.refreshDisplays()
                        engine.refreshDisplays()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.glass)
                    .controlSize(.regular)
                }

                if displayManager.displays.isEmpty {
                    ContentUnavailableView(
                        "No Displays Detected",
                        systemImage: "display.trianglebadge.exclamationmark",
                        description: Text("Connect a display and tap Refresh.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Metrics.spacingXXL)
                } else {
                    VStack(spacing: Metrics.spacingS) {
                        ForEach(displayManager.displays) { display in
                            displayRow(display)
                        }
                    }
                }
            }
            .padding(Metrics.spacingXXL)
        }
    }

    private var aboutTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.spacingXL) {
                settingsHero(
                    title: "LiveWall",
                    detail: "A lightweight live wallpaper app for macOS that keeps the desktop cinematic without turning the rest of the system into noise.",
                    systemImage: "sparkles.tv.fill"
                )

                settingsSection(
                    title: "What it does well",
                    detail: "The product is intentionally focused and desktop-native."
                ) {
                    aboutRow(
                        title: "Multi-display playback",
                        detail: "Run a different live wallpaper on each connected screen.",
                        systemImage: "rectangle.on.rectangle"
                    )

                    Divider()

                    aboutRow(
                        title: "Hover and inline previews",
                        detail: "See motion before applying whenever the video is already on disk.",
                        systemImage: "play.rectangle"
                    )

                    Divider()

                    aboutRow(
                        title: "Power-aware behavior",
                        detail: "Pause automatically on battery or low power when you want it to.",
                        systemImage: "bolt.badge.clock"
                    )
                }

                HStack(spacing: Metrics.spacingS) {
                    StatusPill(title: "Version 1.0", systemImage: "app.badge")
                    StatusPill(title: "macOS 26+", systemImage: "desktopcomputer")
                }
            }
            .padding(Metrics.spacingXXL)
        }
    }

    private func settingsHero(title: String, detail: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: Metrics.spacingL) {
            VStack(alignment: .leading, spacing: Metrics.spacingS) {
                Text(title)
                    .font(.largeTitle.weight(.bold))

                Text(detail)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.tint)
                .padding(Metrics.spacingL)
                .glassEffect(.regular, in: .rect(cornerRadius: Metrics.radiusM))
        }
        .padding(Metrics.spacingXL)
        .background {
            RoundedRectangle(cornerRadius: Metrics.radiusL, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: Metrics.radiusL, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                }
        }
    }

    private func settingsSection<Content: View>(title: String, detail: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Metrics.spacingM) {
            VStack(alignment: .leading, spacing: Metrics.spacingXS) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                content()
            }
            .background {
                RoundedRectangle(cornerRadius: Metrics.radiusL, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
                    .overlay {
                        RoundedRectangle(cornerRadius: Metrics.radiusL, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    }
            }
        }
    }

    private func preferenceRow(title: String, detail: String, systemImage: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(alignment: .top, spacing: Metrics.spacingM) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: Metrics.spacingXS) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(Metrics.spacingL)
        }
        .toggleStyle(.switch)
    }

    private func displayRow(_ display: DisplayInfo) -> some View {
        let activeWP = engine.activeWallpapers[display.id]
        return HStack(spacing: Metrics.spacingM) {
            Image(systemName: "display")
                .font(.title3)
                .foregroundStyle(activeWP == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(display.localizedName)
                    .font(.callout.weight(.medium))
                Text(String(format: "%.0f × %.0f", display.resolution.width, display.resolution.height))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let activeWP {
                Label(activeWP.title, systemImage: "play.circle.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("No wallpaper")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(Metrics.spacingL)
        .background {
            RoundedRectangle(cornerRadius: Metrics.radiusM, style: .continuous)
                .fill(activeWP == nil ? Color.primary.opacity(0.04) : Palette.activeGreenTint)
                .overlay {
                    RoundedRectangle(cornerRadius: Metrics.radiusM, style: .continuous)
                        .strokeBorder(
                            activeWP == nil ? Color.primary.opacity(0.08) : Color.green.opacity(0.35),
                            lineWidth: 1
                        )
                }
        }
    }

    private func aboutRow(title: String, detail: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: Metrics.spacingM) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: Metrics.spacingXS) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(Metrics.spacingL)
    }
}
