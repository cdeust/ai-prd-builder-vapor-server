import Foundation
import Domain

/// Core business logic for PRD generation - Application layer use case
/// Orchestrates the entire PRD generation workflow using ports and domain services
public final class GeneratePRDUseCase {
    private let aiProvider: AIProviderPort
    private let prdRepository: PRDRepositoryProtocol
    private let documentRepository: PRDDocumentRepositoryProtocol

    public init(
        aiProvider: AIProviderPort,
        prdRepository: PRDRepositoryProtocol,
        documentRepository: PRDDocumentRepositoryProtocol
    ) {
        self.aiProvider = aiProvider
        self.prdRepository = prdRepository
        self.documentRepository = documentRepository
    }

    /// Execute PRD generation workflow
    public func execute(_ command: GeneratePRDCommand) async throws -> PRDDocument {
        // 1. Fetch existing request and update status to processing
        guard var savedRequest = try await prdRepository.findById(command.requestId) else {
            throw DomainError.notFound("PRD request not found: \(command.requestId)")
        }

        savedRequest = savedRequest.withStatus(.processing)
        savedRequest = try await prdRepository.update(savedRequest)

        // 2. Generate PRD content using AI provider
        let result = try await aiProvider.generatePRD(from: command)

        // 3. Create PRD document
        let document = PRDDocument(
            requestId: savedRequest.id,
            title: command.title,
            content: result.content,
            sections: result.sections.map { section in
                PRDSection(
                    title: section.title,
                    content: section.content,
                    order: 0, // TODO: Implement proper ordering
                    sectionType: mapSectionType(section.type)
                )
            },
            metadata: DocumentMetadata(
                wordCount: result.content.split(separator: " ").count,
                estimatedReadTime: PRDDocument.estimateReadTime(
                    wordCount: result.content.split(separator: " ").count
                )
            ),
            generatedBy: result.metadata.provider,
            confidence: result.confidence
        )

        // Validate document
        try document.validate()

        // 4. Save or update document
        let existingDocument = try await documentRepository.findByRequestId(command.requestId)
        let savedDocument: PRDDocument
        if let existing = existingDocument {
            let updatedDocument = PRDDocument(
                id: existing.id,
                requestId: savedRequest.id,
                title: command.title,
                content: result.content,
                sections: result.sections.map { section in
                    PRDSection(
                        title: section.title,
                        content: section.content,
                        order: 0,
                        sectionType: mapSectionType(section.type)
                    )
                },
                metadata: DocumentMetadata(
                    wordCount: result.content.split(separator: " ").count,
                    estimatedReadTime: PRDDocument.estimateReadTime(
                        wordCount: result.content.split(separator: " ").count
                    )
                ),
                generatedAt: existing.generatedAt,
                generatedBy: result.metadata.provider,
                confidence: result.confidence,
                version: existing.version + 1
            )
            savedDocument = try await documentRepository.update(updatedDocument)
        } else {
            savedDocument = try await documentRepository.save(document)
        }

        // 5. Update request status
        let completedRequest = savedRequest.withStatus(.completed)

        _ = try await prdRepository.update(completedRequest)

        return savedDocument
    }

    /// Map application section type to domain section type
    private func mapSectionType(_ type: String) -> SectionType {
        switch type.lowercased() {
        case "executive_summary", "summary":
            return .executiveSummary
        case "problem_statement", "problem":
            return .problemStatement
        case "user_stories", "stories":
            return .userStories
        case "functional_requirements", "functional":
            return .functionalRequirements
        case "non_functional_requirements", "non_functional":
            return .nonFunctionalRequirements
        case "technical_requirements", "technical":
            return .technicalRequirements
        case "acceptance_criteria", "acceptance":
            return .acceptanceCriteria
        case "timeline":
            return .timeline
        case "risks":
            return .risks
        default:
            return .appendix
        }
    }
}