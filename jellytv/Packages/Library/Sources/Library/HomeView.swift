import SwiftUI
import JellyfinAPI
import DesignSystem

public struct HomeView: View {
    @Bindable var model: HomeModel
    @FocusedValue(\.focusedHomeItem) private var focusedItem

    public init(model: HomeModel) {
        self.model = model
    }

    public var body: some View {
        Group {
            switch model.state {
            case .loading:
                ProgressView()
                    .controlSize(.large)
            case .loaded(let content):
                homeContent(content)
            case .failed(let message):
                failedView(message)
            }
        }
        .task {
            await model.load()
        }
    }

    @ViewBuilder
    private func homeContent(_ content: HomeContent) -> some View {
        let displayedHeroItem = focusedItem ?? content.heroItem
        if content.isEmpty {
            emptyState(libraryCount: content.libraries.count)
        } else {
            loadedScroll(content: content, displayedHeroItem: displayedHeroItem)
        }
    }

    private func emptyState(libraryCount: Int) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "film.stack")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)
            Text("Nothing to show yet")
                .font(.title)
            Text(libraryCount == 0
                 ? "Your server has no libraries."
                 : "Your libraries are empty, or have no recently added items.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Reload") {
                Task { await model.load() }
            }
        }
        .padding(60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func loadedScroll(content: HomeContent, displayedHeroItem: BaseItemDto?) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 60) {
                if let heroItem = displayedHeroItem {
                    HeroSection(
                        item: heroItem,
                        serverURL: content.serverURL,
                        onPlay: { /* Phase 4: play */ },
                        onDetail: { /* Phase 3: detail */ }
                    )
                }

                if !content.resumeItems.isEmpty {
                    Shelf(
                        title: "Continue Watching",
                        items: content.resumeItems,
                        itemTitle: { $0.name },
                        imageURL: { $0.imageURL(serverURL: content.serverURL, type: .primary, maxWidth: 300) }
                    ) { item in
                        print("Resume: \(item.name)")
                    }
                    .focusedValue { $0 }
                }

                if !content.nextUp.isEmpty {
                    Shelf(
                        title: "Next Up",
                        items: content.nextUp,
                        itemTitle: { $0.name },
                        imageURL: { $0.imageURL(serverURL: content.serverURL, type: .primary, maxWidth: 300) }
                    ) { item in
                        print("Next Up: \(item.name)")
                    }
                    .focusedValue { $0 }
                }

                ForEach(content.libraries, id: \.id) { library in
                    if let latestItems = content.latestPerLibrary[library.id], !latestItems.isEmpty {
                        Shelf(
                            title: library.name,
                            items: latestItems,
                            itemTitle: { $0.name },
                            imageURL: { $0.imageURL(serverURL: content.serverURL, type: .primary, maxWidth: 300) }
                        ) { item in
                            print("Latest: \(item.name)")
                        }
                        .focusedValue { $0 }
                    }
                }
            }
            .scrollTargetLayout()
        }
        .scrollClipDisabled()
        .scrollTargetBehavior(.viewAligned)
    }

    private func failedView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.title2)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await model.load() }
            }
            .buttonStyle(.bordered)
        }
        .padding(40)
    }
}

extension HomeContent {
    var heroItem: BaseItemDto? {
        if let first = resumeItems.first {
            return first
        }
        if let first = nextUp.first {
            return first
        }
        return nil
    }

    var isEmpty: Bool {
        resumeItems.isEmpty && nextUp.isEmpty && latestPerLibrary.values.allSatisfy(\.isEmpty)
    }
}