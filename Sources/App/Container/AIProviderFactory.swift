import Foundation
import Vapor
import AsyncHTTPClient
import Domain
import Infrastructure

/// Factory responsible for creating AI providers based on configuration
public final class AIProviderFactory {
    private let app: Application
    private let httpClient: HTTPClient

    public init(app: Application, httpClient: HTTPClient) {
        self.app = app
        self.httpClient = httpClient
    }

    /// Create AI provider based on configuration
    public func createProvider() throws -> AIProviderPort {
        // Primary: AI Orchestrator Provider (uses complete Swift CLI system)
        if let orchestratorProvider = createAIOrchestratorProvider() {
            return orchestratorProvider
        }

        // Fallback: Direct Anthropic provider only if AI Orchestrator fails
        if let anthropicProvider = createAnthropicProvider() {
            app.logger.info("🤖 Fallback: Direct Anthropic provider registered (AI Orchestrator unavailable)")
            return anthropicProvider
        }

        // No providers available
        app.logger.error("❌ No AI providers available. Ensure ai-orchestrator system is properly configured or set ANTHROPIC_API_KEY.")
        throw ConfigurationError.missingAIProvider
    }

    /// Create AI Orchestrator provider if available
    public func createAIOrchestratorProvider() -> AIOrchestratorProvider? {
        do {
            let provider = try AIOrchestratorProvider()
            // Note: AI Orchestrator will be initialized on first use
            app.logger.info("🎯 AI Orchestrator provider configured (will initialize on first use)")
            return provider
        } catch {
            app.logger.error("❌ Failed to initialize AI Orchestrator provider: \(error)")
            return nil
        }
    }

    // MARK: - Private Methods

    private func createAnthropicProvider() -> AnthropicProvider? {
        guard let anthropicKey = Environment.get("ANTHROPIC_API_KEY"), !anthropicKey.isEmpty else {
            return nil
        }

        let model = Environment.get("ANTHROPIC_MODEL") ?? "claude-3-5-sonnet-20241022"
        return AnthropicProvider(
            apiKey: anthropicKey,
            httpClient: httpClient,
            model: model
        )
    }
}