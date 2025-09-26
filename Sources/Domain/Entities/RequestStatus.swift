import Foundation

public enum RequestStatus: Equatable, Sendable {
    case pending
    case processing
    case clarificationNeeded
    case completed
    case failed(reason: String)
    case cancelled

    public var rawValue: String {
        switch self {
        case .pending: return "pending"
        case .processing: return "processing"
        case .clarificationNeeded: return "clarificationNeeded"
        case .completed: return "completed"
        case .failed: return "failed"
        case .cancelled: return "cancelled"
        }
    }

    public static func from(rawValue: String) -> RequestStatus {
        switch rawValue {
        case "pending": return .pending
        case "processing": return .processing
        case "clarificationNeeded": return .clarificationNeeded
        case "completed": return .completed
        case "failed": return .failed(reason: "")
        case "cancelled": return .cancelled
        default: return .pending
        }
    }
}