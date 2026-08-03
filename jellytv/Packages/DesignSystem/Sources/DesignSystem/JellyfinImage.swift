import Foundation
import JellyfinAPI

public enum JellyfinImage {
    public static func url(
        serverURL: URL,
        itemId: String,
        type: ImageType,
        tag: String?,
        maxWidth: Int? = nil,
        maxHeight: Int? = nil
    ) -> URL? {
        var components = URLComponents(
            url: serverURL.appendingPathComponent("Items/\(itemId)/Images/\(type.rawValue)"),
            resolvingAgainstBaseURL: false
        )

        var queryItems: [URLQueryItem] = []
        if let tag = tag {
            queryItems.append(URLQueryItem(name: "tag", value: tag))
        }
        if let maxWidth = maxWidth {
            queryItems.append(URLQueryItem(name: "maxWidth", value: String(maxWidth)))
        }
        if let maxHeight = maxHeight {
            queryItems.append(URLQueryItem(name: "maxHeight", value: String(maxHeight)))
        }
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        return components?.url
    }

    public enum ImageType: String, Sendable {
        case primary = "Primary"
        case backdrop = "Backdrop"
        case thumb = "Thumb"
        case logo = "Logo"
        case art = "Art"
    }
}

public extension BaseItemDto {
    func imageURL(
        serverURL: URL,
        type: JellyfinImage.ImageType,
        maxWidth: Int? = nil
    ) -> URL? {
        let tag: String?
        switch type {
        case .primary:
            tag = imageTags?["Primary"]
        case .backdrop:
            tag = backdropImageTags?.first
        case .thumb:
            tag = imageTags?["Thumb"]
        case .logo:
            tag = imageTags?["Logo"]
        case .art:
            tag = imageTags?["Art"]
        }
        guard let tag = tag else { return nil }
        return JellyfinImage.url(
            serverURL: serverURL,
            itemId: id,
            type: type,
            tag: tag,
            maxWidth: maxWidth
        )
    }
}

public extension LiveTvChannel {
    /// Channel logo URL. Falls back through Logo → Primary → Thumb tags so we
    /// surface whatever image the tuner / listings provider supplied.
    func logoURL(serverURL: URL, maxWidth: Int? = 320) -> URL? {
        if let tag = imageTags?["Logo"] {
            return JellyfinImage.url(
                serverURL: serverURL,
                itemId: id,
                type: .logo,
                tag: tag,
                maxWidth: maxWidth
            )
        }
        if let tag = imageTags?["Primary"] {
            return JellyfinImage.url(
                serverURL: serverURL,
                itemId: id,
                type: .primary,
                tag: tag,
                maxWidth: maxWidth
            )
        }
        if let tag = imageTags?["Thumb"] {
            return JellyfinImage.url(
                serverURL: serverURL,
                itemId: id,
                type: .thumb,
                tag: tag,
                maxWidth: maxWidth
            )
        }
        return nil
    }
}

public extension LiveTvProgram {
    /// Backdrop / thumbnail URL for a program. Prefers `Thumb` (typical
    /// landscape EPG art), falls back to `Primary`, then to the channel's
    /// Primary tag (Jellyfin populates `ChannelPrimaryImageTag` on programs
    /// when the program itself has no art).
    func tileImageURL(serverURL: URL, maxWidth: Int? = 600) -> URL? {
        if let tag = imageTags?["Thumb"] {
            return JellyfinImage.url(
                serverURL: serverURL,
                itemId: id,
                type: .thumb,
                tag: tag,
                maxWidth: maxWidth
            )
        }
        if let tag = imageTags?["Primary"] {
            return JellyfinImage.url(
                serverURL: serverURL,
                itemId: id,
                type: .primary,
                tag: tag,
                maxWidth: maxWidth
            )
        }
        if let channelId, let tag = channelPrimaryImageTag {
            return JellyfinImage.url(
                serverURL: serverURL,
                itemId: channelId,
                type: .primary,
                tag: tag,
                maxWidth: maxWidth
            )
        }
        return nil
    }

    func backdropURL(serverURL: URL, maxWidth: Int? = 1920) -> URL? {
        if let tag = imageTags?["Backdrop"] {
            return JellyfinImage.url(
                serverURL: serverURL,
                itemId: id,
                type: .backdrop,
                tag: tag,
                maxWidth: maxWidth
            )
        }
        return tileImageURL(serverURL: serverURL, maxWidth: maxWidth)
    }
}