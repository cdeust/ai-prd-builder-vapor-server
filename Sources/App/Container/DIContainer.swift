import Foundation
import Vapor
import AsyncHTTPClient
import Domain
import Application
import Infrastructure
import Presentation

/// Dependency Injection Container for the application
/// Follows Inversion of Control principle for clean architecture
public final class DIContainer: @unchecked Sendable {
    private var services: [String: Any] = [:]
    private let app: Application
    private let databaseFactory: DatabaseRepositoryFactory
    private let aiProviderFactory: AIProviderFactory

    public init(app: Application) {
        self.app = app
        let httpClient = HTTPClient(eventLoopGroupProvider: .shared(app.eventLoopGroup))
        self.databaseFactory = DatabaseRepositoryFactory(app: app, httpClient: httpClient)
        self.aiProviderFactory = AIProviderFactory(app: app, httpClient: httpClient)

        // Register HTTP client for other uses
        register(httpClient, for: HTTPClient.self)
    }

    /// Register services with the container
    public func registerServices() throws {
        try registerInfrastructureServices()
        try registerApplicationServices()
        try registerPresentationServices()
    }

    /// Get service by type
    public func resolve<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        return services[key] as? T
    }

    /// Register service
    public func register<T>(_ service: T, for type: T.Type) {
        let key = String(describing: type)
        services[key] = service
    }

    // MARK: - Service Registration

    /// Register infrastructure layer services
    private func registerInfrastructureServices() throws {
        // Register database repositories using factory
        let repositories = try databaseFactory.createRepositories()
        register(repositories.prd, for: PRDRepositoryProtocol.self)
        register(repositories.document, for: PRDDocumentRepositoryProtocol.self)

        // Register AI provider using factory
        let aiProvider = try aiProviderFactory.createProvider()
        register(aiProvider, for: AIProviderPort.self)

        // Also register AIOrchestratorProvider specifically if it was created
        if let orchestratorProvider = aiProviderFactory.createAIOrchestratorProvider() {
            register(orchestratorProvider, for: AIOrchestratorProvider.self)
        }
    }

    /// Register application layer services
    private func registerApplicationServices() throws {
        guard let aiProvider = resolve(AIProviderPort.self),
              let prdRepository = resolve(PRDRepositoryProtocol.self),
              let documentRepository = resolve(PRDDocumentRepositoryProtocol.self) else {
            throw ConfigurationError.missingDependency("Required repositories or AI provider not found")
        }

        // Use cases
        let generatePRDUseCase = GeneratePRDUseCase(
            aiProvider: aiProvider,
            prdRepository: prdRepository,
            documentRepository: documentRepository
        )
        register(generatePRDUseCase, for: GeneratePRDUseCase.self)

        let analyzeRequirementsUseCase = AnalyzeRequirementsUseCase(aiProvider: aiProvider)
        register(analyzeRequirementsUseCase, for: AnalyzeRequirementsUseCase.self)

        // Application services
        let prdApplicationService = PRDApplicationService(
            generatePRDUseCase: generatePRDUseCase,
            analyzeRequirementsUseCase: analyzeRequirementsUseCase,
            prdRepository: prdRepository,
            documentRepository: documentRepository,
            aiProvider: aiProvider
        )
        register(prdApplicationService, for: PRDApplicationService.self)
    }

    /// Register presentation layer services
    private func registerPresentationServices() throws {
        guard let applicationService = resolve(PRDApplicationService.self) else {
            throw ConfigurationError.missingDependency("PRDApplicationService not found")
        }

        let aiOrchestrator = resolve(AIOrchestratorProvider.self)

        let generationController = PRDGenerationController(
            applicationService: applicationService,
            aiOrchestrator: aiOrchestrator
        )
        register(generationController, for: PRDGenerationController.self)

        let managementController = PRDManagementController(
            applicationService: applicationService
        )
        register(managementController, for: PRDManagementController.self)

        let providerController = ProviderController(
            aiOrchestrator: aiOrchestrator
        )
        register(providerController, for: ProviderController.self)

        let webSocketController = PRDWebSocketController(
            applicationService: applicationService,
            aiOrchestrator: aiOrchestrator
        )
        register(webSocketController, for: PRDWebSocketController.self)

        if aiOrchestrator != nil {
            app.logger.info("🎛️ PRD Controllers configured with AI Orchestrator integration")
        } else {
            app.logger.info("⚠️ PRD Controllers configured without AI Orchestrator (fallback mode)")
        }
    }
}