import Foundation
import Vapor
import AsyncHTTPClient
import Domain
import Application
import Infrastructure
import Presentation
import CommonModels
import DomainCore
import AIProviderImplementations

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

        // Create configuration for ai-prd-builder package
        let modelPreferences = DomainCore.ModelPreferences(
            temperature: 0.3,
            maxTokens: 4000
        )

        let configuration = DomainCore.Configuration(
            anthropicAPIKey: Environment.get("ANTHROPIC_API_KEY"),
            openAIAPIKey: Environment.get("OPENAI_API_KEY"),
            geminiAPIKey: Environment.get("GEMINI_API_KEY"),
            maxPrivacyLevel: .external,
            preferredProvider: Environment.get("MOCKUP_PREFERRED_PROVIDER")?.lowercased() ?? "apple-intelligence",
            modelPreferences: modelPreferences
        )

        // Create AI provider based on configuration
        let aiProvider = try createAIPRDBuilderProvider(configuration: configuration)

        return AppleIntelligenceClient(
            httpClient: httpClient,
            provider: aiProvider,
            configuration: configuration
        )
    }

    private func createAIPRDBuilderProvider(configuration: DomainCore.Configuration) throws -> CommonModels.AIProvider {
        let providerType = configuration.preferredProvider

        switch providerType {
        case "apple", "apple-intelligence":
            // Use Apple Intelligence Foundation Models (on-device)
            app.logger.info("🍎 Using Apple Intelligence Foundation Models for mockup analysis")
            return AIProviderImplementations.AppleProvider(mode: .hybrid)

        case "anthropic":
            guard let apiKey = configuration.anthropicAPIKey, !apiKey.isEmpty else {
                throw ConfigurationError.missingEnvironmentVariable("ANTHROPIC_API_KEY required for mockup analysis")
            }
            app.logger.info("🤖 Using Anthropic for mockup analysis")
            return AIProviderImplementations.AnthropicProvider(apiKey: apiKey)

        case "openai":
            guard let apiKey = configuration.openAIAPIKey, !apiKey.isEmpty else {
                throw ConfigurationError.missingEnvironmentVariable("OPENAI_API_KEY required for mockup analysis")
            }
            app.logger.info("🤖 Using OpenAI for mockup analysis")
            return AIProviderImplementations.OpenAIProvider(apiKey: apiKey)

        case "gemini":
            guard let apiKey = configuration.geminiAPIKey, !apiKey.isEmpty else {
                throw ConfigurationError.missingEnvironmentVariable("GEMINI_API_KEY required for mockup analysis")
            }
            app.logger.info("🤖 Using Gemini for mockup analysis")
            return AIProviderImplementations.GeminiProvider(apiKey: apiKey)

        default:
            // Default to Apple Intelligence if available, otherwise Anthropic
            #if canImport(FoundationModels)
            if #available(macOS 16.0, iOS 18.0, *) {
                app.logger.info("🍎 Unknown provider '\(providerType)', defaulting to Apple Intelligence")
                return AIProviderImplementations.AppleProvider(mode: .hybrid)
            }
            #endif

            // Fallback to Anthropic if Apple Intelligence not available
            if let apiKey = configuration.anthropicAPIKey, !apiKey.isEmpty {
                app.logger.warning("⚠️ Unknown provider '\(providerType ?? "none")', falling back to Anthropic")
                return AIProviderImplementations.AnthropicProvider(apiKey: apiKey)
            }
            throw ConfigurationError.invalidConfiguration("No valid AI provider configured for mockup analysis")
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

        guard let aiProvider = resolve(AIProviderPort.self) else {
            throw ConfigurationError.missingDependency("AIProviderPort not found")
        }

        let providerController = ProviderController(
            aiOrchestrator: aiOrchestrator,
            aiProvider: aiProvider,
            app: app
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
