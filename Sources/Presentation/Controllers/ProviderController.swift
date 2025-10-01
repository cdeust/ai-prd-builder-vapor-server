import Vapor
import Infrastructure
import Domain
import AsyncHTTPClient

public final class ProviderController: RouteCollection, @unchecked Sendable {
    private let aiOrchestrator: AIOrchestratorProvider?
    private let aiProvider: AIProviderPort
    private let app: Application

    public init(aiOrchestrator: AIOrchestratorProvider?, aiProvider: AIProviderPort, app: Application) {
        self.aiOrchestrator = aiOrchestrator
        self.aiProvider = aiProvider
        self.app = app
    }

    public func boot(routes: RoutesBuilder) throws {
        let prd = routes.grouped("api", "v1", "prd")

        prd.get("providers", "available", use: getAvailableProviders)
        prd.get("providers", "status", use: getProviderStatus)
        prd.get("providers", "current", use: getCurrentProvider)
    }

    func getAvailableProviders(req: Request) async throws -> AvailableProvidersResponseDTO {
        var availableProviders: [AvailableProviderDTO] = []

        // Always available - Native
        availableProviders.append(AvailableProviderDTO(
            id: "native",
            name: "Native PRD Generator",
            description: "Built-in PRD generation using ai-prd-builder package",
            isAvailable: true,
            priority: 0,
            requiresApiKey: false
        ))

        // Check Anthropic
        if let anthropicKey = Environment.get("ANTHROPIC_API_KEY"), !anthropicKey.isEmpty {
            let model = Environment.get("ANTHROPIC_MODEL") ?? "claude-sonnet-4-5-20250929"
            availableProviders.append(AvailableProviderDTO(
                id: "anthropic",
                name: "Anthropic Claude",
                description: "Claude Sonnet 4.5 - Advanced reasoning and analysis",
                isAvailable: true,
                priority: 1,
                requiresApiKey: true,
                model: model
            ))
        }

        // Check OpenAI
        if let openaiKey = Environment.get("OPENAI_API_KEY"), !openaiKey.isEmpty {
            let model = Environment.get("OPENAI_MODEL") ?? "gpt-5-turbo-2025-01-01"
            availableProviders.append(AvailableProviderDTO(
                id: "openai",
                name: "OpenAI GPT",
                description: "GPT-5 Turbo - Fast and capable language model",
                isAvailable: true,
                priority: 2,
                requiresApiKey: true,
                model: model
            ))
        }

        // Check Gemini
        if let geminiKey = Environment.get("GEMINI_API_KEY"), !geminiKey.isEmpty {
            let model = Environment.get("GEMINI_MODEL") ?? "gemini-2.5-pro-latest"
            availableProviders.append(AvailableProviderDTO(
                id: "gemini",
                name: "Google Gemini",
                description: "Gemini 2.5 Pro - Powerful multimodal AI",
                isAvailable: true,
                priority: 3,
                requiresApiKey: true,
                model: model
            ))
        }

        // Note: AI Orchestrator is not included as a user-selectable provider
        // It's an internal routing mechanism, not a direct provider choice

        return AvailableProvidersResponseDTO(providers: availableProviders)
    }

    func getProviderStatus(req: Request) async throws -> ProviderHealthResponseDTO {
        guard let orchestrator = aiOrchestrator else {
            throw Abort(.serviceUnavailable, reason: "AI Orchestrator not available for status monitoring")
        }

        let providers = try await orchestrator.getAvailableProviders()

        let healthStatus = providers.reduce(into: [String: ProviderHealthDTO]()) { result, provider in
            result[provider.name] = ProviderHealthDTO(
                isHealthy: provider.isAvailable,
                lastChecked: provider.lastUsed ?? Date(),
                failureCount: 0,
                avgResponseTime: 1.0
            )
        }

        return ProviderHealthResponseDTO(providers: healthStatus)
    }

    func getCurrentProvider(req: Request) async throws -> CurrentProviderResponseDTO {
        let isAvailable = await aiProvider.isAvailable

        return CurrentProviderResponseDTO(
            name: aiProvider.name,
            priority: aiProvider.priority,
            isAvailable: isAvailable,
            configuredProvider: Environment.get("AI_PROVIDER") ?? "native"
        )
    }
}

// MARK: - Response DTOs

struct CurrentProviderResponseDTO: Content {
    let name: String
    let priority: Int
    let isAvailable: Bool
    let configuredProvider: String
}

struct AvailableProviderDTO: Content {
    let id: String
    let name: String
    let description: String
    let isAvailable: Bool
    let priority: Int
    let requiresApiKey: Bool
    let model: String?

    init(id: String, name: String, description: String, isAvailable: Bool, priority: Int, requiresApiKey: Bool, model: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.isAvailable = isAvailable
        self.priority = priority
        self.requiresApiKey = requiresApiKey
        self.model = model
    }
}

struct AvailableProvidersResponseDTO: Content {
    let providers: [AvailableProviderDTO]
}