import Foundation
import Domain
import CommonModels
import DomainCore
import PRDGenerator

/// Converts professional analysis from library components to server domain models
struct ProfessionalAnalysisConverter {

    /// Generate professional analysis using library's analyzers
    func generateProfessionalAnalysis(
        from document: CommonModels.PRDocument,
        provider: CommonModels.AIProvider
    ) async throws -> (conflicts: [Domain.DomainArchitecturalConflict], challenges: [Domain.DomainTechnicalChallenge]) {

        // Extract requirements text from document
        let requirementsText = document.sections
            .filter { section in
                section.title.lowercased().contains("requirement") ||
                section.title.lowercased().contains("functional") ||
                section.title.lowercased().contains("technical")
            }
            .map { $0.content }
            .joined(separator: "\n\n")

        // Use library's ConflictAnalyzer
        let conflictAnalyzer = ConflictAnalyzer(provider: provider)
        let libraryConflicts = try await conflictAnalyzer.analyze(requirementsText)

        // Use library's ChallengePredictor
        let challengePredictor = ChallengePredictor(provider: provider)
        let libraryChallenges = try await challengePredictor.predictChallenges(from: requirementsText)

        // Convert to domain models
        let conflicts = libraryConflicts.map { conflict in
            Domain.DomainArchitecturalConflict(
                requirement1: conflict.requirement1,
                requirement2: conflict.requirement2,
                conflictReason: conflict.resolution.recommendation,
                severity: mapConflictSeverity(conflict.severity),
                resolution: conflict.resolution.approach
            )
        }

        let challenges = libraryChallenges.map { challenge in
            Domain.DomainTechnicalChallenge(
                title: challenge.title,
                description: challenge.description,
                priority: mapChallengePriority(challenge.priority),
                category: challenge.category.rawValue,
                mitigation: challenge.preventiveMeasures.first?.action
            )
        }

        return (conflicts, challenges)
    }

    // MARK: - Helper mapping functions

    private func mapConflictSeverity(_ severity: ArchitecturalConflict.Severity) -> Domain.DomainArchitecturalConflict.Severity {
        switch severity {
        case .critical: return .critical
        case .high: return .high
        case .medium: return .medium
        case .low: return .low
        }
    }

    private func mapChallengePriority(_ priority: TechnicalChallenge.Priority) -> Domain.DomainTechnicalChallenge.Priority {
        switch priority {
        case .critical: return .critical
        case .high: return .high
        case .medium: return .medium
        case .low: return .low
        }
    }
}
