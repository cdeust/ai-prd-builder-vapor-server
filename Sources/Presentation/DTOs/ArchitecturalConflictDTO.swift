import Foundation
import Vapor

public struct ArchitecturalConflictDTO: Content {
    public let requirement1: String
    public let requirement2: String
    public let conflictReason: String
    public let severity: String
    public let resolution: String

    public init(
        requirement1: String,
        requirement2: String,
        conflictReason: String,
        severity: String,
        resolution: String
    ) {
        self.requirement1 = requirement1
        self.requirement2 = requirement2
        self.conflictReason = conflictReason
        self.severity = severity
        self.resolution = resolution
    }
}
