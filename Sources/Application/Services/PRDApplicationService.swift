import Foundation
import Domain

/// Application service that coordinates specialized services
/// Acts as a facade for the presentation layer
public final class PRDApplicationService {
    private let workflowService: PRDWorkflowService
    private let statusService: PRDStatusService
    private let exportService: PRDExportService
    private let aiProvider: AIProviderPort

    public init(
        generatePRDUseCase: GeneratePRDUseCase,
        analyzeRequirementsUseCase: AnalyzeRequirementsUseCase,
        prdRepository: PRDRepositoryProtocol,
        documentRepository: PRDDocumentRepositoryProtocol,
        aiProvider: AIProviderPort
    ) {
        self.workflowService = PRDWorkflowService(
            generatePRDUseCase: generatePRDUseCase,
            analyzeRequirementsUseCase: analyzeRequirementsUseCase
        )

        self.statusService = PRDStatusService(
            prdRepository: prdRepository,
            documentRepository: documentRepository
        )

        self.exportService = PRDExportService(
            documentRepository: documentRepository
        )

        self.aiProvider = aiProvider
    }

    /// Get the AI provider for direct usage
    public func getAIProvider() -> AIProviderPort {
        return aiProvider
    }

    /// Complete PRD generation workflow with analysis
    public func generatePRDWithAnalysis(_ command: GeneratePRDCommand) async throws -> PRDGenerationResponse {
        return try await workflowService.generatePRDWithAnalysis(command)
    }

    /// Get PRD generation status
    public func getGenerationStatus(requestId: UUID) async throws -> GenerationStatusResponse {
        return try await statusService.getGenerationStatus(requestId: requestId)
    }

    /// List PRD requests for a user
    public func listPRDRequests(
        for requesterId: String,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> [PRDRequestSummary] {
        return try await statusService.listPRDRequests(
            for: requesterId,
            limit: limit,
            offset: offset
        )
    }

    /// Export PRD document in different formats
    public func exportPRD(documentId: UUID, format: DocumentFormat) async throws -> ExportResult {
        return try await exportService.exportPRD(documentId: documentId, format: format)
    }

    /// Export PRD document by request ID
    public func exportPRDByRequestId(requestId: UUID, format: DocumentFormat) async throws -> ExportResult {
        return try await exportService.exportPRDByRequestId(requestId: requestId, format: format)
    }
}