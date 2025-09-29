public struct RequesterInfo: Sendable, Codable {
    public let id: String
    public let name: String?
    public let email: String?

    public init(id: String, name: String? = nil, email: String? = nil) {
        self.id = id
        self.name = name
        self.email = email
    }
}
