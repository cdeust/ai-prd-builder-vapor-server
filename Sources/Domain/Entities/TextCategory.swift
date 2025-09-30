import Foundation

public enum TextCategory: String, Sendable, Codable {
    case heading
    case subheading
    case body
    case label
    case button
    case placeholder
    case error
    case other
}
