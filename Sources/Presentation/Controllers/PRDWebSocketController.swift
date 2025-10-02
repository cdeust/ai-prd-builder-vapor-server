import Vapor
import Domain
import Application
import Infrastructure
import ImplementationAnalysis

public final class PRDWebSocketController: RouteCollection, @unchecked Sendable {
    private let applicationService: PRDApplicationService
    private let aiOrchestrator: AIOrchestratorProvider?
    private let prdCodebaseLink: PRDCodebaseLink?
    private let codebaseRepository: CodebaseRepositoryProtocol?
    private let githubParser: GitHubTreeParser?

    public init(
        applicationService: PRDApplicationService,
        aiOrchestrator: AIOrchestratorProvider?,
        prdCodebaseLink: PRDCodebaseLink? = nil,
        codebaseRepository: CodebaseRepositoryProtocol? = nil,
        githubParser: GitHubTreeParser? = nil
    ) {
        self.applicationService = applicationService
        self.aiOrchestrator = aiOrchestrator
        self.prdCodebaseLink = prdCodebaseLink
        self.codebaseRepository = codebaseRepository
        self.githubParser = githubParser
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
        // Extract session ID from URL (may be PRD request ID or a random session ID)
        guard let sessionId = extractRequestId(from: req) else {
            _ = try? await ws.close(code: .policyViolation)
            return
        }

        guard let orchestrator = aiOrchestrator else {
            try? await ws.send("AI Orchestrator not available")
            _ = try? await ws.close(code: .unacceptableData)
            return
        }

        let stateHandler = WebSocketStateHandler()
        setupInteractiveWebSocketHandler(ws: ws, orchestrator: orchestrator, stateHandler: stateHandler, sessionId: sessionId)
        try? await ws.send("Interactive PRD generation ready. Send 'start_generation' message with prdRequestId to begin.")
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
        sessionId: UUID
    ) {
        ws.onText { ws, text in
            guard let data = text.data(using: .utf8),
                  let message = try? JSONDecoder().decode(InteractiveMessage.self, from: data) else {
                print("Invalid WebSocket message for session \(sessionId)")
                return
            }

            switch message.type {
            case "start_generation":
                // Extract PRD request ID from message or fall back to session ID
                let prdRequestId: UUID
                if let prdIdString = message.prdRequestId,
                   let prdId = UUID(uuidString: prdIdString) {
                    prdRequestId = prdId
                    print("[WebSocket] Using PRD request ID from message: \(prdRequestId)")
                } else {
                    prdRequestId = sessionId
                    print("[WebSocket] Using session ID as PRD request ID: \(prdRequestId)")
                }
                self.handleStartGeneration(ws: ws, message: message, orchestrator: orchestrator, stateHandler: stateHandler, requestId: prdRequestId)
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
        stateHandler: WebSocketStateHandler,
        requestId: UUID
    ) {
        Task {
            do {
                // Try to fetch codebase context using the provided request ID
                var codebaseContext = await fetchCodebaseContext(for: requestId)
                var actualPRDRequestId = requestId

                // If no codebase found and we have a title, try to find the actual PRD request
                if codebaseContext == nil, let title = message.title {
                    print("[WebSocket] 🔍 No codebase for session ID, searching for PRD by title: \(title)")
                    if let foundPRDId = await findRecentPRDByTitle(title) {
                        print("[WebSocket] ✅ Found PRD request by title: \(foundPRDId)")
                        actualPRDRequestId = foundPRDId
                        codebaseContext = await fetchCodebaseContext(for: foundPRDId)
                    }
                }

                if let context = codebaseContext {
                    print("[WebSocket] ✅ Found linked codebase: \(context.repositoryUrl) with \(context.techStack.languages.count) languages")
                } else {
                    print("[WebSocket] ⚠️ No codebase linked to PRD request: \(actualPRDRequestId)")
                }

                let command: GeneratePRDCommand

                if let existingCommand = message.generateCommand {
                    command = existingCommand
                } else if let title = message.title, let description = message.description {
                    let priority = Priority(rawValue: message.priority ?? "medium") ?? .medium
                    command = GeneratePRDCommand(
                        requestId: actualPRDRequestId,  // ✅ Use the actual PRD ID we found!
                        title: title,
                        description: description,
                        priority: priority,
                        codebaseContext: codebaseContext  // ✅ Include codebase context!
                    )
                } else {
                    try? await ws.send("""
                        {
                            "type": "error",
                            "message": "Invalid message format: missing title or description"
                        }
                        """)
                    return
                }

                print("[WebSocket] Starting PRD generation with streaming...")
                print("[WebSocket] Command: title=\(command.title), description length=\(command.description.count)")

                let progressHandler: @Sendable (String) async -> Void = { [weak ws] message in
                    print("[WebSocket] progressHandler called with: \(message)")
                    guard let ws = ws else {
                        print("[WebSocket] ❌ WebSocket is nil!")
                        return
                    }
                    await self.sendProgressUpdate(ws: ws, message: message)
                }

                let sectionHandler: @Sendable (String, String, Int) async -> Void = { [weak ws] title, content, order in
                    guard let ws = ws else { return }
                    print("[WebSocket] 📄 Section received: \(title) (order: \(order))")
                    await self.sendSectionUpdate(ws: ws, title: title, content: content, order: order)
                }

                print("[WebSocket] Calling orchestrator.generatePRDWithClarifications with streaming handlers...")
                let result = try await orchestrator.generatePRDWithClarifications(
                    from: command,
                    clarificationHandler: { questions in
                        print("[WebSocket] Clarifications needed: \(questions.count)")
                        await self.sendClarificationRequest(ws: ws, questions: questions)
                        let answers = await self.waitForClarificationAnswers(stateHandler: stateHandler)
                        print("[WebSocket] Received \(answers.count) answers from frontend")
                        return answers
                    },
                    progressHandler: progressHandler,
                    sectionHandler: sectionHandler
                )

                print("[WebSocket] ✅ Generation complete with \(result.sections.count) sections")
                await self.sendGenerationCompleteFromResult(ws: ws, result: result)
                print("[WebSocket] All done!")

            } catch {
                print("[WebSocket] ❌ ERROR: \(error)")
                print("[WebSocket] Error type: \(type(of: error))")
                try? await ws.send("""
                    {
                        "type": "error",
                        "message": "Generation failed: \(error.localizedDescription)"
                    }
                    """)
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

    private func sendProgressUpdate(ws: WebSocket, message: String) async {
        print("[WebSocket] 📤 Sending progress: \(message)")

        let progressMessage = InteractiveMessage(
            type: "progress",
            message: message,
            questions: nil,
            generateCommand: nil,
            answers: nil
        )

        if let messageData = try? JSONEncoder().encode(progressMessage),
           let messageString = String(data: messageData, encoding: .utf8) {
            do {
                try await ws.send(messageString)
                print("[WebSocket] ✅ Sent to frontend")
            } catch {
                print("[WebSocket] ❌ Failed to send: \(error)")
            }
        } else {
            print("[WebSocket] ❌ Failed to encode message")
        }
    }

    private func sendSectionsAndComplete(ws: WebSocket, document: PRDDocument) async {
        print("[WebSocket] Sending \(document.sections.count) sections to frontend")

        for (index, section) in document.sections.enumerated() {
            print("[WebSocket] Sending section \(index + 1): \(section.title) (\(section.content.count) chars)")
            await sendSectionUpdate(
                ws: ws,
                title: section.title,
                content: section.content,
                order: index + 1
            )
        }

        let generatedSections = document.sections.map { section in
            GeneratedSection(title: section.title, content: section.content, type: section.sectionType.rawValue)
        }

        let generationMetadata = GenerationMetadata(
            provider: document.generatedBy,
            modelVersion: "1.0",
            processingTime: 0.0,
            tokensUsed: 0,
            cost: nil
        )

        let result = PRDGenerationResult(
            content: document.content,
            sections: generatedSections,
            confidence: document.confidence,
            metadata: generationMetadata
        )

        print("[WebSocket] Sending generation complete message...")
        await sendGenerationComplete(ws: ws, result: result)
        print("[WebSocket] All done!")
    }

    private func sendSectionUpdate(ws: WebSocket, title: String, content: String, order: Int) async {
        let sectionId = title.lowercased().replacingOccurrences(of: " ", with: "-")
        let sectionUpdate = SectionUpdate(id: sectionId, title: title, content: content, order: order)
        let sectionMessage = InteractiveMessage(
            type: "section",
            section: sectionUpdate
        )

        if let messageData = try? JSONEncoder().encode(sectionMessage),
           let messageString = String(data: messageData, encoding: .utf8) {
            print("[WebSocket] Encoded section message: \(messageString.prefix(100))...")
            try? await ws.send(messageString)
            print("[WebSocket] Section message sent successfully")
        } else {
            print("[WebSocket] ERROR: Failed to encode section message")
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

    private func sendGenerationCompleteFromResult(ws: WebSocket, result: PRDGenerationResult) async {
        let generationMetadata = GenerationMetadata(
            provider: result.metadata.provider,
            modelVersion: result.metadata.modelVersion,
            processingTime: result.metadata.processingTime,
            tokensUsed: result.metadata.tokensUsed,
            cost: result.metadata.cost
        )

        let prdResult = PRDGenerationResult(
            content: result.content,
            sections: result.sections,
            confidence: result.confidence,
            metadata: generationMetadata
        )

        await sendGenerationComplete(ws: ws, result: prdResult)
    }

    /// Find a recently created PRD request by title (within last 60 seconds)
    private func findRecentPRDByTitle(_ title: String) async -> UUID? {
        do {
            // Get recent pending PRDs from repository
            let repository = applicationService.getPRDRepository()
            let recentPRDs = try await repository.findByStatus(.pending)

            // Find the most recent PRD with matching title (case-insensitive, trimmed)
            let normalizedTitle = title.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased()

            for prd in recentPRDs {
                let prdTitle = prd.title.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased()
                if prdTitle == normalizedTitle || prdTitle.contains(normalizedTitle) || normalizedTitle.contains(prdTitle) {
                    // Check if created within last 60 seconds
                    let timeSinceCreation = Date().timeIntervalSince(prd.createdAt)
                    if timeSinceCreation < 60 {
                        return prd.id
                    }
                }
            }

            return nil
        } catch {
            print("[WebSocket] ❌ Error searching for PRD by title: \(error)")
            return nil
        }
    }

    /// Fetch codebase context for a PRD request if linked
    private func fetchCodebaseContext(for prdRequestId: UUID) async -> CodebaseContext? {
        guard let prdCodebaseLink = prdCodebaseLink,
              codebaseRepository != nil,
              githubParser != nil else {
            return nil
        }

        do {
            guard let linkedCodebase = try await prdCodebaseLink.getCodebaseForPRD(prdRequestId: prdRequestId) else {
                return nil
            }

            // Build tech stack info
            let techStack = TechStackInfo(
                languages: linkedCodebase.detectedLanguages,
                frameworks: linkedCodebase.detectedFrameworks,
                architecturePatterns: linkedCodebase.architecturePatterns.map { $0.name }
            )

            // Build summary from tech stack
            let languagesSummary = techStack.languages.map { "\($0.key)" }.joined(separator: ", ")
            let frameworksSummary = techStack.frameworks.isEmpty ? "No frameworks detected" : techStack.frameworks.joined(separator: ", ")
            let summary = """
            Repository: \(linkedCodebase.repositoryUrl)
            Languages: \(languagesSummary)
            Frameworks: \(frameworksSummary)
            Total Files: \(linkedCodebase.totalFiles)
            Architecture: \(techStack.architecturePatterns.joined(separator: ", "))
            """

            // For now, we'll include minimal file context to avoid token limits
            // In the future, this could be enhanced with semantic search
            let relevantFiles: [CodeFileContext] = []

            return CodebaseContext(
                projectId: linkedCodebase.id,
                repositoryUrl: linkedCodebase.repositoryUrl,
                repositoryBranch: linkedCodebase.repositoryBranch,
                summary: summary,
                relevantFiles: relevantFiles,
                techStack: techStack
            )
        } catch {
            print("[WebSocket] ❌ Error fetching codebase context: \(error)")
            return nil
        }
    }
}