import Foundation

/// Domain entity representing a conflict between architectural requirements
public struct DomainArchitecturalConflict: Sendable {
    public let requirement1: String
    public let requirement2: String
    public let conflictReason: String
    public let severity: Severity
    public let resolution: String

    public enum Severity: String, Sendable {
        case critical = "critical"
        case high = "high"
        case medium = "medium"
        case low = "low"
    }

    public init(
        requirement1: String,
        requirement2: String,
        conflictReason: String,
        severity: Severity,
        resolution: String
    ) {
        self.requirement1 = requirement1
        self.requirement2 = requirement2
        self.conflictReason = conflictReason
        self.severity = severity
        self.resolution = resolution
    }
}
