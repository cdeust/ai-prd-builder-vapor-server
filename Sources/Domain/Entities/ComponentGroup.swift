import Foundation

public struct ComponentGroup: Sendable, Codable, Equatable {
    public let name: String
    public let components: [String]
    public let purpose: String?

    public init(name: String, components: [String], purpose: String?) {
        self.name = name
        self.components = components
        self.purpose = purpose
    }
}
