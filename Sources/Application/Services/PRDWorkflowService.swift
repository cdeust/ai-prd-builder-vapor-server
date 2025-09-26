import Foundation
import Domain

/// Service responsible for coordinating PRD generation workflow
public final class PRDWorkflowService {
    private let generatePRDUseCase: GeneratePRDUseCase
    private let analyzeRequirementsUseCase: AnalyzeRequirementsUseCase
    private let confidenceThreshold: Double

    public init(
        generatePRDUseCase: GeneratePRDUseCase,
        analyzeRequirementsUseCase: AnalyzeRequirementsUseCase,
        confidenceThreshold: Double = 70.0
    ) {
        self.generatePRDUseCase = generatePRDUseCase
        self.analyzeRequirementsUseCase = analyzeRequirementsUseCase
        self.confidenceThreshold = confidenceThreshold
    }

    /// Complete PRD generation workflow with analysis
    public func generatePRDWithAnalysis(_ command: GeneratePRDCommand) async throws -> PRDGenerationResponse {
        // 1. Analyze requirements first
        let analysis = try await analyzeRequirementsUseCase.execute(
            command.description,
            mockupSources: command.mockupSources
        )

        // 2. If confidence is too low, return analysis for clarification
        if analysis.confidence < confidenceThreshold {
            return PRDGenerationResponse(
                status: .needsClarification,
                analysis: analysis,
                document: nil
            )
        }

        // 3. Generate PRD if confidence is sufficient
        let document = try await generatePRDUseCase.execute(command)

        return PRDGenerationResponse(
            status: .completed,
            analysis: analysis,
            document: document
        )
    }
}