import Foundation
import Domain

/// Service responsible for managing PRD request status and tracking
public final class PRDStatusService {
    private let prdRepository: PRDRepositoryProtocol
    private let documentRepository: PRDDocumentRepositoryProtocol
    private let progressCalculator: ProgressCalculator

    public init(
        prdRepository: PRDRepositoryProtocol,
        documentRepository: PRDDocumentRepositoryProtocol
    ) {
        self.prdRepository = prdRepository
        self.documentRepository = documentRepository
        self.progressCalculator = ProgressCalculator()
    }

    /// Get PRD generation status
    public func getGenerationStatus(requestId: UUID) async throws -> GenerationStatusResponse {
        guard let request = try await prdRepository.findById(requestId) else {
            throw DomainError.notFound("PRD request with ID \(requestId)")
        }

        let document = try await documentRepository.findByRequestId(requestId)
        let progress = progressCalculator.calculateProgress(for: request.status)

        return GenerationStatusResponse(
            requestId: requestId,
            status: request.status,
            progress: progress,
            document: document,
            createdAt: request.createdAt,
            updatedAt: Date(), // TODO: Track actual update time
            completedAt: nil // TODO: Track completion time when status is completed
        )
    }

    /// List PRD requests for a user
    public func listPRDRequests(
        for requesterId: String,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> [PRDRequestSummary] {
        let requests = try await prdRepository.findByRequesterId(requesterId, limit: limit, offset: offset)

        return requests.map { request in
            PRDRequestSummary(
                id: request.id,
                title: request.title,
                status: request.status,
                priority: request.priority,
                createdAt: request.createdAt,
                completedAt: nil // TODO: Track completion time when status is completed
            )
        }
    }
}