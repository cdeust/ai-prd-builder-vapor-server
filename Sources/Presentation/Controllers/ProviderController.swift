import Vapor
import Infrastructure

public final class ProviderController: RouteCollection, @unchecked Sendable {
    private let aiOrchestrator: AIOrchestratorProvider?

    public init(aiOrchestrator: AIOrchestratorProvider?) {
        self.aiOrchestrator = aiOrchestrator
    }

    public func boot(routes: RoutesBuilder) throws {
        let prd = routes.grouped("api", "v1", "prd")

        prd.get("providers", use: getAvailableProviders)
        prd.get("providers", "status", use: getProviderStatus)
    }

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
}