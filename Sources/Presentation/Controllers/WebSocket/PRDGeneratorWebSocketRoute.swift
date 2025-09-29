import Vapor
import PRDGenerator
import CommonModels
import DomainCore
import AIProvidersCore
import AIProviderImplementations

/// New WebSocket route that uses PRDGenerator with WebSocketInteractionHandler
public final class PRDGeneratorWebSocketRoute {

    /// Handle PRD generation via WebSocket with streaming
    public static func handleGenerateWithStreaming(req: Request, ws: WebSocket) async {
        print("[PRDGen-WS] New WebSocket connection established")

        // Create adapter for bridging Vapor WebSocket with PRDGenerator
        let adapter = VaporWebSocketAdapter(ws: ws)

        // Setup WebSocket message handler
        ws.onText { ws, text in
            print("[PRDGen-WS] Received: \(text)")
            await PRDGeneratorWebSocketRoute.handleIncomingMessage(text: text, ws: ws, adapter: adapter)
        }

        ws.onClose.whenComplete { _ in
            print("[PRDGen-WS] WebSocket closed")
        }

        // Send ready message
        try? await ws.send("""
        {
            "type": "ready",
            "message": "PRD Generator WebSocket ready. Send start message with your input."
        }
        """)
    }

    /// Handle incoming WebSocket messages
    private static func handleIncomingMessage(
        text: String,
        ws: WebSocket,
        adapter: VaporWebSocketAdapter
    ) async {
        guard let data = text.data(using: .utf8),
              let message = try? JSONDecoder().decode(ClientMessage.self, from: data) else {
            try? await ws.send("""
            {
                "type": "error",
                "payload": {"message": "Invalid message format"}
            }
            """)
            return
        }

        switch message.type {
        case "start":
            await handleStartGeneration(message: message, ws: ws, adapter: adapter)

        case "response":
            // User responded to a question
            if let response = message.response {
                await adapter.receiveResponse(response)
            }

        default:
            try? await ws.send("""
            {
                "type": "error",
                "payload": {"message": "Unknown message type: \(message.type)"}
            }
            """)
        }
    }

    /// Handle PRD generation start
    private static func handleStartGeneration(
        message: ClientMessage,
        ws: WebSocket,
        adapter: VaporWebSocketAdapter
    ) async {
        guard let input = message.input else {
            try? await ws.send("""
            {
                "type": "error",
                "payload": {"message": "Missing input field"}
            }
            """)
            return
        }

        Task {
            do {
                print("[PRDGen-WS] Starting PRD generation")

                // Create AI provider (Apple Intelligence preferred)
                let provider = AppleProvider(mode: .hybrid)

                // Create configuration with professional analysis enabled
                let config = Configuration(
                    maxPrivacyLevel: .onDevice,
                    useChainOfThought: message.useChainOfThought ?? false,
                    useSelfConsistency: message.useSelfConsistency ?? false,
                    enableProfessionalAnalysis: true,
                    detectArchitecturalConflicts: true,
                    predictTechnicalChallenges: true,
                    analyzeComplexity: true,
                    identifyScalingBreakpoints: true,
                    showCriticalDecisions: true
                )

                // Create WebSocketInteractionHandler with adapter
                let wsHandler = WebSocketInteractionHandler(
                    sendMessage: await adapter.makeSender(),
                    receiveResponse: await adapter.makeReceiver()
                )

                // Create PRD Generator with WebSocket support
                let generator = PRDGenerator.createForWebSocket(
                    provider: provider,
                    configuration: config,
                    webSocketHandler: wsHandler
                )

                print("[PRDGen-WS] Generating PRD...")

                // Generate PRD - all output automatically streams through WebSocket
                let prd = try await generator.generatePRD(from: input)

                print("[PRDGen-WS] Generation complete!")

                // Send completion message with professional analysis
                let markdown = "# \(prd.title)\n\n" + prd.sections.map { "## \($0.title)\n\n\($0.content)\n\n" }.joined()

                var prdPayload: [String: Any] = [
                    "title": prd.title,
                    "content": markdown,
                    "sections": prd.sections.map { section in
                        [
                            "title": section.title,
                            "content": section.content
                        ]
                    }
                ]

                // Include professional analysis if present
                if let analysis = prd.professionalAnalysis {
                    prdPayload["professionalAnalysis"] = [
                        "hasCriticalIssues": analysis.hasCriticalIssues,
                        "executiveSummary": analysis.executiveSummary,
                        "conflictCount": analysis.conflictCount,
                        "challengeCount": analysis.challengeCount,
                        "complexityScore": analysis.complexityScore as Any,
                        "blockingIssues": analysis.blockingIssues
                    ]
                }

                let completionMessage = [
                    "type": "complete",
                    "payload": ["prd": prdPayload]
                ] as [String: Any]

                if let jsonData = try? JSONSerialization.data(withJSONObject: completionMessage),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    try await ws.send(jsonString)
                }

            } catch {
                print("[PRDGen-WS] Error: \(error)")
                try? await ws.send("""
                {
                    "type": "error",
                    "payload": {"message": "Generation failed: \(error.localizedDescription)"}
                }
                """)
            }
        }
    }
}

// MARK: - Message Types

struct ClientMessage: Codable {
    let type: String
    let input: String?
    let response: String?
    let useChainOfThought: Bool?
    let useSelfConsistency: Bool?
}