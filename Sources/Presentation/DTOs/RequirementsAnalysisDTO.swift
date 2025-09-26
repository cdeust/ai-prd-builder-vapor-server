import Foundation
import Vapor
import Domain

/// DTO for requirements analysis responses
public struct RequirementsAnalysisDTO: Content {
    public let confidence: Int
    public let clarificationsNeeded: [String]
    public let assumptions: [String]
    public let gaps: [String]

    public init(
        confidence: Int,
        clarificationsNeeded: [String],
        assumptions: [String],
        gaps: [String]
    ) {
        self.confidence = confidence
        self.clarificationsNeeded = clarificationsNeeded
        self.assumptions = assumptions
        self.gaps = gaps
    }

    static func from(_ analysis: RequirementsAnalysis) -> RequirementsAnalysisDTO {
        return RequirementsAnalysisDTO(
            confidence: Int(analysis.confidence * 100),
            clarificationsNeeded: analysis.clarificationsNeeded,
            assumptions: analysis.assumptions,
            gaps: analysis.gaps
        )
    }
}