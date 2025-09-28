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
            enableClarificationPrompts: false
        )

        let generator = PRDGenerator(
            provider: provider,
            configuration: config,
            interactionHandler: NonInteractiveHandler()
        )

        self.prdGenerator = generator

        let document = try await generator.generatePRD(from: command.description)

        return try mapToDomainResult(document)
    }

    public func analyzeRequirements(_ text: String) async throws -> Domain.RequirementsAnalysis {
        guard let provider = getFirstAvailableProvider() else {
            throw DomainError.processingFailed("No AI provider available")
        }

        let analyzer = RequirementsAnalyzer(
            provider: provider,
            interactionHandler: NonInteractiveHandler()
        )

        let enriched = try await analyzer.analyzeAndClarify(input: text)

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

    private func mapToDomainResult(_ document: CommonModels.PRDocument) throws -> PRDGenerationResult {
        let sections = document.sections.map { section in
            Domain.GeneratedSection(
                title: section.title,
                content: section.content,
                type: mapSectionType(section.title)
            )
        }

        let fullContent = document.sections.map { section in
            "## \(section.title)\n\n\(section.content)"
        }.joined(separator: "\n\n")

        return PRDGenerationResult(
            content: fullContent,
            sections: sections,
            confidence: 0.85,
            metadata: Domain.GenerationMetadata(
                provider: "native-prd-generator",
                modelVersion: "orchestrated",
                processingTime: 0.0,
                tokensUsed: 0,
                cost: nil
            )
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

final class NonInteractiveHandler: UserInteractionHandler {
    func askQuestion(_ question: String) async -> String {
        return ""
    }

    func askMultipleChoice(_ question: String, options: [String]) async -> String {
        return options.first ?? ""
    }

    func askYesNo(_ question: String) async -> Bool {
        return true
    }

    func showInfo(_ message: String) {
    }
}