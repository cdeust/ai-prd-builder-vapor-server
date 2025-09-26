import Vapor
import Domain
import Application
import Infrastructure

/// Main controller for PRD operations
/// Enhanced to leverage the complete ai-orchestrator Swift CLI system
public final class PRDController: RouteCollection, @unchecked Sendable {
    private let applicationService: PRDApplicationService
    private let aiOrchestrator: AIOrchestratorProvider?

    public init(applicationService: PRDApplicationService, aiOrchestrator: AIOrchestratorProvider? = nil) {
        self.applicationService = applicationService
        self.aiOrchestrator = aiOrchestrator
    }

    public func boot(routes: RoutesBuilder) throws {
        let prd = routes.grouped("api", "v1", "prd")

        // PRD Generation endpoints (enhanced with ai-orchestrator)
        prd.post("generate", use: generatePRD)
        prd.post("generate", "interactive", use: generatePRDInteractive)
        prd.post("generate", "provider", ":providerName", use: generatePRDWithProvider)
        prd.post("analyze", use: analyzeRequirements)

        // PRD Management endpoints
        prd.get(":requestId", "status", use: getStatus)
        prd.get("requests", use: listRequests)
        prd.get("documents", ":documentId", "export", use: exportDocument)

        // AI Orchestrator specific endpoints
        prd.get("providers", use: getAvailableProviders)
        prd.get("providers", "status", use: getProviderStatus)

        // WebSocket for real-time updates and interactive clarifications
        prd.webSocket("ws", ":requestId", onUpgrade: handleWebSocket)
        prd.webSocket("ws", "interactive", ":requestId", onUpgrade: handleInteractiveWebSocket)
    }

    // MARK: - Route Handlers

    /// Generate PRD from requirements
    func generatePRD(req: Request) async throws -> PRDGenerationResponseDTO {
        let command = try req.content.decode(GeneratePRDRequestDTO.self)

        let generateCommand = GeneratePRDCommand(
            requestId: command.requestId ?? UUID(),
            title: command.title,
            description: command.description,
            mockupSources: command.mockupSources?.compactMap { dto in
                let type = MockupType(rawValue: dto.type) ?? .url
                let location = dto.url ?? dto.localPath ?? dto.content ?? ""
                return try? MockupSource(
                    type: type,
                    location: location,
                    metadata: nil
                )
            } ?? [],
            priority: Priority(rawValue: command.priority) ?? .medium,
            preferredProvider: command.preferredProvider,
            options: GenerationOptions(
                includeTestCases: command.options?.includeTestCases ?? true,
                includeApiSpec: command.options?.includeApiSpec ?? true,
                includeTechnicalDetails: command.options?.includeTechnicalDetails ?? true,
                maxSections: command.options?.maxSections ?? 10,
                targetAudience: command.options?.targetAudience ?? "technical",
                customPrompt: command.options?.customPrompt
            )
        )

        let result = try await applicationService.generatePRDWithAnalysis(generateCommand)

        return PRDGenerationResponseDTO(
            requestId: generateCommand.requestId,
            status: result.status.rawValue,
            analysis: result.analysis.map(RequirementsAnalysisDTO.from),
            document: result.document.map(PRDDocumentDTO.from),
            message: getStatusMessage(for: result.status)
        )
    }

    /// Generate PRD with interactive clarifications
    func generatePRDInteractive(req: Request) async throws -> PRDGenerationResponseDTO {
        guard let orchestrator = aiOrchestrator else {
            throw Abort(.serviceUnavailable, reason: "AI Orchestrator not available for interactive generation")
        }

        let command = try req.content.decode(GeneratePRDRequestDTO.self)
        let generateCommand = buildGenerateCommand(from: command)

        // Start interactive generation - will need WebSocket for clarifications
        let result = try await orchestrator.generatePRDWithClarifications(from: generateCommand) { questions in
            // This would typically be handled via WebSocket, but for demo purposes:
            req.logger.info("Interactive clarifications needed: \(questions)")
            return [] // Return empty answers for now - real implementation uses WebSocket
        }

        return PRDGenerationResponseDTO(
            requestId: generateCommand.requestId,
            status: "completed",
            analysis: nil,
            document: convertToPRDDocumentDTO(result),
            message: "PRD generated with interactive clarifications"
        )
    }

    /// Generate PRD with specific provider
    func generatePRDWithProvider(req: Request) async throws -> PRDGenerationResponseDTO {
        guard let orchestrator = aiOrchestrator else {
            throw Abort(.serviceUnavailable, reason: "AI Orchestrator not available")
        }

        guard let providerName = req.parameters.get("providerName") else {
            throw Abort(.badRequest, reason: "Provider name required")
        }

        let command = try req.content.decode(GeneratePRDRequestDTO.self)
        let generateCommand = buildGenerateCommand(from: command)

        let result = try await orchestrator.generatePRDWithProvider(
            from: generateCommand,
            providerName: providerName
        )

        return PRDGenerationResponseDTO(
            requestId: generateCommand.requestId,
            status: "completed",
            analysis: nil,
            document: convertToPRDDocumentDTO(result),
            message: "PRD generated using \(providerName) provider"
        )
    }

    /// Analyze requirements without generating PRD
    func analyzeRequirements(req: Request) async throws -> RequirementsAnalysisDTO {
        let request = try req.content.decode(AnalyzeRequirementsRequestDTO.self)

        let mockupSources = request.mockupSources?.compactMap { dto in
            let type = MockupType(rawValue: dto.type) ?? .url
            let location = dto.url ?? dto.localPath ?? dto.content ?? ""
            return try? MockupSource(
                type: type,
                location: location,
                metadata: nil
            )
        } ?? []

        // Use AI provider from application service
        let aiProvider = applicationService.getAIProvider()

        let analysis = try await aiProvider.analyzeRequirements(request.description)
        return RequirementsAnalysisDTO.from(analysis)
    }

    /// Get generation status
    func getStatus(req: Request) async throws -> GenerationStatusResponseDTO {
        guard let requestIdString = req.parameters.get("requestId"),
              let requestId = UUID(uuidString: requestIdString) else {
            throw Abort(.badRequest, reason: "Invalid request ID")
        }

        let status = try await applicationService.getGenerationStatus(requestId: requestId)

        return GenerationStatusResponseDTO(
            requestId: status.requestId,
            status: status.status.rawValue,
            progress: status.progress,
            document: status.document.map(PRDDocumentDTO.from),
            createdAt: status.createdAt,
            updatedAt: status.updatedAt,
            completedAt: status.completedAt
        )
    }

    /// List user's PRD requests
    func listRequests(req: Request) async throws -> PRDRequestListResponseDTO {
        // TODO: Extract user ID from authentication
        let userId = "current-user" // Placeholder

        let limit = req.query["limit"] ?? 20
        let offset = req.query["offset"] ?? 0

        let requests = try await applicationService.listPRDRequests(
            for: userId,
            limit: limit,
            offset: offset
        )

        return PRDRequestListResponseDTO(
            requests: requests.map { PRDRequestSummaryDTO(
                id: $0.id,
                title: $0.title,
                status: $0.status.rawValue,
                priority: $0.priority.rawValue,
                createdAt: $0.createdAt,
                completedAt: nil
            ) },
            pagination: PaginationDTO(
                limit: limit,
                offset: offset,
                total: requests.count // TODO: Get actual total count
            )
        )
    }

    /// Export PRD document
    func exportDocument(req: Request) async throws -> Response {
        guard let documentIdString = req.parameters.get("documentId"),
              let documentId = UUID(uuidString: documentIdString) else {
            throw Abort(.badRequest, reason: "Invalid document ID")
        }

        let formatString = req.query["format"] ?? "markdown"
        guard let format = DocumentFormat(rawValue: formatString) else {
            throw Abort(.badRequest, reason: "Invalid export format")
        }

        let exportResult = try await applicationService.exportPRD(
            documentId: documentId,
            format: format
        )

        let response = Response()
        response.body = .init(string: exportResult.content)
        response.headers.contentType = HTTPMediaType(type: exportResult.mimeType.components(separatedBy: "/")[0],
                                                     subType: exportResult.mimeType.components(separatedBy: "/")[1])
        response.headers.add(name: "Content-Disposition", value: "attachment; filename=\"\(exportResult.filename)\"")

        return response
    }

    /// Get available AI providers from orchestrator
    func getAvailableProviders(req: Request) async throws -> ProvidersResponseDTO {
        guard let orchestrator = aiOrchestrator else {
            throw Abort(.serviceUnavailable, reason: "AI Orchestrator not available")
        }

        let providers = try await orchestrator.getAvailableProviders()

        return ProvidersResponseDTO(
            providers: providers.map { provider in
                ProviderStatusDTO(
                    name: provider.name,
                    isAvailable: provider.isAvailable,
                    priority: provider.priority,
                    capabilities: provider.capabilities,
                    lastUsed: provider.lastUsed
                )
            }
        )
    }

    /// Get provider status and health information
    func getProviderStatus(req: Request) async throws -> ProviderHealthResponseDTO {
        guard let orchestrator = aiOrchestrator else {
            throw Abort(.serviceUnavailable, reason: "AI Orchestrator not available for status monitoring")
        }

        // Get status from AI orchestrator system
        let providers = try await orchestrator.getAvailableProviders()

        let healthStatus = providers.reduce(into: [String: ProviderHealthDTO]()) { result, provider in
            result[provider.name] = ProviderHealthDTO(
                isHealthy: provider.isAvailable,
                lastChecked: provider.lastUsed ?? Date(),
                failureCount: 0, // AI orchestrator manages this internally
                avgResponseTime: 1.0 // Placeholder - orchestrator would provide real metrics
            )
        }

        return ProviderHealthResponseDTO(providers: healthStatus)
    }

    /// Handle WebSocket connections for real-time updates
    func handleWebSocket(req: Request, ws: WebSocket) async {
        guard let requestIdString = req.parameters.get("requestId"),
              let requestId = UUID(uuidString: requestIdString) else {
            _ = try? await ws.close(code: .policyViolation)
            return
        }

        // TODO: Implement real-time status updates
        // This would involve:
        // 1. Subscribing to status changes for the request
        // 2. Sending periodic updates to the client
        // 3. Handling client messages for interactive clarifications

        ws.onText { ws, text in
            // Handle client messages
            print("Received WebSocket message for request \(requestId): \(text)")
        }

        // Send initial status
        do {
            let status = try await applicationService.getGenerationStatus(requestId: requestId)
            let statusDTO = GenerationStatusResponseDTO(
                requestId: status.requestId,
                status: status.status.rawValue,
                progress: status.progress,
                document: status.document.map(PRDDocumentDTO.from),
                createdAt: status.createdAt,
                updatedAt: status.updatedAt,
                completedAt: status.completedAt
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(statusDTO)
            if let jsonString = String(data: data, encoding: .utf8) {
                try await ws.send(jsonString)
            }
        } catch {
            print("Error sending initial WebSocket status: \(error)")
        }
    }

    /// Actor to handle WebSocket state safely
    private actor WebSocketStateHandler {
        var clarificationResolver: CheckedContinuation<[String], Never>?

        func setClarificationResolver(_ resolver: CheckedContinuation<[String], Never>) {
            self.clarificationResolver = resolver
        }

        func getClarificationResolver() -> CheckedContinuation<[String], Never>? {
            return clarificationResolver
        }

        func clearClarificationResolver() {
            self.clarificationResolver = nil
        }
    }

    /// Handle WebSocket connections for interactive PRD generation with clarifications
    func handleInteractiveWebSocket(req: Request, ws: WebSocket) async {
        guard let requestIdString = req.parameters.get("requestId"),
              let requestId = UUID(uuidString: requestIdString) else {
            _ = try? await ws.close(code: .policyViolation)
            return
        }

        guard let orchestrator = aiOrchestrator else {
            try? await ws.send("AI Orchestrator not available")
            _ = try? await ws.close(code: .unacceptableData)
            return
        }

        // Use actor for thread-safe state management
        let stateHandler = WebSocketStateHandler()

        ws.onText { ws, text in
            if let data = text.data(using: .utf8),
               let message = try? JSONDecoder().decode(InteractiveMessage.self, from: data) {

                    switch message.type {
                    case "start_generation":
                        // Start interactive PRD generation
                        Task {
                            do {
                                if let command = message.generateCommand {
                                    let result = try await orchestrator.generatePRDWithClarifications(from: command) { questions in
                                        // Send clarification questions to client
                                        let clarificationMessage = InteractiveMessage(
                                            type: "clarification_needed",
                                            questions: questions,
                                            generateCommand: nil,
                                            answers: nil
                                        )

                                        if let messageData = try? JSONEncoder().encode(clarificationMessage),
                                           let messageString = String(data: messageData, encoding: .utf8) {
                                            try? await ws.send(messageString)
                                        }

                                        // Wait for client response
                                        return await withCheckedContinuation { continuation in
                                            Task {
                                                await stateHandler.setClarificationResolver(continuation)
                                            }
                                        }
                                    }

                                    // Send completion message
                                    let completionMessage = InteractiveMessage(
                                        type: "generation_complete",
                                        questions: nil,
                                        generateCommand: nil,
                                        answers: nil,
                                        result: self.convertToPRDDocumentDTO(result)
                                    )

                                    if let messageData = try? JSONEncoder().encode(completionMessage),
                                       let messageString = String(data: messageData, encoding: .utf8) {
                                        try? await ws.send(messageString)
                                    }
                                }
                            } catch {
                                try? await ws.send("Generation failed: \(error.localizedDescription)")
                            }
                        }

                    case "clarification_answers":
                        // Provide answers to clarifications
                        if let answers = message.answers {
                            Task {
                                if let resolver = await stateHandler.getClarificationResolver() {
                                    resolver.resume(returning: answers)
                                    await stateHandler.clearClarificationResolver()
                                }
                            }
                        }

                    default:
                        try? await ws.send("Unknown message type: \(message.type)")
                    }
                }
        }

        try? await ws.send("Interactive PRD generation ready. Send 'start_generation' message to begin.")
    }

    // MARK: - Helper Methods

    /// Build GeneratePRDCommand from request DTO
    private func buildGenerateCommand(from command: GeneratePRDRequestDTO) -> GeneratePRDCommand {
        return GeneratePRDCommand(
            requestId: command.requestId ?? UUID(),
            title: command.title,
            description: command.description,
            mockupSources: command.mockupSources?.compactMap { dto in
                let type = MockupType(rawValue: dto.type) ?? .url
                let location = dto.url ?? dto.localPath ?? dto.content ?? ""
                return try? MockupSource(
                    type: type,
                    location: location,
                    metadata: nil
                )
            } ?? [],
            priority: Priority(rawValue: command.priority) ?? .medium,
            preferredProvider: command.preferredProvider,
            options: GenerationOptions(
                includeTestCases: command.options?.includeTestCases ?? true,
                includeApiSpec: command.options?.includeApiSpec ?? true,
                includeTechnicalDetails: command.options?.includeTechnicalDetails ?? true,
                maxSections: command.options?.maxSections ?? 10,
                targetAudience: command.options?.targetAudience ?? "technical",
                customPrompt: command.options?.customPrompt
            )
        )
    }

    /// Convert PRDGenerationResult to PRDDocumentDTO
    private func convertToPRDDocumentDTO(_ result: PRDGenerationResult) -> PRDDocumentDTO {
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

    /// Get user-friendly status message
    private func getStatusMessage(for status: GenerationStatus) -> String {
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

// MARK: - Error Handling Middleware

/// Middleware to handle domain errors and convert them to appropriate HTTP responses
public final class DomainErrorMiddleware: AsyncMiddleware {
    public init() {}

    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        do {
            return try await next.respond(to: request)
        } catch let error as DomainError {
            let status: HTTPStatus
            let message: String

            switch error {
            case .validation(let msg):
                status = .badRequest
                message = msg
            case .notFound(let msg):
                status = .notFound
                message = msg
            case .businessRule(let msg):
                status = .unprocessableEntity
                message = msg
            case .conflict(let msg):
                status = .conflict
                message = msg
            case .unauthorized(let msg):
                status = .unauthorized
                message = msg
            case .processingFailed(let msg):
                status = .internalServerError
                message = msg
            }

            let errorResponse = ErrorResponseDTO(
                error: ErrorDetailDTO(
                    code: String(describing: error).components(separatedBy: "(")[0],
                    message: message,
                    timestamp: Date()
                )
            )

            let response = Response(status: status)
            try response.content.encode(errorResponse)
            return response
        }
    }
}