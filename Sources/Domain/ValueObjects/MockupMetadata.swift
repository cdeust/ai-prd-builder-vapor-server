import Foundation

public struct MockupMetadata: Equatable, Sendable, Codable {
    public let fileName: String?
    public let fileSize: Int?
    public let mimeType: String?
    public let uploadedAt: Date?
    public let description: String?

    public init(
        fileName: String? = nil,
        fileSize: Int? = nil,
        mimeType: String? = nil,
        uploadedAt: Date? = nil,
        description: String? = nil
    ) {
        self.fileName = fileName
        self.fileSize = fileSize
        self.mimeType = mimeType
        self.uploadedAt = uploadedAt
        self.description = description
    }
}