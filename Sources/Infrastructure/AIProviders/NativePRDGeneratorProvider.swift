import Foundation
import Domain
import PRDGenerator
import CommonModels
import DomainCore
import ThinkingCore
import Orchestration

public final class NativePRDGeneratorProvider: AIProviderPort {
    private let coordinator: AIProviderCoordinator
    private var prdGenerator: PRDGenerator?
    private let analysisConverter = ProfessionalAnalysisConverter()
    private var lastEnrichedRequirements: EnrichedRequirements?

    public var name: String { "Native PRD Generator" }
    public var priority: Int { 100 }
    public var isAvailable: Bool {
        get async { true }
    }

    public init() {
        self.coordinator = AIProviderCoordinator()
    }

    public func generatePRD(from command: GeneratePRDCommand) async throws -> PRDGenerationResult {
        guard let provider = getFirstAvailableProvider() else {
            throw DomainError.processingFailed("No AI provider available for PRD generation")
        }

        let config = DomainCore.Configuration(
            debugMode: true,
            enableClarificationPrompts: false,
            enableProfessionalAnalysis: true, // Enable professional analysis
            detectArchitecturalConflicts: true,
            predictTechnicalChallenges: true,
            analyzeComplexity: true,
            identifyScalingBreakpoints: true,
            showCriticalDecisions: true
        )

        let generator = PRDGenerator(
            provider: provider,
            configuration: config,
            interactionHandler: NonInteractiveHandler()
        )

        self.prdGenerator = generator

        let document = try await generator.generatePRD(from: command.description)

        return try await mapToDomainResult(document)
    }

    public func analyzeRequirements(_ text: String) async throws -> Domain.RequirementsAnalysis {
        guard let provider = getFirstAvailableProvider() else {
            throw DomainError.processingFailed("No AI provider available")
        }

        let analyzer = RequirementsAnalyzer(
            provider: provider,
            interactionHandler: NonInteractiveHandler(),
            configuration: DomainCore.Configuration(
                enableProfessionalAnalysis: true,
                detectArchitecturalConflicts: true,
                predictTechnicalChallenges: true
            )
        )

        let enriched = try await analyzer.analyzeAndClarify(input: text)

        // Store for later use in professional analysis extraction
        self.lastEnrichedRequirements = enriched

        let clarifications = Array(enriched.clarifications.keys)

        return Domain.RequirementsAnalysis(
            confidence: Double(enriched.initialConfidence),
            clarificationsNeeded: clarifications,
            assumptions: enriched.assumptions,
            gaps: enriched.gaps
        )
    }

    public func extractFromMockups(_ sources: [Domain.MockupSource]) async throws -> Domain.MockupAnalysis {
        return Domain.MockupAnalysis(
            extractedFeatures: [],
            userFlows: [],
            uiComponents: [],
            businessLogic: []
        )
    }

    private func getFirstAvailableProvider() -> CommonModels.AIProvider? {
        return coordinator.getCurrentProvider()
    }

    private func mapToDomainResult(_ document: CommonModels.PRDocument) async throws -> PRDGenerationResult {
        var sections = document.sections.map { section in
            Domain.GeneratedSection(
                title: section.title,
                content: section.content,
                type: mapSectionType(section.title)
            )
        }

        var domainProfessionalAnalysis: Domain.ProfessionalAnalysis?

        if let analysis = document.professionalAnalysis {
            // Use AI to detect actual conflicts and challenges from the document
            let (conflicts, challenges): ([Domain.DomainArchitecturalConflict], [Domain.DomainTechnicalChallenge])

            if let provider = getFirstAvailableProvider() {
                // Generate real AI-based analysis
                do {
                    (conflicts, challenges) = try await analysisConverter.generateProfessionalAnalysis(
                        from: document,
                        provider: provider
                    )
                } catch {
                    // If AI analysis fails, return empty arrays (no hardcoded values)
                    conflicts = []
                    challenges = []
                }
            } else {
                // No provider available, return empty arrays
                conflicts = []
                challenges = []
            }

            domainProfessionalAnalysis = Domain.ProfessionalAnalysis(
                hasCriticalIssues: analysis.hasCriticalIssues,
                executiveSummary: analysis.executiveSummary,
                conflictCount: conflicts.count, // Use actual count from AI analysis
                challengeCount: challenges.count, // Use actual count from AI analysis
                complexityScore: analysis.complexityScore,
                blockingIssues: analysis.blockingIssues,
                conflicts: conflicts,
                challenges: challenges
            )

            let analysisSection = Domain.GeneratedSection(
                title: "Professional Analysis",
                content: analysis.executiveSummary,
                type: "analysis"
            )
            sections.insert(analysisSection, at: 0)
        }

        let fullContent = sections.map { section in
            "## \(section.title)\n\n\(section.content)"
        }.joined(separator: "\n\n")

        // Adjust confidence based on professional analysis
        let confidence: Double = document.professionalAnalysis?.hasCriticalIssues == true ? 0.65 : 0.85

        // Store professional analysis in metadata for retrieval
        var metadataDict: [String: Any] = [
            "provider": "native-prd-generator",
            "modelVersion": "orchestrated"
        ]

        if let domainAnalysis = domainProfessionalAnalysis {
            metadataDict["professionalAnalysis"] = domainAnalysis
        }

        return PRDGenerationResult(
            content: fullContent,
            sections: sections,
            confidence: confidence,
            metadata: Domain.GenerationMetadata(
                provider: "native-prd-generator",
                modelVersion: "orchestrated",
                processingTime: 0.0,
                tokensUsed: 0,
                cost: nil
            ),
            professionalAnalysis: domainProfessionalAnalysis
        )
    }

    private func mapSectionType(_ title: String) -> String {
        let lowercased = title.lowercased()
        if lowercased.contains("overview") || lowercased.contains("summary") {
            return "executive_summary"
        } else if lowercased.contains("problem") {
            return "problem_statement"
        } else if lowercased.contains("stories") || lowercased.contains("user") {
            return "user_stories"
        } else if lowercased.contains("functional") {
            return "functional_requirements"
        } else if lowercased.contains("non-functional") {
            return "non_functional_requirements"
        } else if lowercased.contains("technical") || lowercased.contains("stack") {
            return "technical_requirements"
        } else if lowercased.contains("acceptance") || lowercased.contains("validation") {
            return "acceptance_criteria"
        } else if lowercased.contains("timeline") || lowercased.contains("roadmap") {
            return "timeline"
        } else if lowercased.contains("risk") {
            return "risks"
        } else {
            return "appendix"
        }
    }

}
