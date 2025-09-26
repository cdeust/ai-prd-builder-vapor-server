import Foundation

public struct ExportMetadata {
    public let exportedAt: Date
    public let version: String

    public init(exportedAt: Date, version: String) {
        self.exportedAt = exportedAt
        self.version = version
    }
}