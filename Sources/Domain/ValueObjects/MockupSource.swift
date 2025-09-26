import Foundation

public struct MockupSource: Equatable, Sendable {
    public let type: MockupType
    public let location: String
    public let metadata: MockupMetadata?

    public var url: URL? {
        guard type == .url else { return nil }
        return URL(string: location)
    }

    public var localPath: String? {
        guard type == .filePath else { return nil }
        return location
    }

    public init(type: MockupType, location: String, metadata: MockupMetadata? = nil) throws {
        self.type = type
        self.location = location
        self.metadata = metadata

        try validate()
    }

    private func validate() throws {
        switch type {
        case .url:
            guard location.hasPrefix("http://") || location.hasPrefix("https://") else {
                throw DomainError.validation("Invalid URL format")
            }
        case .filePath:
            guard location.hasPrefix("/") || location.hasPrefix("~") else {
                throw DomainError.validation("Invalid file path")
            }
        case .base64:
            guard location.hasPrefix("data:image/") else {
                throw DomainError.validation("Invalid base64 image format")
            }
        case .s3:
            guard location.hasPrefix("s3://") else {
                throw DomainError.validation("Invalid S3 path")
            }
        }
    }
}

extension MockupSource: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case location
        case metadata
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MockupType.self, forKey: .type)
        let location = try container.decode(String.self, forKey: .location)
        let metadata = try container.decodeIfPresent(MockupMetadata.self, forKey: .metadata)

        try self.init(type: type, location: location, metadata: metadata)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(location, forKey: .location)
        try container.encodeIfPresent(metadata, forKey: .metadata)
    }
}