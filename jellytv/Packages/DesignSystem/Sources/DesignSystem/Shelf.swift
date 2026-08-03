import SwiftUI
import JellyfinAPI

public struct Shelf<Item: Identifiable & Sendable>: View {
    let title: String
    let items: [Item]
    let itemTitle: (Item) -> String
    let imageURL: (Item) -> URL?
    let onItemTap: (Item) -> Void
    private var focusedValue: ((Item) -> BaseItemDto?)?

    public init(
        title: String,
        items: [Item],
        itemTitle: @escaping (Item) -> String,
        imageURL: @escaping (Item) -> URL?,
        onItemTap: @escaping (Item) -> Void
    ) {
        self.title = title
        self.items = items
        self.itemTitle = itemTitle
        self.imageURL = imageURL
        self.onItemTap = onItemTap
    }

    public func focusedValue(_ provider: @escaping (Item) -> BaseItemDto?) -> Self {
        var copy = self
        copy.focusedValue = provider
        return copy
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.horizontal, 40)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 40) {
                    ForEach(items) { item in
                        if let provider = focusedValue {
                            PosterCard(
                                item: item,
                                title: itemTitle(item),
                                imageURL: imageURL(item)
                            ) {
                                onItemTap(item)
                            }
                            .focusedValue(provider)
                        } else {
                            PosterCard(
                                item: item,
                                title: itemTitle(item),
                                imageURL: imageURL(item)
                            ) {
                                onItemTap(item)
                            }
                        }
                    }
                }
                .scrollClipDisabled()
            }
            .scrollClipDisabled()
        }
        .focusSection()
    }
}