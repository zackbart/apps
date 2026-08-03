import SwiftUI
import UniformTypeIdentifiers

struct GalleryView: View {
    @State private var selectedWallpaper: Wallpaper?
    @State private var searchQuery = ""
    @State private var selectedTag: String = ""
    @State private var showWelcome = false
    @State private var isDropTargeted = false

    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false

    @Environment(\.openWindow) private var openWindow

    @ObservedObject private var catalog = WallpaperCatalog.shared
    @ObservedObject private var engine = WallpaperEngine.shared
    @ObservedObject private var downloadManager = DownloadManager.shared
    @ObservedObject private var displayManager = DisplayManager.shared

    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 260), spacing: Metrics.spacingXXL)
    ]

    var body: some View {
        ZStack {
            AppAmbientBackground()

            Group {
                if let selected = selectedWallpaper {
                    detailPane(for: selected)
                } else {
                    galleryPane
                }
            }
        }
        .frame(minWidth: 760, minHeight: 560)
        .sheet(isPresented: $showWelcome) {
            WelcomeSheet(onDismiss: {
                hasSeenWelcome = true
                showWelcome = false
            })
        }
        .onAppear {
            if !hasSeenWelcome {
                // Defer to next runloop so the sheet lands after the window is presented.
                DispatchQueue.main.async {
                    showWelcome = true
                }
            }
        }
    }

    // MARK: - Gallery

    private var activeWallpaperIDs: Set<String> {
        Set(engine.activeWallpapers.values.map(\.id))
    }

    private var localWallpaperCount: Int {
        catalog.allWallpapers.filter(\.isLocal).count
    }

    private var displayCount: Int {
        max(displayManager.displays.count, 1)
    }

    @ViewBuilder
    private var galleryPane: some View {
        Group {
            if filteredWallpapers.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: Metrics.spacingXXL, pinnedViews: [.sectionHeaders]) {
                        heroSection

                        if !engine.activeWallpapers.isEmpty {
                            nowPlayingSection
                        }

                        Section {
                            LazyVGrid(columns: columns, spacing: Metrics.spacingXXL) {
                                ForEach(filteredWallpapers) { wallpaper in
                                    WallpaperCardView(
                                        wallpaper: wallpaper,
                                        isActive: activeWallpaperIDs.contains(wallpaper.id),
                                        isStale: catalog.staleLocalWallpaperIDs.contains(wallpaper.id)
                                    ) {
                                        withAnimation(.spring(duration: 0.35, bounce: 0.1)) {
                                            selectedWallpaper = wallpaper
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, Metrics.spacingXL)
                            .padding(.bottom, Metrics.spacingXL)
                        } header: {
                            if !catalog.allTags.isEmpty || !searchQuery.isEmpty {
                                tagFilterStrip
                            }
                        }
                    }
                    .padding(.top, Metrics.spacingXL)
                    .padding(.bottom, Metrics.spacingXXL)
                }
            }
        }
        .searchable(
            text: $searchQuery,
            placement: .toolbar,
            prompt: "Search wallpapers"
        )
        .onDrop(of: [UTType.movie.identifier, UTType.mpeg4Movie.identifier, UTType.quickTimeMovie.identifier], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
        .overlay {
            if isDropTargeted {
                dropTargetOverlay
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Label("LiveWall", systemImage: "sparkles.tv.fill")
                    .font(.headline.weight(.semibold))
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    openWindow(id: "import")
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.glassProminent)
                .help("Import a video from your Mac — or drop one onto the window")

                Button {
                    openWindow(id: "settings")
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .buttonStyle(.glass)
                .help("Preferences and displays")
            }
        }
        .navigationTitle("LiveWall")
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingL) {
            HStack(alignment: .top, spacing: Metrics.spacingL) {
                VStack(alignment: .leading, spacing: Metrics.spacingS) {
                    Text("Make your desktop feel alive.")
                        .font(.largeTitle.weight(.bold))

                    Text("Browse the catalog, import your own loops, and send motion to every display.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: Metrics.spacingS) {
                    heroMetric(
                        value: "\(catalog.allWallpapers.count)",
                        title: "Wallpapers",
                        systemImage: "rectangle.stack.fill"
                    )
                    heroMetric(
                        value: "\(displayCount)",
                        title: displayCount == 1 ? "Display Ready" : "Displays Ready",
                        systemImage: "display.2"
                    )
                }
            }

            HStack(spacing: Metrics.spacingM) {
                Button {
                    openWindow(id: "import")
                } label: {
                    Label("Import a Video", systemImage: "square.and.arrow.down")
                        .frame(minWidth: 160)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)

                StatusPill(
                    title: activeWallpaperIDs.isEmpty ? "Ready to apply" : "\(activeWallpaperIDs.count) active",
                    systemImage: activeWallpaperIDs.isEmpty ? "sparkles" : "play.circle.fill",
                    tint: activeWallpaperIDs.isEmpty ? nil : .green
                )
                StatusPill(
                    title: "\(localWallpaperCount) imported",
                    systemImage: "folder.fill"
                )

                Spacer(minLength: 0)
            }
        }
        .padding(Metrics.spacingXXL)
        .background {
            RoundedRectangle(cornerRadius: Metrics.radiusXL, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: Metrics.radiusXL, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.accentColor.opacity(0.08),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: Metrics.radiusXL, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.06), radius: 18, x: 0, y: 10)
        }
        .padding(.horizontal, Metrics.spacingXL)
    }

    private func heroMetric(value: String, title: String, systemImage: String) -> some View {
        HStack(spacing: Metrics.spacingS) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(.tint)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.headline.weight(.semibold))
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, Metrics.spacingM)
        .padding(.vertical, Metrics.spacingS)
        .glassEffect(.regular, in: .capsule)
    }

    // MARK: - Now Playing

    private var nowPlayingSection: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingM) {
            HStack(alignment: .top, spacing: Metrics.spacingM) {
                VStack(alignment: .leading, spacing: Metrics.spacingXS) {
                    Text("Now Playing")
                        .font(.title3.weight(.semibold))

                    Text(engine.isPaused ? "Playback is paused across your desktop." : "Quick access to every live wallpaper currently running.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(engine.isPaused ? "Resume All" : "Pause All") {
                    if engine.isPaused {
                        engine.resumeAll()
                    } else {
                        engine.pauseAll()
                    }
                }
                .buttonStyle(.glass)
                .controlSize(.regular)
            }
            .padding(.horizontal, Metrics.spacingXL)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Metrics.spacingM) {
                    ForEach(orderedNowPlaying, id: \.displayID) { entry in
                        nowPlayingCard(displayID: entry.displayID, wallpaper: entry.wallpaper)
                    }
                }
                .padding(.horizontal, Metrics.spacingXL)
                .padding(.vertical, Metrics.spacingXS)
            }
            .mask {
                HStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                        .frame(width: Metrics.spacingXL)
                    Rectangle().fill(.black)
                    LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: Metrics.spacingXL)
                }
            }
        }
    }

    private var orderedNowPlaying: [(displayID: String, wallpaper: Wallpaper)] {
        let ordered = displayManager.displays.compactMap { display -> (String, Wallpaper)? in
            guard let wp = engine.activeWallpapers[display.id] else { return nil }
            return (display.id, wp)
        }
        if !ordered.isEmpty { return ordered }
        // Fallback: if displayManager hasn't populated for some reason, use sorted keys.
        return engine.activeWallpapers.keys.sorted().compactMap { key in
            engine.activeWallpapers[key].map { (key, $0) }
        }
    }

    private func nowPlayingCard(displayID: String, wallpaper: Wallpaper) -> some View {
        VStack(alignment: .leading, spacing: Metrics.spacingM) {
            Button {
                withAnimation(.spring(duration: 0.35, bounce: 0.1)) {
                    selectedWallpaper = wallpaper
                }
            } label: {
                VStack(alignment: .leading, spacing: Metrics.spacingS) {
                    HStack(spacing: Metrics.spacingS) {
                        Image(systemName: "display")
                            .font(.title3)
                            .foregroundStyle(.tint)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(displayName(for: displayID))
                                .font(.caption.weight(.semibold))
                            Text(wallpaper.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }

                    HStack(spacing: Metrics.spacingXS) {
                        StatusPill(
                            title: wallpaper.isLocal ? "Imported" : "Catalog",
                            systemImage: wallpaper.isLocal ? "folder" : "sparkles.rectangle.stack"
                        )

                        if let duration = wallpaper.duration {
                            StatusPill(
                                title: String(format: "%.0fs", duration),
                                systemImage: "clock"
                            )
                        }
                    }
                }
                .frame(width: 220, alignment: .leading)
            }
            .buttonStyle(.plain)

            HStack {
                Button {
                    engine.stop(forDisplay: displayID)
                } label: {
                    Label("Remove", systemImage: "stop.circle")
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .help("Remove wallpaper from \(displayName(for: displayID))")

                Spacer()

                Image(systemName: "waveform")
                    .font(.caption)
                    .foregroundStyle(
                        engine.isPaused
                            ? AnyShapeStyle(.secondary)
                            : AnyShapeStyle(.tint)
                    )
            }
        }
        .padding(Metrics.spacingL)
        .background {
            RoundedRectangle(cornerRadius: Metrics.radiusL, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: Metrics.radiusL, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                }
        }
    }

    private func displayName(for id: String) -> String {
        displayManager.displays.first(where: { $0.id == id })?.localizedName ?? "Display"
    }

    // MARK: - Tag strip

    private var tagFilterStrip: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingM) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(searchQuery.isEmpty ? "Filter by vibe" : "Refine your search")
                        .font(.headline)
                    Text(selectedTag.isEmpty ? "Choose a tag to tighten the gallery." : "Showing \(selectedTag.lowercased()) wallpapers.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                StatusPill(title: "\(filteredWallpapers.count) shown")
            }
            .padding(.horizontal, Metrics.spacingXL)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Metrics.spacingS) {
                    tagChip(title: "All", tag: "")
                    ForEach(catalog.allTags, id: \.self) { tag in
                        tagChip(title: tag, tag: tag)
                    }
                }
                .padding(.horizontal, Metrics.spacingXL)
                .padding(.bottom, Metrics.spacingS)
            }
        }
        .padding(.top, Metrics.spacingM)
        .background {
            Rectangle()
                .fill(.regularMaterial)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 0.5)
                }
        }
    }

    private func tagChip(title: String, tag: String) -> some View {
        let isSelected = selectedTag == tag
        return Button {
            withAnimation(.easeOut(duration: 0.15)) {
                selectedTag = tag
            }
        } label: {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, Metrics.spacingM)
                .padding(.vertical, Metrics.spacingXS + 2)
        }
        .buttonStyle(.plain)
        .glassEffect(
            isSelected ? .regular.tint(.accentColor.opacity(0.55)) : .regular,
            in: .capsule
        )
        .foregroundStyle(isSelected ? Color.white : .primary)
    }

    // MARK: - Detail

    @ViewBuilder
    private func detailPane(for wallpaper: Wallpaper) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: Metrics.spacingM) {
                Button {
                    withAnimation(.spring(duration: 0.35, bounce: 0.05)) {
                        selectedWallpaper = nil
                    }
                } label: {
                    Label("Gallery", systemImage: "chevron.left")
                }
                .buttonStyle(.glass)
                .controlSize(.regular)
                .keyboardShortcut(.cancelAction)

                Text(wallpaper.title)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                if activeWallpaperIDs.contains(wallpaper.id) {
                    StatusPill(
                        title: "Live on your desktop",
                        systemImage: "play.circle.fill",
                        tint: .green
                    )
                }
            }
            .padding(.horizontal, Metrics.spacingXL)
            .padding(.top, Metrics.spacingM)
            .padding(.bottom, Metrics.spacingS)

            WallpaperDetailView(wallpaper: wallpaper) {
                withAnimation(.spring(duration: 0.35, bounce: 0.05)) {
                    selectedWallpaper = nil
                }
            }
        }
    }

    // MARK: - Data

    private var filteredWallpapers: [Wallpaper] {
        var results = catalog.allWallpapers

        if !searchQuery.isEmpty {
            results = catalog.search(query: searchQuery)
        }

        if !selectedTag.isEmpty {
            results = results.filter { $0.tags.contains(selectedTag) }
        }

        return results
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label(
                searchQuery.isEmpty ? "Start Your Collection" : "No Matches",
                systemImage: searchQuery.isEmpty ? "sparkles.rectangle.stack" : "magnifyingglass"
            )
        } description: {
            Text(searchQuery.isEmpty
                 ? "Import a video from your Mac, or drop an MP4 or MOV onto this window."
                 : "Try a different search term or clear the active tag filter.")
        } actions: {
            if searchQuery.isEmpty {
                Button {
                    openWindow(id: "import")
                } label: {
                    Label("Import Wallpaper", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Metrics.spacingXXL)
    }

    // MARK: - Drop target overlay

    private var dropTargetOverlay: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)

            Rectangle()
                .fill(Color.accentColor.opacity(0.18))

            VStack(spacing: Metrics.spacingM) {
                Image(systemName: "square.and.arrow.down.on.square.fill")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(.tint)

                Text("Drop to Import")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("MP4 or MOV")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(Metrics.spacingXXL)
            .background {
                RoundedRectangle(cornerRadius: Metrics.radiusL, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: Metrics.radiusL, style: .continuous)
                            .strokeBorder(Color.accentColor.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    // MARK: - Drop handler

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else {
            AppErrorPresenter.report(
                title: "Couldn't Import",
                message: "No file was dropped.",
                recoverySuggestion: "Try dragging the video file again."
            )
            return false
        }

        let targetTypes = [UTType.quickTimeMovie.identifier, UTType.mpeg4Movie.identifier, UTType.movie.identifier]
        guard let matchingType = targetTypes.first(where: { provider.hasItemConformingToTypeIdentifier($0) }) else {
            AppErrorPresenter.report(
                title: "Unsupported File",
                message: "That file isn't a supported video format.",
                recoverySuggestion: "Drop an MP4 or MOV file."
            )
            return false
        }

        provider.loadItem(forTypeIdentifier: matchingType, options: nil) { item, error in
            if let error = error {
                AppErrorPresenter.report(
                    title: "Couldn't Import",
                    message: error.localizedDescription,
                    recoverySuggestion: "Try dragging the file again."
                )
                return
            }

            var url: URL?
            if let directURL = item as? URL {
                url = directURL
            } else if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            }

            guard let fileURL = url else {
                AppErrorPresenter.report(
                    title: "Couldn't Import",
                    message: "Couldn't read the dropped file's location.",
                    recoverySuggestion: "Try importing via the toolbar button instead."
                )
                return
            }

            Task { @MainActor in
                // catalog.addLocalWallpaper surfaces its own errors via the presenter on failure.
                if let wallpaper = await catalog.addLocalWallpaper(fileURL: fileURL) {
                    engine.apply(wallpaper, scope: .allDisplays)
                }
            }
        }

        return true
    }
}
