import Foundation

public struct ExportedDocument {
    public let content: String
    public let format: String
    public let metadata: ExportMetadata

    public init(content: String, format: String, metadata: ExportMetadata) {
        self.content = content
        self.format = format
        self.metadata = metadata
    }
}