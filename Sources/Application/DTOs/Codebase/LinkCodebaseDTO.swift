import Foundation

/// DTO for linking a codebase to a PRD request
public struct LinkCodebaseDTO: Codable {
    public let prdRequestId: UUID

    public init(prdRequestId: UUID) {
        self.prdRequestId = prdRequestId
    }
}
