import Vapor
import Domain
import Application
import Infrastructure

public final class PRDGenerationController: RouteCollection, @unchecked Sendable {
    private let applicationService: PRDApplicationService
    private let aiOrchestrator: AIOrchestratorProvider?

    public init(applicationService: PRDApplicationService, aiOrchestrator: AIOrchestratorProvider?) {
        self.applicationService = applicationService
        self.aiOrchestrator = aiOrchestrator
    }

    public func boot(routes: RoutesBuilder) throws {
        let prd = routes.grouped("api", "v1", "prd")

        // Create PRD request without starting generation (for Request-First workflow)
        prd.post("requests", use: createPRDRequest)

        // Generation endpoints
        prd.post("generate", use: generatePRD)
        prd.post("generate", "interactive", use: generatePRDInteractive)
        prd.post("generate", "provider", ":providerName", use: generatePRDWithProvider)
        prd.post("analyze", use: analyzeRequirements)
    }

    /// Create a PRD request without starting generation (Request-First workflow)
    func createPRDRequest(req: Request) async throws -> CreatePRDRequestResponseDTO {
        let dto = try req.content.decode(CreatePRDRequestDTO.self)

        let requestId = dto.requestId ?? UUID()
        let requester = Requester(
            id: dto.requester?.id ?? "anonymous",
            email: dto.requester?.email
        )

        let request = PRDRequest(
            id: requestId,
            title: dto.title,
            description: dto.description,
            mockupSources: [],
            priority: Priority(rawValue: dto.priority ?? "medium") ?? .medium,
            requester: requester,
            metadata: RequestMetadata(),
            createdAt: Date(),
            status: .pending
        )

        try request.validate()
        let savedRequest = try await applicationService.getPRDRepository().save(request)

        return CreatePRDRequestResponseDTO(
            requestId: savedRequest.id.uuidString,
            title: savedRequest.title,
            description: savedRequest.description,
            status: savedRequest.status.rawValue,
            createdAt: savedRequest.createdAt,
            message: "PRD request created. You can now upload mockups using POST /api/v1/mockups/upload"
        )
    }

    func generatePRD(req: Request) async throws -> PRDGenerationResponseDTO {
        let dto = try req.content.decode(GeneratePRDRequestDTO.self)
        let generateCommand = PRDControllerDTOMapper.buildGenerateCommand(from: dto)

        Task.detached {
            do {
                _ = try await self.applicationService.generatePRDWithAnalysis(generateCommand)
            } catch {
                req.logger.error("PRD generation failed: \(error)")
            }
        }

        return PRDGenerationResponseDTO(
            requestId: generateCommand.requestId,
            status: "pending",
            analysis: nil,
            document: nil,
            message: "PRD generation started. Connect to WebSocket at /api/v1/prd/ws/\(generateCommand.requestId) for real-time updates."
        )
    }

    func generatePRDInteractive(req: Request) async throws -> PRDGenerationResponseDTO {
        guard let orchestrator = aiOrchestrator else {
            throw Abort(.serviceUnavailable, reason: "AI Orchestrator not available for interactive generation")
        }

        let dto = try req.content.decode(GeneratePRDRequestDTO.self)
        let generateCommand = PRDControllerDTOMapper.buildGenerateCommand(from: dto)

        let result = try await orchestrator.generatePRDWithClarifications(from: generateCommand) { questions in
            req.logger.info("Interactive clarifications needed: \(questions)")
            return []
        }

        return PRDGenerationResponseDTO(
            requestId: generateCommand.requestId,
            status: "completed",
            analysis: nil,
            document: PRDControllerDTOMapper.convertToPRDDocumentDTO(result),
            message: "PRD generated with interactive clarifications"
        )
    }

    func generatePRDWithProvider(req: Request) async throws -> PRDGenerationResponseDTO {
        guard let orchestrator = aiOrchestrator else {
            throw Abort(.serviceUnavailable, reason: "AI Orchestrator not available")
        }

        guard let providerName = req.parameters.get("providerName") else {
            throw Abort(.badRequest, reason: "Provider name required")
        }

        let dto = try req.content.decode(GeneratePRDRequestDTO.self)
        let generateCommand = PRDControllerDTOMapper.buildGenerateCommand(from: dto)

        let result = try await orchestrator.generatePRDWithProvider(
            from: generateCommand,
            providerName: providerName
        )

        return PRDGenerationResponseDTO(
            requestId: generateCommand.requestId,
            status: "completed",
            analysis: nil,
            document: PRDControllerDTOMapper.convertToPRDDocumentDTO(result),
            message: "PRD generated using \(providerName) provider"
        )
    }

    func analyzeRequirements(req: Request) async throws -> RequirementsAnalysisDTO {
        let dto = try req.content.decode(AnalyzeRequirementsRequestDTO.self)
        let aiProvider = applicationService.getAIProvider()
        let analysis = try await aiProvider.analyzeRequirements(dto.description)
        return RequirementsAnalysisDTO.from(analysis)
    }
}