import Foundation
import Domain

struct AIProviderErrorConverter {
    func convert(_ error: Error) -> DomainError {
        if error.localizedDescription.contains("configuration") {
            return .validation("Invalid configuration: \(error.localizedDescription)")
        }

        if error.localizedDescription.contains("network") ||
           error.localizedDescription.contains("connection") {
            return .processingFailed("Network error: \(error.localizedDescription)")
        }

        if error.localizedDescription.contains("API key") {
            return .validation("Invalid or missing API key")
        }

        if error.localizedDescription.contains("rate limit") {
            return .processingFailed("Rate limit exceeded")
        }

        return .processingFailed("AI Orchestrator error: \(error.localizedDescription)")
    }
}