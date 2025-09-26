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

    public init(app: Application) {
        self.app = app
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
        // HTTP client for AI providers
        let httpClient = HTTPClient(eventLoopGroupProvider: .shared(app.eventLoopGroup))
        register(httpClient, for: HTTPClient.self)

        // Register database repositories based on configuration
        try registerDatabaseRepositories(httpClient: httpClient)

        // AI Providers
        try registerAIProviders(httpClient: httpClient)
    }

    /// Register database repositories based on configuration
    private func registerDatabaseRepositories(httpClient: HTTPClient) throws {
        // Check if database should be skipped
        if Environment.get("SKIP_DATABASE") == "true" {
            registerInMemoryRepositories()
            app.logger.warning("⚠️ Using in-memory repositories (no persistence)")
            return
        }

        let databaseType = Environment.get("DATABASE_TYPE")?.lowercased() ?? "postgresql"

        switch databaseType {
        case "supabase":
            try registerSupabaseRepositories(httpClient: httpClient)
        case "mongodb", "mongo":
            try registerMongoDBRepositories()
        case "postgresql", "postgres", "fluent":
            registerFluentRepositories()
        default:
            app.logger.warning("Unknown database type: \(databaseType). Defaulting to PostgreSQL.")
            registerFluentRepositories()
        }

        app.logger.info("🗄️ Database repositories configured for: \(databaseType)")
    }

    /// Register in-memory repositories for testing without database
    private func registerInMemoryRepositories() {
        let prdRepository = InMemoryPRDRepository()
        register(prdRepository, for: PRDRepositoryProtocol.self)

        let documentRepository = InMemoryPRDDocumentRepository()
        register(documentRepository, for: PRDDocumentRepositoryProtocol.self)

        app.logger.info("💾 In-memory repositories registered (no persistence)")
    }

    /// Register Supabase repositories
    private func registerSupabaseRepositories(httpClient: HTTPClient) throws {
        guard let supabaseURL = Environment.get("SUPABASE_URL"),
              let supabaseKey = Environment.get("SUPABASE_ANON_KEY") else {
            throw ConfigurationError.invalidConfiguration("Missing SUPABASE_URL or SUPABASE_ANON_KEY")
        }

        let prdRepository = SupabasePRDRepository(
            httpClient: httpClient,
            supabaseURL: supabaseURL,
            apiKey: supabaseKey
        )
        register(prdRepository, for: PRDRepositoryProtocol.self)

        let documentRepository = SupabasePRDDocumentRepository(
            httpClient: httpClient,
            supabaseURL: supabaseURL,
            apiKey: supabaseKey
        )
        register(documentRepository, for: PRDDocumentRepositoryProtocol.self)

        app.logger.info("✅ Supabase repositories registered")
    }

    /// Register MongoDB repositories
    private func registerMongoDBRepositories() throws {
        guard let connectionString = Environment.get("MONGODB_CONNECTION_STRING") else {
            throw ConfigurationError.invalidConfiguration("Missing MONGODB_CONNECTION_STRING")
        }

        let databaseName = Environment.get("MONGODB_DATABASE") ?? "ai_prd_builder"

        do {
            let mongoManager = try MongoConnectionManager(
                connectionString: connectionString,
                databaseName: databaseName
            )

            let database = mongoManager.getDatabase()

            let prdRepository = MongoPRDRepository(database: database)
            register(prdRepository, for: PRDRepositoryProtocol.self)

            let documentRepository = MongoPRDDocumentRepository(database: database)
            register(documentRepository, for: PRDDocumentRepositoryProtocol.self)

            // Note: MongoDB indexes will be created on first use
            app.logger.info("📊 MongoDB configured - indexes will be created on first use")

            register(mongoManager, for: MongoConnectionManager.self)
            app.logger.info("✅ MongoDB repositories registered")

        } catch {
            throw ConfigurationError.invalidConfiguration("Failed to initialize MongoDB: \(error.localizedDescription)")
        }
    }

    /// Register Fluent/PostgreSQL repositories
    private func registerFluentRepositories() {
        let prdRepository = VaporPRDRepository(database: app.db)
        register(prdRepository, for: PRDRepositoryProtocol.self)

        let documentRepository = VaporPRDDocumentRepository(database: app.db)
        register(documentRepository, for: PRDDocumentRepositoryProtocol.self)

        app.logger.info("✅ PostgreSQL/Fluent repositories registered")
    }

    /// Register AI providers based on configuration
    private func registerAIProviders(httpClient: HTTPClient) throws {
        // Primary: AI Orchestrator Provider (uses complete Swift CLI system)
        do {
            let aiOrchestratorProvider = try AIOrchestratorProvider()

            // Note: AI Orchestrator will be initialized on first use
            app.logger.info("🎯 AI Orchestrator provider configured (will initialize on first use)")

            // Register immediately (availability will be checked at runtime)
            register(aiOrchestratorProvider, for: AIProviderPort.self)
            register(aiOrchestratorProvider, for: AIOrchestratorProvider.self)
            return
        } catch {
            app.logger.error("❌ Failed to initialize AI Orchestrator provider: \(error)")
        }

        // Fallback: Direct Anthropic provider only if AI Orchestrator fails
        if let anthropicKey = Environment.get("ANTHROPIC_API_KEY"), !anthropicKey.isEmpty {
            let anthropicProvider = AnthropicProvider(
                apiKey: anthropicKey,
                httpClient: httpClient,
                model: Environment.get("ANTHROPIC_MODEL") ?? "claude-3-5-sonnet-20241022"
            )

            register(anthropicProvider, for: AIProviderPort.self)
            app.logger.info("🤖 Fallback: Direct Anthropic provider registered (AI Orchestrator unavailable)")
            return
        }

        // No providers available
        app.logger.error("❌ No AI providers available. Ensure ai-orchestrator system is properly configured or set ANTHROPIC_API_KEY.")
        throw ConfigurationError.missingAIProvider
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

        // Get AI Orchestrator if available for enhanced controller features
        let aiOrchestrator = resolve(AIOrchestratorProvider.self)

        let prdController = PRDController(
            applicationService: applicationService,
            aiOrchestrator: aiOrchestrator
        )
        register(prdController, for: PRDController.self)

        if aiOrchestrator != nil {
            app.logger.info("🎛️ PRD Controller configured with AI Orchestrator integration")
        } else {
            app.logger.info("⚠️ PRD Controller configured without AI Orchestrator (fallback mode)")
        }
    }
}

// MARK: - Configuration Errors

public enum ConfigurationError: Error, LocalizedError {
    case missingAIProvider
    case missingDependency(String)
    case invalidConfiguration(String)

    public var errorDescription: String? {
        switch self {
        case .missingAIProvider:
            return "No AI providers are configured. Please set at least one API key (ANTHROPIC_API_KEY, OPENAI_API_KEY, or GEMINI_API_KEY)."
        case .missingDependency(let dependency):
            return "Missing required dependency: \(dependency)"
        case .invalidConfiguration(let details):
            return "Invalid configuration: \(details)"
        }
    }
}

// MARK: - Vapor Service Extensions

extension Application {
    private struct DIContainerKey: StorageKey {
        typealias Value = DIContainer
    }

    public var diContainer: DIContainer {
        get {
            guard let container = storage[DIContainerKey.self] else {
                let container = DIContainer(app: self)
                storage[DIContainerKey.self] = container
                return container
            }
            return container
        }
        set {
            storage[DIContainerKey.self] = newValue
        }
    }
}

extension Request {
    /// Resolve service from DI container
    public func resolve<T>(_ type: T.Type) -> T? {
        return application.diContainer.resolve(type)
    }
}