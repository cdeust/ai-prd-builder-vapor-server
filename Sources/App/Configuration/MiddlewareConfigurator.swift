import Vapor
import Infrastructure

/// Handles middleware configuration for the application
public final class MiddlewareConfigurator {
    private let app: Application

    public init(app: Application) {
        self.app = app
    }

    /// Configure all middleware for the application
    public func configure() {
        configureCORS()
        configureErrorHandling()
        configureLogging()
        configureTimeout()
        configureFileServing()
        configureSessions()
    }

    // MARK: - Private Methods

    private func configureCORS() {
        let corsConfiguration = CORSMiddleware.Configuration(
            allowedOrigin: .all,
            allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
            allowedHeaders: [
                .accept, .authorization, .contentType, .origin,
                .xRequestedWith, .userAgent, .accessControlAllowOrigin,
                HTTPHeaders.Name("Upgrade"), HTTPHeaders.Name("Connection"),
                HTTPHeaders.Name("Sec-WebSocket-Key"), HTTPHeaders.Name("Sec-WebSocket-Version"),
                HTTPHeaders.Name("Sec-WebSocket-Extensions")
            ]
        )
        app.middleware.use(CORSMiddleware(configuration: corsConfiguration), at: .beginning)
    }

    private func configureErrorHandling() {
        app.middleware.use(ErrorMiddleware.default(environment: app.environment))
    }

    private func configureLogging() {
        app.middleware.use(RouteLoggingMiddleware(logLevel: .info))
    }

    private func configureTimeout() {
        app.middleware.use(TimeoutMiddleware(timeoutSeconds: 30))
    }

    private func configureFileServing() {
        // Serve static documentation files
        app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    }

    private func configureSessions() {
        // Sessions middleware must be added after CORS but before routes
        app.middleware.use(app.sessions.middleware)
    }
}
