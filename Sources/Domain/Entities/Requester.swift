import Foundation

public struct Requester: Sendable {
    public let id: String
    public let email: String?
    public let organizationId: String?

    public init(id: String, email: String? = nil, organizationId: String? = nil) {
        self.id = id
        self.email = email
        self.organizationId = organizationId
    }
}
