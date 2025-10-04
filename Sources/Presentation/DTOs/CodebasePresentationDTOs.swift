import Vapor
import Foundation
import Application

// Import specific DTOs from Application layer
import struct Application.LinkCodebaseDTO
import struct Application.LinkMultipleCodebasesDTO
import struct Application.LinkMultipleCodebasesResponseDTO

// MARK: - Presentation Layer DTOs (Vapor Content Conformance)

extension CreateCodebaseDTO: Content, @unchecked Sendable {}
extension CodebaseResponseDTO: Content, @unchecked Sendable {}
extension AddFileDTO: Content, @unchecked Sendable {}
extension CodeFileResponseDTO: Content, @unchecked Sendable {}
extension SearchCodebaseDTO: Content, @unchecked Sendable {}
extension SearchResultDTO: Content, @unchecked Sendable {}
extension LinkCodebaseDTO: Content, @unchecked Sendable {}
extension LinkMultipleCodebasesDTO: Content, @unchecked Sendable {}
extension LinkMultipleCodebasesResponseDTO: Content, @unchecked Sendable {}

/// Response DTO for successful codebase-PRD link
public struct LinkCodebaseResponseDTO: Content {
    public let success: Bool
    public let prdId: UUID
    public let codebaseId: UUID

    public init(success: Bool, prdId: UUID, codebaseId: UUID) {
        self.success = success
        self.prdId = prdId
        self.codebaseId = codebaseId
    }
}
