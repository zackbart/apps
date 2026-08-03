import SwiftUI

struct MenuBarExtraView: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var engine = WallpaperEngine.shared
    @ObservedObject private var displayManager = DisplayManager.shared

    private var orderedActive: [(display: DisplayInfo, wallpaper: Wallpaper)] {
        displayManager.displays.compactMap { display in
            engine.activeWallpapers[display.id].map { (display, $0) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingM) {
            header

            Button(engine.isPaused ? "Resume Wallpapers" : "Pause Wallpapers") {
                if engine.isPaused {
                    engine.resumeAll()
                } else {
                    engine.pauseAll()
                }
            }
            .buttonStyle(.glassProminent)
            .controlSize(.regular)
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .frame(maxWidth: .infinity)

            if !orderedActive.isEmpty {
                activeWallpapersSection
            }

            VStack(spacing: Metrics.spacingS) {
                menuAction(title: "Open LiveWall", systemImage: "sparkles.tv.fill") {
                    openWindow(id: "main")
                }
                .keyboardShortcut("o", modifiers: .command)

                menuAction(title: "Import Wallpaper…", systemImage: "square.and.arrow.down") {
                    openWindow(id: "import")
                }

                menuAction(title: "Settings…", systemImage: "gearshape") {
                    openWindow(id: "settings")
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            .padding(Metrics.spacingXS)
            .background {
                RoundedRectangle(cornerRadius: Metrics.radiusM, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
                    .overlay {
                        RoundedRectangle(cornerRadius: Metrics.radiusM, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    }
            }

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit LiveWall", systemImage: "power")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .controlSize(.regular)
            .tint(.red)
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(Metrics.spacingL)
        .frame(width: 320)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("LiveWall")
                    .font(.headline)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: engine.isPaused ? "pause.circle.fill" : "play.circle.fill")
                .font(.title2)
                .foregroundStyle(
                    engine.isPaused
                        ? AnyShapeStyle(.secondary)
                        : AnyShapeStyle(.tint)
                )
        }
    }

    private var statusText: String {
        if engine.isPaused { return "Playback paused" }
        let count = engine.activeWallpapers.count
        return count == 1 ? "1 active wallpaper" : "\(count) active wallpapers"
    }

    private var activeWallpapersSection: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingS) {
            Text("Active Wallpapers")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: Metrics.spacingXS) {
                ForEach(orderedActive, id: \.display.id) { entry in
                    activeRow(display: entry.display, wallpaper: entry.wallpaper)
                }
            }
        }
    }

    private func activeRow(display: DisplayInfo, wallpaper: Wallpaper) -> some View {
        HStack(spacing: Metrics.spacingS) {
            Image(systemName: "display")
                .foregroundStyle(.tint)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(wallpaper.title)
                    .font(.callout)
                    .lineLimit(1)
                Text(display.localizedName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, Metrics.spacingM)
        .padding(.vertical, Metrics.spacingS)
        .background {
            RoundedRectangle(cornerRadius: Metrics.radiusS, style: .continuous)
                .fill(Palette.activeGreenTint)
                .overlay {
                    RoundedRectangle(cornerRadius: Metrics.radiusS, style: .continuous)
                        .strokeBorder(Color.green.opacity(0.30), lineWidth: 1)
                }
        }
    }

    private func menuAction(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Metrics.spacingS) {
                Image(systemName: systemImage)
                    .foregroundStyle(.tint)
                    .frame(width: 18)
                Text(title)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.horizontal, Metrics.spacingS)
            .padding(.vertical, Metrics.spacingS)
        }
        .buttonStyle(.plain)
    }
}
