import Vapor

/// Handles server configuration for the application
public final class ServerConfigurator {
    private let app: Application

    public init(app: Application) {
        self.app = app
    }

    /// Configure server settings
    public func configure() {
        configureHost()
        configureRequestLimits()
        configureLogging()
        logConfiguration()
    }

    // MARK: - Private Methods

    private func configureHost() {
        app.http.server.configuration.hostname = Environment.get("HOST") ?? "0.0.0.0"
        app.http.server.configuration.port = Environment.get("PORT").flatMap(Int.init(_:)) ?? 8080
    }

    private func configureRequestLimits() {
        // Request size limits
        app.routes.defaultMaxBodySize = "10mb"
    }

    private func configureLogging() {
        // Configure logging level based on environment
        app.logger.logLevel = app.environment == .production ? .notice : .debug
    }

    private func logConfiguration() {
        app.logger.info("🚀 AI PRD Builder server configured successfully")
        app.logger.info("📊 Database: \(app.databases.ids().first?.string ?? "Not configured")")
        app.logger.info("🌐 Server: \(app.http.server.configuration.hostname):\(app.http.server.configuration.port)")
        app.logger.info("🔧 Environment: \(app.environment.name)")
    }
}