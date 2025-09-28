import Vapor
import PRDGenerator
import CommonModels
import DomainCore
import AIProvidersCore

/// Adapter that bridges Vapor WebSocket with PRDGenerator's WebSocketInteractionHandler
public actor VaporWebSocketAdapter {
    private weak var ws: WebSocket?
    private var pendingQuestionContinuation: CheckedContinuation<String, Never>?
    private var messageQueue: [WebSocketMessage] = []

    public init(ws: WebSocket) {
        self.ws = ws
    }

    /// Creates message sender for WebSocketInteractionHandler
    public nonisolated func makeSender() -> WebSocketInteractionHandler.MessageSender {
        return { [weak self] jsonMessage in
            guard let self = self else { return }
            await self.sendToVapor(jsonMessage)
        }
    }

    /// Creates response receiver for WebSocketInteractionHandler
    public nonisolated func makeReceiver() -> WebSocketInteractionHandler.ResponseReceiver {
        return { [weak self] in
            guard let self = self else { throw WebSocketError.connectionClosed }
            return await self.waitForResponse()
        }
    }

    /// Send message to Vapor WebSocket
    private func sendToVapor(_ message: String) async {
        guard let ws = ws else { return }
        do {
            try await ws.send(message)
        } catch {
            print("[VaporAdapter] Failed to send: \(error)")
        }
    }

    /// Handle user response from frontend
    public func receiveResponse(_ response: String) {
        if let continuation = pendingQuestionContinuation {
            continuation.resume(returning: response)
            pendingQuestionContinuation = nil
        }
    }

    /// Wait for user response
    private func waitForResponse() async -> String {
        await withCheckedContinuation { continuation in
            self.pendingQuestionContinuation = continuation
        }
    }
}