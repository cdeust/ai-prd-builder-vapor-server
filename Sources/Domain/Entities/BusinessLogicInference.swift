import Foundation

public struct BusinessLogicInference: Sendable, Codable, Equatable {
    public let feature: String
    public let description: String
    public let confidence: Double
    public let requiredComponents: [String]

    public init(feature: String, description: String, confidence: Double, requiredComponents: [String]) {
        self.feature = feature
        self.description = description
        self.confidence = confidence
        self.requiredComponents = requiredComponents
    }
}
