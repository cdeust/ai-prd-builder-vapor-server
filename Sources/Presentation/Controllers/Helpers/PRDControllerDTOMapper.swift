import Foundation
import Domain
import Application

struct PRDControllerDTOMapper {
    static func buildGenerateCommand(from dto: GeneratePRDRequestDTO) -> GeneratePRDCommand {
        let requester = dto.requester.map { requesterDTO in
            RequesterInfo(
                id: requesterDTO.id,
                name: requesterDTO.name,
                email: requesterDTO.email
            )
        }

        return GeneratePRDCommand(
            requestId: dto.requestId ?? UUID(),
            title: dto.title,
            description: dto.description,
            mockupSources: dto.mockupSources?.compactMap { mockupDTO in
                let type = MockupType(rawValue: mockupDTO.type) ?? .url
                let location = mockupDTO.url ?? mockupDTO.localPath ?? mockupDTO.content ?? ""
                return try? MockupSource(
                    type: type,
                    location: location,
                    metadata: nil
                )
            } ?? [],
            priority: Priority(rawValue: dto.priority) ?? .medium,
            requester: requester,
            preferredProvider: dto.preferredProvider,
            options: GenerationOptions(
                includeTestCases: dto.options?.includeTestCases ?? true,
                includeApiSpec: dto.options?.includeApiSpec ?? true,
                includeTechnicalDetails: dto.options?.includeTechnicalDetails ?? true,
                maxSections: dto.options?.maxSections ?? 10,
                targetAudience: dto.options?.targetAudience ?? "technical",
                customPrompt: dto.options?.customPrompt
            )
        )
    }

    static func convertToPRDDocumentDTO(_ result: PRDGenerationResult) -> PRDDocumentDTO {
        return PRDDocumentDTO(
            id: UUID(),
            requestId: UUID(),
            title: "Generated PRD",
            content: result.content,
            sections: result.sections.map { section in
                PRDSectionDTO(
                    id: UUID(),
                    title: section.title,
                    content: section.content,
                    order: 0,
                    sectionType: section.type
                )
            },
            metadata: DocumentMetadataDTO(
                format: "markdown",
                language: "en",
                wordCount: result.content.split(separator: " ").count,
                estimatedReadTime: result.content.split(separator: " ").count / 200,
                tags: [],
                attachments: []
            ),
            generatedAt: Date(),
            generatedBy: result.metadata.provider,
            confidence: result.confidence,
            version: 1
        )
    }

    static func parseMockupSources(from dtos: [MockupSourceDTO]?) -> [MockupSource] {
        return dtos?.compactMap { dto in
            let type = MockupType(rawValue: dto.type) ?? .url
            let location = dto.url ?? dto.localPath ?? dto.content ?? ""
            return try? MockupSource(
                type: type,
                location: location,
                metadata: nil
            )
        } ?? []
    }

    static func getStatusMessage(for status: GenerationStatus) -> String {
        switch status {
        case .needsClarification:
            return "Additional information needed to generate a high-quality PRD. Please review the clarification questions."
        case .completed:
            return "PRD generated successfully."
        case .failed:
            return "PRD generation failed. Please try again or contact support."
        }
    }
}