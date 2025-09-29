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

/// DTO for architectural conflicts
public struct ArchitecturalConflictDTO: Content {
    public let requirement1: String
    public let requirement2: String
    public let conflictReason: String
    public let severity: String
    public let resolution: String

    public init(
        requirement1: String,
        requirement2: String,
        conflictReason: String,
        severity: String,
        resolution: String
    ) {
        self.requirement1 = requirement1
        self.requirement2 = requirement2
        self.conflictReason = conflictReason
        self.severity = severity
        self.resolution = resolution
    }
}

/// DTO for technical challenges
public struct TechnicalChallengeDTO: Content {
    public let title: String
    public let description: String
    public let priority: String
    public let category: String
    public let mitigation: String?

    public init(
        title: String,
        description: String,
        priority: String,
        category: String,
        mitigation: String? = nil
    ) {
        self.title = title
        self.description = description
        self.priority = priority
        self.category = category
        self.mitigation = mitigation
    }
}
