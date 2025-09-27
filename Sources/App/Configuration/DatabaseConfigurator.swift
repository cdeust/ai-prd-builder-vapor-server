import Vapor
import Fluent
import FluentPostgresDriver
import Infrastructure

/// Handles database configuration for the application
public final class DatabaseConfigurator {
    private let app: Application

    public init(app: Application) {
        self.app = app
    }

    /// Configure database connection and migrations
    public func configure() throws {
        // Check if we should skip database setup (for testing without PostgreSQL)
        let skipDatabase = Environment.get("SKIP_DATABASE") == "true"

        if skipDatabase {
            app.logger.warning("⚠️ Database disabled via SKIP_DATABASE=true - running without persistence")
            return
        }

        // Check database type
        let databaseType = Environment.get("DATABASE_TYPE") ?? "postgresql"

        // Only configure Fluent/PostgreSQL for postgresql type
        // Supabase and MongoDB use their own clients via repositories
        if databaseType == "postgresql" {
            try configureConnection()
            try configureMigrations()
        } else {
            app.logger.info("ℹ️ Database type: \(databaseType) - using repository-based connection")
        }
    }

    // MARK: - Private Methods

    private func configureConnection() throws {
        if let databaseURL = Environment.get("DATABASE_URL") {
            try app.databases.use(.postgres(url: databaseURL), as: .psql)
        } else {
            let config = SQLPostgresConfiguration(
                hostname: Environment.get("DATABASE_HOST") ?? "localhost",
                port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? 5432,
                username: Environment.get("DATABASE_USERNAME") ?? "vapor",
                password: Environment.get("DATABASE_PASSWORD") ?? "password",
                database: Environment.get("DATABASE_NAME") ?? "ai_prd_builder",
                tls: .disable
            )
            app.databases.use(.postgres(configuration: config), as: .psql)
        }
    }

    private func configureMigrations() throws {
        // Add migrations for database schema
        app.migrations.add(CreatePRDRequest())
        app.migrations.add(CreatePRDDocument())

        // Run migrations automatically in development
        if app.environment != .production {
            do {
                try app.autoMigrate().wait()
                app.logger.info("✅ Database migrations completed successfully")
            } catch {
                app.logger.error("❌ Database migration failed: \(error)")
                app.logger.warning("⚠️ Server will continue without database - some features may be limited")
            }
        }
    }
}