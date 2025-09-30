import Foundation
import Domain

struct SupabaseMockupUploadModel: Codable {
    let id: UUID
    let prd_request_id: UUID
    let storage_path: String
    let storage_bucket: String
    let file_name: String
    let file_size: Int64
    let mime_type: String
    let uploaded_at: String
    let analysis_result: String?
    let analysis_confidence: Double?
    let is_processed: Bool
    let expires_at: String
    let created_at: String
    let updated_at: String

    static func from(domainEntity: MockupUpload) throws -> SupabaseMockupUploadModel {
        let iso8601Formatter = ISO8601DateFormatter()

        var analysisResultJSON: String?
        if let analysisResult = domainEntity.analysisResult {
            let analysisData = try JSONEncoder().encode(analysisResult)
            analysisResultJSON = String(data: analysisData, encoding: .utf8)
        }

        return SupabaseMockupUploadModel(
            id: domainEntity.id,
            prd_request_id: domainEntity.prdRequestId,
            storage_path: domainEntity.storagePath,
            storage_bucket: domainEntity.storageBucket,
            file_name: domainEntity.fileName,
            file_size: domainEntity.fileSize,
            mime_type: domainEntity.mimeType,
            uploaded_at: iso8601Formatter.string(from: domainEntity.uploadedAt),
            analysis_result: analysisResultJSON,
            analysis_confidence: domainEntity.analysisConfidence,
            is_processed: domainEntity.isProcessed,
            expires_at: iso8601Formatter.string(from: domainEntity.expiresAt),
            created_at: iso8601Formatter.string(from: domainEntity.createdAt),
            updated_at: iso8601Formatter.string(from: domainEntity.updatedAt)
        )
    }

    func toDomainEntity() throws -> MockupUpload {
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let uploadedAtDate = iso8601Formatter.date(from: uploaded_at) ??
                                    ISO8601DateFormatter().date(from: uploaded_at) else {
            throw DomainError.processingFailed("Invalid date format for uploaded_at: \(uploaded_at)")
        }

        guard let expiresAtDate = iso8601Formatter.date(from: expires_at) ??
                                  ISO8601DateFormatter().date(from: expires_at) else {
            throw DomainError.processingFailed("Invalid date format for expires_at: \(expires_at)")
        }

        guard let createdAtDate = iso8601Formatter.date(from: created_at) ??
                                  ISO8601DateFormatter().date(from: created_at) else {
            throw DomainError.processingFailed("Invalid date format for created_at: \(created_at)")
        }

        guard let updatedAtDate = iso8601Formatter.date(from: updated_at) ??
                                  ISO8601DateFormatter().date(from: updated_at) else {
            throw DomainError.processingFailed("Invalid date format for updated_at: \(updated_at)")
        }

        var analysisResult: MockupAnalysisResult?
        if let analysisResultJSON = analysis_result,
           let analysisData = analysisResultJSON.data(using: .utf8) {
            analysisResult = try? JSONDecoder().decode(MockupAnalysisResult.self, from: analysisData)
        }

        return MockupUpload(
            id: id,
            prdRequestId: prd_request_id,
            storagePath: storage_path,
            storageBucket: storage_bucket,
            fileName: file_name,
            fileSize: file_size,
            mimeType: mime_type,
            uploadedAt: uploadedAtDate,
            analysisResult: analysisResult,
            analysisConfidence: analysis_confidence,
            isProcessed: is_processed,
            expiresAt: expiresAtDate,
            createdAt: createdAtDate,
            updatedAt: updatedAtDate
        )
    }
}