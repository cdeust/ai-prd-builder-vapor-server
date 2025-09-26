import Foundation

public struct RequirementsAnalysis {
    public let confidence: Double
    public let clarificationsNeeded: [String]
    public let assumptions: [String]
    public let gaps: [String]

    public init(
        confidence: Double,
        clarificationsNeeded: [String],
        assumptions: [String],
        gaps: [String]
    ) {
        self.confidence = confidence
        self.clarificationsNeeded = clarificationsNeeded
        self.assumptions = assumptions
        self.gaps = gaps
    }
}