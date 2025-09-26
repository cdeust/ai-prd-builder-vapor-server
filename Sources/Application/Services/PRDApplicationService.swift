import Foundation
import Domain

/// Application service that coordinates multiple use cases
/// Provides higher-level business operations for the presentation layer
public final class PRDApplicationService {
    private let generatePRDUseCase: GeneratePRDUseCase
    private let analyzeRequirementsUseCase: AnalyzeRequirementsUseCase
    private let prdRepository: PRDRepositoryProtocol
    private let documentRepository: PRDDocumentRepositoryProtocol
    private let aiProvider: AIProviderPort

    public init(
        generatePRDUseCase: GeneratePRDUseCase,
        analyzeRequirementsUseCase: AnalyzeRequirementsUseCase,
        prdRepository: PRDRepositoryProtocol,
        documentRepository: PRDDocumentRepositoryProtocol,
        aiProvider: AIProviderPort
    ) {
        self.generatePRDUseCase = generatePRDUseCase
        self.analyzeRequirementsUseCase = analyzeRequirementsUseCase
        self.prdRepository = prdRepository
        self.documentRepository = documentRepository
        self.aiProvider = aiProvider
    }

    /// Get the AI provider for direct usage
    public func getAIProvider() -> AIProviderPort {
        return aiProvider
    }

    /// Complete PRD generation workflow with analysis
    public func generatePRDWithAnalysis(_ command: GeneratePRDCommand) async throws -> PRDGenerationResponse {
        // 1. Analyze requirements first
        let analysis = try await analyzeRequirementsUseCase.execute(
            command.description,
            mockupSources: command.mockupSources
        )

        // 2. If confidence is too low, return analysis for clarification
        if analysis.confidence < 70 {
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

    /// Get PRD generation status
    public func getGenerationStatus(requestId: UUID) async throws -> GenerationStatusResponse {
        guard let request = try await prdRepository.findById(requestId) else {
            throw DomainError.notFound("PRD request with ID \(requestId)")
        }

        let document = try await documentRepository.findByRequestId(requestId)

        return GenerationStatusResponse(
            requestId: requestId,
            status: request.status,
            progress: calculateProgress(request.status),
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

    /// Export PRD document in different formats
    public func exportPRD(documentId: UUID, format: DocumentFormat) async throws -> ExportResult {
        guard let document = try await documentRepository.findById(documentId) else {
            throw DomainError.notFound("PRD document with ID \(documentId)")
        }

        // Export logic would be implemented here
        // For now, return the content as-is
        return ExportResult(
            format: format,
            content: formatContent(document.content, for: format),
            filename: generateFilename(document.title, format: format),
            mimeType: getMimeType(for: format)
        )
    }

    // MARK: - Private Helper Methods

    /// Calculate progress percentage based on status
    private func calculateProgress(_ status: RequestStatus) -> Int {
        switch status {
        case .pending:
            return 0
        case .processing:
            return 50
        case .clarificationNeeded:
            return 25
        case .completed:
            return 100
        case .failed(_):
            return 0
        case .cancelled:
            return 0
        }
    }

    /// Format content for export
    private func formatContent(_ content: String, for format: DocumentFormat) -> String {
        switch format {
        case .markdown:
            return content
        case .html:
            return convertMarkdownToHTML(content)
        case .json:
            return wrapInJSON(content)
        case .pdf, .docx:
            return content // These would need specialized formatting
        }
    }

    /// Convert markdown to HTML
    private func convertMarkdownToHTML(_ markdown: String) -> String {
        // Simple conversion - in real implementation, use a proper markdown parser
        return "<html><body><pre>\(markdown)</pre></body></html>"
    }

    /// Wrap content in JSON structure
    private func wrapInJSON(_ content: String) -> String {
        let jsonData = [
            "content": content,
            "format": "markdown",
            "generatedAt": ISO8601DateFormatter().string(from: Date())
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: jsonData, options: .prettyPrinted),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "{\"content\": \"\(content)\"}"
        }

        return jsonString
    }

    /// Generate filename for export
    private func generateFilename(_ title: String, format: DocumentFormat) -> String {
        let sanitizedTitle = title.replacingOccurrences(of: "[^a-zA-Z0-9-_]", with: "_", options: .regularExpression)
        let timestamp = DateFormatter().string(from: Date())
        return "\(sanitizedTitle)_\(timestamp).\(format.rawValue)"
    }

    /// Get MIME type for format
    private func getMimeType(for format: DocumentFormat) -> String {
        switch format {
        case .markdown:
            return "text/markdown"
        case .html:
            return "text/html"
        case .pdf:
            return "application/pdf"
        case .docx:
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case .json:
            return "application/json"
        }
    }
}

// MARK: - Response Models

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

public enum GenerationStatus: String, CaseIterable {
    case needsClarification = "needs_clarification"
    case completed = "completed"
    case failed = "failed"
}

public struct GenerationStatusResponse {
    public let requestId: UUID
    public let status: RequestStatus
    public let progress: Int
    public let document: PRDDocument?
    public let createdAt: Date
    public let updatedAt: Date
    public let completedAt: Date?

    public init(
        requestId: UUID,
        status: RequestStatus,
        progress: Int,
        document: PRDDocument?,
        createdAt: Date,
        updatedAt: Date,
        completedAt: Date?
    ) {
        self.requestId = requestId
        self.status = status
        self.progress = progress
        self.document = document
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
    }
}

public struct PRDRequestSummary {
    public let id: UUID
    public let title: String
    public let status: RequestStatus
    public let priority: Priority
    public let createdAt: Date
    public let completedAt: Date?

    public init(
        id: UUID,
        title: String,
        status: RequestStatus,
        priority: Priority,
        createdAt: Date,
        completedAt: Date?
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.priority = priority
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}

public struct ExportResult {
    public let format: DocumentFormat
    public let content: String
    public let filename: String
    public let mimeType: String

    public init(format: DocumentFormat, content: String, filename: String, mimeType: String) {
        self.format = format
        self.content = content
        self.filename = filename
        self.mimeType = mimeType
    }
}