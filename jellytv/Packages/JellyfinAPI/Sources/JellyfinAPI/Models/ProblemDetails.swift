// RFC 7807 error envelope returned by Jellyfin for 4xx responses.
// Wire keys are lowercase — no CodingKeys needed since Swift property names match.
public struct ProblemDetails: Decodable, Sendable, Equatable {
    public let type: String?
    public let title: String?
    public let status: Int?
    public let detail: String?
    public let instance: String?

    public init(
        type: String? = nil,
        title: String? = nil,
        status: Int? = nil,
        detail: String? = nil,
        instance: String? = nil
    ) {
        self.type = type
        self.title = title
        self.status = status
        self.detail = detail
        self.instance = instance
    }
}
