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
        self.databaseFactory = DatabaseRepositoryFactory(app: app, httpClient: app.http.client.shared)
        self.aiProviderFactory = AIProviderFactory(app: app, httpClient: app.http.client.shared)

        // Register HTTP client for other uses
        register(app.http.client.shared, for: HTTPClient.self)
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

        // Register mockup upload repository
        let mockupUploadRepository = try databaseFactory.createMockupUploadRepository()
        register(mockupUploadRepository, for: MockupUploadRepositoryProtocol.self)

        // Register AI provider using factory
        let aiProvider = try aiProviderFactory.createProvider()
        register(aiProvider, for: AIProviderPort.self)

        // Also register AIOrchestratorProvider specifically if it was created
        if let orchestratorProvider = aiProviderFactory.createAIOrchestratorProvider() {
            register(orchestratorProvider, for: AIOrchestratorProvider.self)
        }

        // Register storage and analysis services
        let storageClient = try createStorageClient()
        register(storageClient, for: MockupStoragePort.self)

        let appleIntelligenceClient = try createAppleIntelligenceClient()
        register(appleIntelligenceClient, for: MockupAnalysisPort.self)
    }

    private func createStorageClient() throws -> MockupStoragePort {
        guard let httpClient = resolve(HTTPClient.self) else {
            throw ConfigurationError.missingDependency("HTTPClient not found")
        }

        guard let supabaseURL = Environment.get("SUPABASE_URL") else {
            throw ConfigurationError.missingEnvironmentVariable("SUPABASE_URL")
        }

        // Use SERVICE_ROLE_KEY for admin operations, fallback to ANON_KEY for development
        guard let supabaseKey = Environment.get("SUPABASE_SERVICE_ROLE_KEY") ?? Environment.get("SUPABASE_ANON_KEY") else {
            throw ConfigurationError.missingEnvironmentVariable("SUPABASE_SERVICE_ROLE_KEY or SUPABASE_ANON_KEY")
        }

        return SupabaseStorageClient(
            httpClient: httpClient,
            supabaseURL: supabaseURL,
            apiKey: supabaseKey,
            bucketName: "prd-mockups"
        )
    }

    private func createAppleIntelligenceClient() throws -> MockupAnalysisPort {
        guard let httpClient = resolve(HTTPClient.self) else {
            throw ConfigurationError.missingDependency("HTTPClient not found")
        }

        // Apple Intelligence uses Foundation Models - no API key required
        let baseURL = Environment.get("APPLE_INTELLIGENCE_URL") ?? "https://api.intelligence.apple.com/v1"

        return AppleIntelligenceClient(
            httpClient: httpClient,
            apiKey: "", // Empty string - Foundation Models don't require authentication
            baseURL: baseURL
        )
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

        // Mockup services
        guard let storagePort = resolve(MockupStoragePort.self),
              let analysisPort = resolve(MockupAnalysisPort.self),
              let uploadRepository = resolve(MockupUploadRepositoryProtocol.self) else {
            throw ConfigurationError.missingDependency("Mockup services not found")
        }

        let mockupProcessingService = MockupProcessingService(
            storagePort: storagePort,
            analysisPort: analysisPort,
            uploadRepository: uploadRepository,
            prdRepository: prdRepository
        )
        register(mockupProcessingService, for: MockupProcessingService.self)

        let mockupCleanupService = MockupCleanupService(
            storagePort: storagePort,
            uploadRepository: uploadRepository
        )
        register(mockupCleanupService, for: MockupCleanupService.self)
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

        // Mockup controller
        guard let mockupProcessingService = resolve(MockupProcessingService.self),
              let mockupCleanupService = resolve(MockupCleanupService.self) else {
            throw ConfigurationError.missingDependency("Mockup services not found")
        }

        let mockupController = MockupController(
            mockupProcessingService: mockupProcessingService,
            mockupCleanupService: mockupCleanupService
        )
        register(mockupController, for: MockupController.self)

        if aiOrchestrator != nil {
            app.logger.info("🎛️ PRD Controllers configured with AI Orchestrator integration")
        } else {
            app.logger.info("⚠️ PRD Controllers configured without AI Orchestrator (fallback mode)")
        }

        app.logger.info("📸 Mockup Controller configured with storage and analysis services")
    }
}
