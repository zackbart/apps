import SwiftUI
import AVKit

struct WallpaperDetailView: View {
    let wallpaper: Wallpaper
    var onRequestClose: (() -> Void)? = nil

    @ObservedObject private var engine = WallpaperEngine.shared
    @ObservedObject private var downloadManager = DownloadManager.shared
    @ObservedObject private var catalog = WallpaperCatalog.shared
    @ObservedObject private var displayManager = DisplayManager.shared

    private var isStale: Bool {
        catalog.staleLocalWallpaperIDs.contains(wallpaper.id)
    }

    private var previewURL: URL? {
        if let local = wallpaper.localFileURL {
            return local
        }
        return downloadManager.localURL(for: wallpaper.id)
    }

    private var activeDisplayCount: Int {
        engine.activeWallpapers.values.filter { $0.id == wallpaper.id }.count
    }

    private var wallpaperSummary: String {
        if isStale {
            return "The source file is missing, so this entry can no longer be played."
        }
        if wallpaper.isLocal {
            return "Imported from your Mac and ready to apply anywhere."
        }
        if previewURL != nil {
            return "Cached locally for instant preview and faster applying."
        }
        return "Preview becomes fully interactive after the first download."
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.spacingXXL) {
                heroPreview

                summaryPanel

                if isStale {
                    staleNotice
                } else {
                    displayPicker
                }
            }
            .padding(Metrics.spacingXXL)
        }
        .frame(minWidth: 440, minHeight: 520)
    }

    private var summaryPanel: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingL) {
            HStack(alignment: .top, spacing: Metrics.spacingL) {
                VStack(alignment: .leading, spacing: Metrics.spacingS) {
                    Text(wallpaper.title)
                        .font(.largeTitle.weight(.bold))

                    Text(wallpaperSummary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                if activeDisplayCount > 0 {
                    StatusPill(
                        title: "\(activeDisplayCount) active",
                        systemImage: "play.circle.fill",
                        tint: .green
                    )
                }
            }

            HStack(spacing: Metrics.spacingS) {
                StatusPill(title: wallpaper.resolution.rawValue, systemImage: "display")
                if let duration = wallpaper.duration {
                    StatusPill(title: String(format: "%.0fs loop", duration), systemImage: "clock")
                }
                StatusPill(
                    title: wallpaper.isLocal ? "Imported" : (previewURL != nil ? "Cached" : "Download on apply"),
                    systemImage: wallpaper.isLocal ? "folder.fill" : "arrow.down.circle"
                )
            }

            if !wallpaper.tags.isEmpty {
                FlowLayout(spacing: Metrics.spacingS) {
                    ForEach(wallpaper.tags, id: \.self) { tag in
                        StatusPill(title: tag)
                    }
                }
            }
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

    // MARK: - Stale notice

    private var staleNotice: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingM) {
            Label {
                VStack(alignment: .leading, spacing: Metrics.spacingXS) {
                    Text("File is missing")
                        .font(.headline)
                    Text("This wallpaper was moved or deleted from your Mac since you imported it. You can remove the entry from your library.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
            }
            .padding(Metrics.spacingL)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Metrics.radiusM, style: .continuous)
                    .fill(Color.orange.opacity(0.12))
                    .overlay {
                        RoundedRectangle(cornerRadius: Metrics.radiusM, style: .continuous)
                            .strokeBorder(Color.orange.opacity(0.25), lineWidth: 1)
                    }
            }

            HStack {
                Spacer()
                Button {
                    catalog.removeLocalWallpaper(wallpaper)
                    onRequestClose?()
                } label: {
                    Label("Remove Missing Entry", systemImage: "trash")
                }
                .buttonStyle(.glassProminent)
                .controlSize(.regular)
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    // MARK: - Hero preview

    @ViewBuilder
    private var heroPreview: some View {
        if let url = previewURL {
            VideoPreviewPlayer(
                wallpaperID: "detail-\(wallpaper.id)",
                url: url,
                isPlaying: true
            )
            .frame(maxWidth: .infinity)
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.radiusM, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                Label("Live preview", systemImage: "dot.radiowaves.left.and.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Metrics.spacingS)
                    .padding(.vertical, 5)
                    .glassEffect(.regular.tint(.black.opacity(0.45)), in: .capsule)
                    .padding(Metrics.spacingM)
            }
            .overlay(alignment: .topLeading) {
                StatusPill(
                    title: wallpaper.isLocal ? "Imported" : "Catalog",
                    systemImage: wallpaper.isLocal ? "folder.fill" : "sparkles.rectangle.stack.fill"
                )
                .padding(Metrics.spacingM)
            }
        } else {
            staticHero
        }
    }

    private var heroPlaceholder: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                Image(systemName: "film.stack")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(.tertiary)
            }
    }

    @ViewBuilder
    private var staticHero: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.radiusM, style: .continuous)

        ZStack {
            if let thumbnailURL = wallpaper.thumbnailURL, let url = URL(string: thumbnailURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .empty, .failure:
                        heroPlaceholder
                    @unknown default:
                        heroPlaceholder
                    }
                }
            } else {
                heroPlaceholder
            }

            if downloadManager.downloads[wallpaper.id]?.isActive == true {
                Color.black.opacity(0.35)
                if let fraction = downloadManager.downloads[wallpaper.id]?.progressFraction {
                    ProgressView(value: fraction) {
                        Text("Downloading preview…")
                            .foregroundStyle(.white)
                    }
                    .progressViewStyle(.linear)
                    .tint(.white)
                    .frame(maxWidth: 220)
                    .padding(.horizontal, 24)
                } else {
                    ProgressView("Downloading preview…")
                        .controlSize(.regular)
                        .foregroundStyle(.white)
                }
            } else {
                Label("Preview unlocks after Apply", systemImage: "play.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Metrics.spacingM)
                    .padding(.vertical, 6)
                    .glassEffect(.regular.tint(.black.opacity(0.5)), in: .capsule)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 240)
        .clipShape(shape)
    }

    // MARK: - Display picker

    private var displayPicker: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingM) {
            HStack {
                VStack(alignment: .leading, spacing: Metrics.spacingXS) {
                    Text("Apply to Display")
                        .font(.headline)
                    Text("Choose where this wallpaper should play right now.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    applyToAllDisplays()
                } label: {
                    Label("Apply to All", systemImage: "rectangle.on.rectangle")
                }
                .buttonStyle(.glassProminent)
                .controlSize(.regular)
                .keyboardShortcut(.defaultAction)
                .disabled(isAnyDownloadInFlight)
            }

            if displayManager.displays.isEmpty {
                ContentUnavailableView(
                    "No Displays Detected",
                    systemImage: "display.trianglebadge.exclamationmark",
                    description: Text("Connect a display and try again.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, Metrics.spacingL)
            } else {
                VStack(spacing: Metrics.spacingS) {
                    ForEach(displayManager.displays) { display in
                        displayRow(display)
                    }
                }
            }
        }
    }

    private var isAnyDownloadInFlight: Bool {
        downloadManager.downloads[wallpaper.id]?.isActive == true
    }

    private func displayRow(_ display: DisplayInfo) -> some View {
        let isActive = engine.activeWallpapers[display.id]?.id == wallpaper.id
        let otherActive = engine.activeWallpapers[display.id]
        let downloadState = downloadManager.downloads[wallpaper.id]

        return HStack(spacing: Metrics.spacingM) {
            Image(systemName: "display")
                .font(.title3)
                .foregroundStyle(
                    isActive
                        ? AnyShapeStyle(.tint)
                        : AnyShapeStyle(.secondary)
                )
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(display.localizedName)
                    .font(.callout.weight(.medium))
                Text(String(format: "%.0f × %.0f", display.resolution.width, display.resolution.height))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: Metrics.spacingXS) {
                if isActive {
                    Label("Currently Live", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                } else if let other = otherActive, other.id != wallpaper.id {
                    Text(other.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 120, alignment: .trailing)
                }

                applyButton(for: display, isActive: isActive, state: downloadState)
            }
        }
        .padding(Metrics.spacingL)
        .background {
            RoundedRectangle(cornerRadius: Metrics.radiusM, style: .continuous)
                .fill(isActive ? Palette.activeGreenTint : Color.primary.opacity(0.04))
                .overlay {
                    RoundedRectangle(cornerRadius: Metrics.radiusM, style: .continuous)
                        .strokeBorder(
                            isActive ? Color.green.opacity(0.35) : Color.primary.opacity(0.08),
                            lineWidth: 1
                        )
                }
        }
    }

    @ViewBuilder
    private func applyButton(for display: DisplayInfo, isActive: Bool, state: DownloadState?) -> some View {
        switch state {
        case .downloading(let fraction):
            VStack(alignment: .trailing, spacing: 2) {
                Text("Downloading…")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                ProgressView(value: fraction)
                    .progressViewStyle(.linear)
                    .controlSize(.small)
                    .frame(minWidth: 84)
            }
        case .failed(let message):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help(message)
                Button("Retry") {
                    applyToDisplay(display.id)
                }
                .buttonStyle(.glass)
            }
        default:
            if isActive {
                Button {
                    engine.stop(forDisplay: display.id)
                } label: {
                    Label("Remove", systemImage: "stop.circle")
                        .frame(minWidth: 72)
                }
                .buttonStyle(.glass)
            } else {
                Button {
                    applyToDisplay(display.id)
                } label: {
                    Text("Apply")
                        .frame(minWidth: 72)
                }
                .buttonStyle(.glassProminent)
            }
        }
    }

    // MARK: - Actions

    private func applyToAllDisplays() {
        let wp = wallpaper
        Task {
            if !wp.isLocal {
                await downloadManager.download(wallpaper: wp)
            }
            engine.apply(wp, scope: .allDisplays)
        }
    }

    private func applyToDisplay(_ displayID: String) {
        let wp = wallpaper
        Task {
            if !wp.isLocal {
                await downloadManager.download(wallpaper: wp)
            }
            engine.setWallpaper(wp, forDisplay: displayID)
        }
    }
}

// MARK: - FlowLayout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                anchor: .topLeading,
                proposal: .unspecified
            )
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxLineWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                maxLineWidth = max(maxLineWidth, currentX - spacing)
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        maxLineWidth = max(maxLineWidth, currentX - spacing)
        let totalHeight = currentY + lineHeight
        return (CGSize(width: maxLineWidth, height: totalHeight), positions)
    }
}
