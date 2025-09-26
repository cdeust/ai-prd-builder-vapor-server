import Vapor
import Fluent
import FluentPostgresDriver
import Domain
import Application
import Infrastructure
import Presentation

/// Configure the Vapor application
public func configure(_ app: Application) throws {
    // MARK: - Database Configuration

    // Check if we should skip database setup (for testing without PostgreSQL)
    let skipDatabase = Environment.get("SKIP_DATABASE") == "true"

    if !skipDatabase {
        // Configure PostgreSQL database
        if let databaseURL = Environment.get("DATABASE_URL") {
            try app.databases.use(.postgres(url: databaseURL), as: .psql)
        } else {
            // Development database configuration
            app.databases.use(.postgres(
                hostname: Environment.get("DATABASE_HOST") ?? "localhost",
                port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? 5432,
                username: Environment.get("DATABASE_USERNAME") ?? "vapor",
                password: Environment.get("DATABASE_PASSWORD") ?? "password",
                database: Environment.get("DATABASE_NAME") ?? "ai_prd_builder"
            ), as: .psql)
        }

        // MARK: - Migrations

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
    } else {
        app.logger.warning("⚠️ Database disabled via SKIP_DATABASE=true - running without persistence")
    }

    // MARK: - Middleware Configuration

    // CORS middleware for cross-origin requests
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin]
    )
    app.middleware.use(CORSMiddleware(configuration: corsConfiguration), at: .beginning)

    // Error handling middleware
    app.middleware.use(DomainErrorMiddleware())

    // Request logging middleware
    app.middleware.use(RouteLoggingMiddleware(logLevel: .info))

    // Request timeout middleware
    app.middleware.use(TimeoutMiddleware(timeout: .seconds(30)))

    // MARK: - Content Configuration

    // Configure JSON encoding/decoding
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.keyEncodingStrategy = .convertToSnakeCase

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    decoder.keyDecodingStrategy = .convertFromSnakeCase

    ContentConfiguration.global.use(encoder: encoder, for: .json)
    ContentConfiguration.global.use(decoder: decoder, for: .json)

    // MARK: - Dependency Injection

    // Register all services with DI container
    try app.diContainer.registerServices()

    // MARK: - Routes Configuration

    try registerRoutes(app)

    // MARK: - Server Configuration

    // Configure server
    app.http.server.configuration.hostname = Environment.get("HOST") ?? "0.0.0.0"
    app.http.server.configuration.port = Environment.get("PORT").flatMap(Int.init(_:)) ?? 8080

    // Request size limits
    app.routes.defaultMaxBodySize = "10mb"

    // MARK: - Logging Configuration

    // Configure logging
    app.logger.logLevel = app.environment == .production ? .notice : .debug

    app.logger.info("🚀 AI PRD Builder server configured successfully")
    app.logger.info("📊 Database: \(app.databases.ids().first?.string ?? "Not configured")")
    app.logger.info("🌐 Server: \(app.http.server.configuration.hostname):\(app.http.server.configuration.port)")
    app.logger.info("🔧 Environment: \(app.environment.name)")
}

/// Register application routes
private func registerRoutes(_ app: Application) throws {
    // Health check endpoint
    app.get("health") { req in
        return HealthResponse(
            status: "healthy",
            timestamp: Date(),
            version: Environment.get("APP_VERSION") ?? "1.0.0",
            environment: app.environment.name
        )
    }

    // API documentation endpoint
    app.get("docs") { req in
        return req.redirect(to: "/docs/index.html")
    }

    // Serve static documentation files
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // Register PRD routes
    guard let prdController = app.diContainer.resolve(PRDController.self) else {
        throw ConfigurationError.missingDependency("PRDController")
    }

    try app.register(collection: prdController)
}

// MARK: - Response Models

private struct HealthResponse: Content {
    let status: String
    let timestamp: Date
    let version: String
    let environment: String
}

// MARK: - Custom Middleware

/// Middleware for request/response logging
private struct RouteLoggingMiddleware: AsyncMiddleware {
    let logLevel: Logger.Level

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let startTime = Date()

        // Log request
        request.logger.log(level: logLevel, "\(request.method) \(request.url.path)")

        let response = try await next.respond(to: request)

        // Log response
        let duration = Date().timeIntervalSince(startTime) * 1000 // ms
        request.logger.log(
            level: logLevel,
            "\(request.method) \(request.url.path) -> \(response.status.code) (\(String(format: "%.1f", duration))ms)"
        )

        return response
    }
}

/// Middleware for request timeout
private struct TimeoutMiddleware: AsyncMiddleware {
    let timeout: TimeAmount

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        return try await withThrowingTaskGroup(of: Response.self) { group in
            group.addTask {
                return try await next.respond(to: request)
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout.nanoseconds))
                throw Abort(.requestTimeout, reason: "Request timeout after \(timeout)")
            }

            guard let response = try await group.next() else {
                throw Abort(.internalServerError, reason: "No response received")
            }

            group.cancelAll()
            return response
        }
    }
}