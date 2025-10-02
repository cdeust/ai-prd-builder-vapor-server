import Foundation

/// Response DTO for batch linking multiple codebases to a PRD
public struct LinkMultipleCodebasesResponseDTO: Codable {
    public let success: Bool
    public let prdId: UUID
    public let linkedCodebaseIds: [UUID]
    public let failedCodebaseIds: [UUID]
    public let totalRequested: Int
    public let totalLinked: Int

    public init(
        success: Bool,
        prdId: UUID,
        linkedCodebaseIds: [UUID],
        failedCodebaseIds: [UUID],
        totalRequested: Int,
        totalLinked: Int
    ) {
        self.success = success
        self.prdId = prdId
        self.linkedCodebaseIds = linkedCodebaseIds
        self.failedCodebaseIds = failedCodebaseIds
        self.totalRequested = totalRequested
        self.totalLinked = totalLinked
    }
}
