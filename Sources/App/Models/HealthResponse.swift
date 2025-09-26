import Vapor

/// Response model for health check endpoint
public struct HealthResponse: Content {
    public let status: String
    public let timestamp: Date
    public let version: String
    public let environment: String

    public init(status: String, timestamp: Date, version: String, environment: String) {
        self.status = status
        self.timestamp = timestamp
        self.version = version
        self.environment = environment
    }
}