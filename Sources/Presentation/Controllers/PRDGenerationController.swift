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

        prd.post("generate", use: generatePRD)
        prd.post("generate", "interactive", use: generatePRDInteractive)
        prd.post("generate", "provider", ":providerName", use: generatePRDWithProvider)
        prd.post("analyze", use: analyzeRequirements)
    }

    func generatePRD(req: Request) async throws -> PRDGenerationResponseDTO {
        let dto = try req.content.decode(GeneratePRDRequestDTO.self)
        let generateCommand = PRDControllerDTOMapper.buildGenerateCommand(from: dto)
        let result = try await applicationService.generatePRDWithAnalysis(generateCommand)

        return PRDGenerationResponseDTO(
            requestId: generateCommand.requestId,
            status: result.status.rawValue,
            analysis: result.analysis.map(RequirementsAnalysisDTO.from),
            document: result.document.map(PRDDocumentDTO.from),
            message: PRDControllerDTOMapper.getStatusMessage(for: result.status)
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