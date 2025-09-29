import Foundation

/// Professional analysis of a PRD with architectural conflicts and technical challenges
public struct ProfessionalAnalysis: Sendable {
    public let hasCriticalIssues: Bool
    public let executiveSummary: String
    public let conflictCount: Int
    public let challengeCount: Int
    public let complexityScore: Int?
    public let blockingIssues: [String]
    public let conflicts: [DomainArchitecturalConflict]
    public let challenges: [DomainTechnicalChallenge]

    public init(
        hasCriticalIssues: Bool,
        executiveSummary: String,
        conflictCount: Int,
        challengeCount: Int,
        complexityScore: Int? = nil,
        blockingIssues: [String] = [],
        conflicts: [DomainArchitecturalConflict] = [],
        challenges: [DomainTechnicalChallenge] = []
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
