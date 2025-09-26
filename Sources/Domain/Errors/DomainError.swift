import Foundation

/// Domain-specific errors
public enum DomainError: Error, Equatable {
    case validation(String)
    case notFound(String)
    case businessRule(String)
    case conflict(String)
    case unauthorized(String)
    case processingFailed(String)
}

extension DomainError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .validation(let message):
            return "Validation Error: \(message)"
        case .notFound(let message):
            return "Not Found: \(message)"
        case .businessRule(let message):
            return "Business Rule Violation: \(message)"
        case .conflict(let message):
            return "Conflict: \(message)"
        case .unauthorized(let message):
            return "Unauthorized: \(message)"
        case .processingFailed(let message):
            return "Processing Failed: \(message)"
        }
    }
}