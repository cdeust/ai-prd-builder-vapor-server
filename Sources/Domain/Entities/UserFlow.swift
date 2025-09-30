import Foundation

public struct UserFlow: Sendable, Codable, Equatable {
    public let flowName: String
    public let steps: [String]
    public let confidence: Double

    public init(flowName: String, steps: [String], confidence: Double) {
        self.flowName = flowName
        self.steps = steps
        self.confidence = confidence
    }
}
