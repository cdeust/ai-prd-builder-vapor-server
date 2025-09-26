import Vapor
import Domain
import Application
import Infrastructure

public final class PRDWebSocketController: RouteCollection, @unchecked Sendable {
    private let applicationService: PRDApplicationService
    private let aiOrchestrator: AIOrchestratorProvider?

    public init(applicationService: PRDApplicationService, aiOrchestrator: AIOrchestratorProvider?) {
        self.applicationService = applicationService
        self.aiOrchestrator = aiOrchestrator
    }

    public func boot(routes: RoutesBuilder) throws {
        let prd = routes.grouped("api", "v1", "prd")

        prd.webSocket("ws", ":requestId", onUpgrade: handleWebSocket)
        prd.webSocket("ws", "interactive", ":requestId", onUpgrade: handleInteractiveWebSocket)
    }

    func handleWebSocket(req: Request, ws: WebSocket) async {
        guard let requestId = extractRequestId(from: req) else {
            _ = try? await ws.close(code: .policyViolation)
            return
        }

        setupWebSocketTextHandler(ws: ws, requestId: requestId)
        await sendInitialStatus(ws: ws, requestId: requestId)
    }

    func handleInteractiveWebSocket(req: Request, ws: WebSocket) async {
        guard let requestId = extractRequestId(from: req) else {
            _ = try? await ws.close(code: .policyViolation)
            return
        }

        guard let orchestrator = aiOrchestrator else {
            try? await ws.send("AI Orchestrator not available")
            _ = try? await ws.close(code: .unacceptableData)
            return
        }

        let stateHandler = WebSocketStateHandler()
        setupInteractiveWebSocketHandler(ws: ws, orchestrator: orchestrator, stateHandler: stateHandler, requestId: requestId)
        try? await ws.send("Interactive PRD generation ready for request \(requestId). Send 'start_generation' message to begin.")
    }

    private func extractRequestId(from req: Request) -> UUID? {
        guard let requestIdString = req.parameters.get("requestId"),
              let requestId = UUID(uuidString: requestIdString) else {
            return nil
        }
        return requestId
    }

    private func setupWebSocketTextHandler(ws: WebSocket, requestId: UUID) {
        ws.onText { ws, text in
            print("Received WebSocket message for request \(requestId): \(text)")
        }
    }

    private func sendInitialStatus(ws: WebSocket, requestId: UUID) async {
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

    private func setupInteractiveWebSocketHandler(
        ws: WebSocket,
        orchestrator: AIOrchestratorProvider,
        stateHandler: WebSocketStateHandler,
        requestId: UUID
    ) {
        ws.onText { ws, text in
            guard let data = text.data(using: .utf8),
                  let message = try? JSONDecoder().decode(InteractiveMessage.self, from: data) else {
                print("Invalid WebSocket message for request \(requestId)")
                return
            }

            switch message.type {
            case "start_generation":
                self.handleStartGeneration(ws: ws, message: message, orchestrator: orchestrator, stateHandler: stateHandler)
            case "clarification_answers":
                self.handleClarificationAnswers(message: message, stateHandler: stateHandler)
            default:
                try? await ws.send("Unknown message type: \(message.type)")
            }
        }
    }

    private func handleStartGeneration(
        ws: WebSocket,
        message: InteractiveMessage,
        orchestrator: AIOrchestratorProvider,
        stateHandler: WebSocketStateHandler
    ) {
        Task {
            do {
                guard let command = message.generateCommand else { return }

                let result = try await orchestrator.generatePRDWithClarifications(from: command) { questions in
                    await self.sendClarificationRequest(ws: ws, questions: questions)
                    return await self.waitForClarificationAnswers(stateHandler: stateHandler)
                }

                await self.sendGenerationComplete(ws: ws, result: result)
            } catch {
                try? await ws.send("Generation failed: \(error.localizedDescription)")
            }
        }
    }

    private func handleClarificationAnswers(message: InteractiveMessage, stateHandler: WebSocketStateHandler) {
        guard let answers = message.answers else { return }
        Task {
            if let resolver = await stateHandler.getClarificationResolver() {
                resolver.resume(returning: answers)
                await stateHandler.clearClarificationResolver()
            }
        }
    }

    private func sendClarificationRequest(ws: WebSocket, questions: [String]) async {
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
    }

    private func waitForClarificationAnswers(stateHandler: WebSocketStateHandler) async -> [String] {
        return await withCheckedContinuation { continuation in
            Task {
                await stateHandler.setClarificationResolver(continuation)
            }
        }
    }

    private func sendGenerationComplete(ws: WebSocket, result: PRDGenerationResult) async {
        let completionMessage = InteractiveMessage(
            type: "generation_complete",
            questions: nil,
            generateCommand: nil,
            answers: nil,
            result: PRDControllerDTOMapper.convertToPRDDocumentDTO(result)
        )

        if let messageData = try? JSONEncoder().encode(completionMessage),
           let messageString = String(data: messageData, encoding: .utf8) {
            try? await ws.send(messageString)
        }
    }
}