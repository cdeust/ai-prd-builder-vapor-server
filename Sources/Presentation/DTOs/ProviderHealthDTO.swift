import Foundation
import Vapor

/// DTO for individual provider health
public struct ProviderHealthDTO: Content {
    public let isHealthy: Bool
    public let lastChecked: Date
    public let failureCount: Int
    public let avgResponseTime: TimeInterval

    public init(isHealthy: Bool, lastChecked: Date, failureCount: Int, avgResponseTime: TimeInterval) {
        self.isHealthy = isHealthy
        self.lastChecked = lastChecked
        self.failureCount = failureCount
        self.avgResponseTime = avgResponseTime
    }
}