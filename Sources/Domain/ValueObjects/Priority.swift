import Foundation

/// Value object representing priority levels
public enum Priority: String, CaseIterable, Sendable, Codable {
    case low
    case medium
    case high
    case critical

    /// Business rule: Critical priority has special handling
    public var requiresImmediateProcessing: Bool {
        self == .critical
    }

    /// SLA in hours based on priority
    public var slaHours: Int {
        switch self {
        case .critical: return 2
        case .high: return 8
        case .medium: return 24
        case .low: return 72
        }
    }

    /// Maximum retries allowed based on priority
    public var maxRetries: Int {
        switch self {
        case .critical: return 5
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }
}