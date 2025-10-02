import Foundation

/// DTO for linking multiple codebases to a PRD request in one operation
public struct LinkMultipleCodebasesDTO: Codable {
    public let prdRequestId: UUID
    public let codebaseIds: [UUID]

    public init(prdRequestId: UUID, codebaseIds: [UUID]) {
        self.prdRequestId = prdRequestId
        self.codebaseIds = codebaseIds
    }
}
