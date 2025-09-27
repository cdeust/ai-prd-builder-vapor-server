import Foundation
import Domain

/// Service responsible for coordinating PRD generation workflow
public final class PRDWorkflowService {
    private let generatePRDUseCase: GeneratePRDUseCase
    private let analyzeRequirementsUseCase: AnalyzeRequirementsUseCase
    private let prdRepository: PRDRepositoryProtocol
    private let confidenceThreshold: Double

    public init(
        generatePRDUseCase: GeneratePRDUseCase,
        analyzeRequirementsUseCase: AnalyzeRequirementsUseCase,
        prdRepository: PRDRepositoryProtocol,
        confidenceThreshold: Double = 70.0
    ) {
        self.generatePRDUseCase = generatePRDUseCase
        self.analyzeRequirementsUseCase = analyzeRequirementsUseCase
        self.prdRepository = prdRepository
        self.confidenceThreshold = confidenceThreshold
    }

    /// Complete PRD generation workflow with analysis
    public func generatePRDWithAnalysis(_ command: GeneratePRDCommand) async throws -> PRDGenerationResponse {
        // 1. Create and save PRD request immediately to track it
        let requester = Requester(
            id: command.requester?.id ?? "anonymous",
            email: command.requester?.email
        )
        let request = PRDRequest(
            id: command.requestId,
            title: command.title,
            description: command.description,
            mockupSources: command.mockupSources,
            priority: command.priority,
            requester: requester,
            metadata: RequestMetadata(),
            createdAt: Date(),
            status: .pending
        )

        try request.validate()
        _ = try await prdRepository.save(request)

        // 2. Analyze requirements
        let analysis = try await analyzeRequirementsUseCase.execute(
            command.description,
            mockupSources: command.mockupSources
        )

        // 3. If confidence is too low, return analysis for clarification
        if analysis.confidence < confidenceThreshold {
            return PRDGenerationResponse(
                status: .needsClarification,
                analysis: analysis,
                document: nil
            )
        }

        // 4. Generate PRD if confidence is sufficient
        let document = try await generatePRDUseCase.execute(command)

        return PRDGenerationResponse(
            status: .completed,
            analysis: analysis,
            document: document
        )
    }
}