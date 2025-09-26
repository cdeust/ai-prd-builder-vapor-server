import Foundation

public enum MockupType: String, CaseIterable, Equatable, Sendable, Codable {
    case url
    case filePath
    case base64
    case s3
}