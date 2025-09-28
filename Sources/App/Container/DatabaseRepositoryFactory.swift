import Foundation
import Vapor
import AsyncHTTPClient
import Domain
import Infrastructure

/// Factory responsible for creating database repositories based on configuration
public final class DatabaseRepositoryFactory {
    private let app: Application
    private let httpClient: HTTPClient

    public init(app: Application, httpClient: HTTPClient) {
        self.app = app
        self.httpClient = httpClient
    }

    /// Create repositories based on configuration
    public func createRepositories() throws -> (prd: PRDRepositoryProtocol, document: PRDDocumentRepositoryProtocol) {
        // Check if database should be skipped
        if Environment.get("SKIP_DATABASE") == "true" {
            app.logger.warning("⚠️ Using in-memory repositories (no persistence)")
            return createInMemoryRepositories()
        }

        let databaseType = Environment.get("DATABASE_TYPE")?.lowercased() ?? "postgresql"

        let repositories: (prd: PRDRepositoryProtocol, document: PRDDocumentRepositoryProtocol)

        switch databaseType {
        case "supabase":
            repositories = try createSupabaseRepositories()
        case "mongodb", "mongo":
            repositories = try createMongoDBRepositories()
        case "postgresql", "postgres", "fluent":
            repositories = createFluentRepositories()
        default:
            app.logger.warning("Unknown database type: \(databaseType). Defaulting to PostgreSQL.")
            repositories = createFluentRepositories()
        }

        app.logger.info("🗄️ Database repositories configured for: \(databaseType)")
        return repositories
    }

    // MARK: - Private Methods

    private func createInMemoryRepositories() -> (prd: PRDRepositoryProtocol, document: PRDDocumentRepositoryProtocol) {
        let prdRepository = InMemoryPRDRepository()
        let documentRepository = InMemoryPRDDocumentRepository()
        app.logger.info("💾 In-memory repositories registered (no persistence)")
        return (prdRepository, documentRepository)
    }

    private func createSupabaseRepositories() throws -> (prd: PRDRepositoryProtocol, document: PRDDocumentRepositoryProtocol) {
        guard let supabaseURL = Environment.get("SUPABASE_URL"),
              let supabaseKey = Environment.get("SUPABASE_ANON_KEY") else {
            throw ConfigurationError.invalidConfiguration("Missing SUPABASE_URL or SUPABASE_ANON_KEY")
        }

        let schema = "public"

        let prdRepository = SupabasePRDRepository(
            httpClient: httpClient,
            supabaseURL: supabaseURL,
            apiKey: supabaseKey,
            schema: schema
        )

        let documentRepository = SupabasePRDDocumentRepository(
            httpClient: httpClient,
            supabaseURL: supabaseURL,
            apiKey: supabaseKey,
            schema: schema
        )

        app.logger.info("✅ Supabase repositories registered (schema: \(schema))")
        return (prdRepository, documentRepository)
    }

    private func createMongoDBRepositories() throws -> (prd: PRDRepositoryProtocol, document: PRDDocumentRepositoryProtocol) {
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
            let documentRepository = MongoPRDDocumentRepository(database: database)

            // Store mongo manager reference if needed
            // Note: MongoDB indexes will be created on first use
            app.logger.info("📊 MongoDB configured - indexes will be created on first use")
            app.logger.info("✅ MongoDB repositories registered")

            return (prdRepository, documentRepository)
        } catch {
            throw ConfigurationError.invalidConfiguration("Failed to initialize MongoDB: \(error.localizedDescription)")
        }
    }

    private func createFluentRepositories() -> (prd: PRDRepositoryProtocol, document: PRDDocumentRepositoryProtocol) {
        let prdRepository = VaporPRDRepository(database: app.db)
        let documentRepository = VaporPRDDocumentRepository(database: app.db)
        app.logger.info("✅ PostgreSQL/Fluent repositories registered")
        return (prdRepository, documentRepository)
    }
}
