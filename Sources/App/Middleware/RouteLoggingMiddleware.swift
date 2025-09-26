import Vapor

/// Middleware for request/response logging
public struct RouteLoggingMiddleware: AsyncMiddleware {
    let logLevel: Logger.Level

    public init(logLevel: Logger.Level = .info) {
        self.logLevel = logLevel
    }

    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
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