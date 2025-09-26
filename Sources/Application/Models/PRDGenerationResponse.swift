import Foundation
import Domain

/// Response model for PRD generation workflow
public struct PRDGenerationResponse {
    public let status: GenerationStatus
    public let analysis: RequirementsAnalysis?
    public let document: PRDDocument?

    public init(status: GenerationStatus, analysis: RequirementsAnalysis?, document: PRDDocument?) {
        self.status = status
        self.analysis = analysis
        self.document = document
    }
}