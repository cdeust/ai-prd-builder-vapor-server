import Vapor
import Presentation
import PRDGenerator
import CommonModels
import DomainCore
import AIProvidersCore

/// Handles route configuration for the application
public final class RouteConfigurator {
    private let app: Application

    public init(app: Application) {
        self.app = app
    }

    /// Register all application routes
    public func configure() throws {
        registerHealthCheck()
        registerDocumentation()
        try registerAPIRoutes()
    }

    // MARK: - Private Methods

    private func registerHealthCheck() {
        let environment = app.environment.name
        app.get("health") { req in
            return HealthResponse(
                status: "healthy",
                timestamp: Date(),
                version: Environment.get("APP_VERSION") ?? "1.0.0",
                environment: environment
            )
        }
    }

    private func registerDocumentation() {
        app.get("docs") { req in
            return req.redirect(to: "/docs/index.html")
        }
    }

    private func registerAPIRoutes() throws {
        guard let generationController = app.diContainer.resolve(PRDGenerationController.self) else {
            throw ConfigurationError.missingDependency("PRDGenerationController")
        }

        guard let managementController = app.diContainer.resolve(PRDManagementController.self) else {
            throw ConfigurationError.missingDependency("PRDManagementController")
        }

        guard let providerController = app.diContainer.resolve(ProviderController.self) else {
            throw ConfigurationError.missingDependency("ProviderController")
        }

        guard let webSocketController = app.diContainer.resolve(PRDWebSocketController.self) else {
            throw ConfigurationError.missingDependency("PRDWebSocketController")
        }

        guard let mockupController = app.diContainer.resolve(MockupController.self) else {
            throw ConfigurationError.missingDependency("MockupController")
        }

        try app.register(collection: generationController)
        try app.register(collection: managementController)
        try app.register(collection: providerController)
        try app.register(collection: webSocketController)
        try app.register(collection: mockupController)

        // Register codebase controller if available
        if let codebaseController = app.diContainer.resolve(CodebaseController.self) {
            try app.register(collection: codebaseController)
        } else {
            app.logger.warning("CodebaseController not available - codebase routes will not be registered")
        }

        registerPRDGeneratorWebSocket()
    }

    private func registerPRDGeneratorWebSocket() {
        app.webSocket("api", "v1", "prd", "generate", "stream", onUpgrade: PRDGeneratorWebSocketRoute.handleGenerateWithStreaming)
    }
}
