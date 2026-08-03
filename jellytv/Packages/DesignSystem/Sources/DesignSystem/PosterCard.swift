import SwiftUI
import Nuke
import NukeUI
import JellyfinAPI

public struct PosterCard<Item: Identifiable & Sendable>: View {
    let item: Item
    let title: String
    let imageURL: URL?
    public let action: () -> Void
    private var focusedValue: ((Item) -> BaseItemDto?)?

    @FocusState private var isFocused: Bool

    public init(
        item: Item,
        title: String,
        imageURL: URL?,
        action: @escaping () -> Void
    ) {
        self.item = item
        self.title = title
        self.imageURL = imageURL
        self.action = action
    }

    public func focusedValue(_ provider: @escaping (Item) -> BaseItemDto?) -> Self {
        var copy = self
        copy.focusedValue = provider
        return copy
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: action) {
                Group {
                    if let url = imageURL {
                        LazyImage(url: url) { state in
                            if let image = state.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                placeholderView
                            }
                        }
                    } else {
                        placeholderView
                    }
                }
                .aspectRatio(2/3, contentMode: .fit)
                .frame(width: 240)
            }
            #if os(tvOS)
            .buttonStyle(.card)
            #else
            .buttonStyle(.plain)
            #endif
            .focused($isFocused)
            .focusedValue(\.focusedHomeItem, isFocused ? focusedValue?(item) : nil)

            Text(title)
                .font(.subheadline)
                .lineLimit(1)
                .foregroundStyle(isFocused ? .primary : .secondary)
                .frame(width: 240, alignment: .leading)
        }
    }

    private var placeholderView: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.2))
            .overlay {
                Image(systemName: "film")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
            }
    }
}