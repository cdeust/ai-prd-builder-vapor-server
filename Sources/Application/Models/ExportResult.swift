import Foundation
import Domain

/// Result model for document export
public struct ExportResult {
    public let format: DocumentFormat
    public let content: String
    public let filename: String
    public let mimeType: String

    public init(format: DocumentFormat, content: String, filename: String, mimeType: String) {
        self.format = format
        self.content = content
        self.filename = filename
        self.mimeType = mimeType
    }
}