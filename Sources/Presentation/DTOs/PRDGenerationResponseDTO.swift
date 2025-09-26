import Foundation
import Vapor

/// DTO for PRD generation responses
public struct PRDGenerationResponseDTO: Content {
    public let requestId: UUID
    public let status: String
    public let analysis: RequirementsAnalysisDTO?
    public let document: PRDDocumentDTO?
    public let message: String

    public init(
        requestId: UUID,
        status: String,
        analysis: RequirementsAnalysisDTO? = nil,
        document: PRDDocumentDTO? = nil,
        message: String
    ) {
        self.requestId = requestId
        self.status = status
        self.analysis = analysis
        self.document = document
        self.message = message
    }
}
