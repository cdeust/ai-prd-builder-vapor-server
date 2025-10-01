import Foundation
import Vapor

/// DTO for professional analysis results
public struct ProfessionalAnalysisDTO: Content {
    public let hasCriticalIssues: Bool
    public let executiveSummary: String
    public let conflictCount: Int
    public let challengeCount: Int
    public let complexityScore: Int?
    public let blockingIssues: [String]
    public let conflicts: [ArchitecturalConflictDTO]
    public let challenges: [TechnicalChallengeDTO]

    public init(
        hasCriticalIssues: Bool,
        executiveSummary: String,
        conflictCount: Int,
        challengeCount: Int,
        complexityScore: Int? = nil,
        blockingIssues: [String] = [],
        conflicts: [ArchitecturalConflictDTO] = [],
        challenges: [TechnicalChallengeDTO] = []
    ) {
        self.hasCriticalIssues = hasCriticalIssues
        self.executiveSummary = executiveSummary
        self.conflictCount = conflictCount
        self.challengeCount = challengeCount
        self.complexityScore = complexityScore
        self.blockingIssues = blockingIssues
        self.conflicts = conflicts
        self.challenges = challenges
    }
}
