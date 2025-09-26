import Foundation
import Domain

/// Service responsible for exporting PRD documents in various formats
public final class PRDExportService {
    private let documentRepository: PRDDocumentRepositoryProtocol
    private let documentFormatter: DocumentFormatter

    public init(documentRepository: PRDDocumentRepositoryProtocol) {
        self.documentRepository = documentRepository
        self.documentFormatter = DocumentFormatter()
    }

    /// Export PRD document in specified format
    public func exportPRD(documentId: UUID, format: DocumentFormat) async throws -> ExportResult {
        guard let document = try await documentRepository.findById(documentId) else {
            throw DomainError.notFound("PRD document with ID \(documentId)")
        }

        let formattedContent = documentFormatter.formatContent(document.content, for: format)
        let filename = documentFormatter.generateFilename(document.title, format: format)
        let mimeType = documentFormatter.getMimeType(for: format)

        return ExportResult(
            format: format,
            content: formattedContent,
            filename: filename,
            mimeType: mimeType
        )
    }

    /// Export PRD document by request ID
    public func exportPRDByRequestId(requestId: UUID, format: DocumentFormat) async throws -> ExportResult {
        guard let document = try await documentRepository.findByRequestId(requestId) else {
            throw DomainError.notFound("PRD document for request ID \(requestId)")
        }

        let formattedContent = documentFormatter.formatContent(document.content, for: format)
        let filename = documentFormatter.generateFilename(document.title, format: format)
        let mimeType = documentFormatter.getMimeType(for: format)

        return ExportResult(
            format: format,
            content: formattedContent,
            filename: filename,
            mimeType: mimeType
        )
    }
}