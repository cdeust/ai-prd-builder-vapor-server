import Foundation

public struct ProviderStatus {
    public let name: String
    public let isAvailable: Bool
    public let priority: Int
    public let capabilities: [String]
    public let lastUsed: Date?

    public init(
        name: String,
        isAvailable: Bool,
        priority: Int,
        capabilities: [String],
        lastUsed: Date? = nil
    ) {
        self.name = name
        self.isAvailable = isAvailable
        self.priority = priority
        self.capabilities = capabilities
        self.lastUsed = lastUsed
    }
}