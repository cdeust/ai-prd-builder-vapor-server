import Foundation

public struct MockupUpload: Sendable {
    public let id: UUID
    public let prdRequestId: UUID
    public let storagePath: String
    public let storageBucket: String
    public let fileName: String
    public let fileSize: Int64
    public let mimeType: String
    public let uploadedAt: Date
    public let analysisResult: MockupAnalysisResult?
    public let analysisConfidence: Double?
    public let isProcessed: Bool
    public let expiresAt: Date
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID = UUID(),
        prdRequestId: UUID,
        storagePath: String,
        storageBucket: String = "prd-mockups",
        fileName: String,
        fileSize: Int64,
        mimeType: String,
        uploadedAt: Date = Date(),
        analysisResult: MockupAnalysisResult? = nil,
        analysisConfidence: Double? = nil,
        isProcessed: Bool = false,
        expiresAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.prdRequestId = prdRequestId
        self.storagePath = storagePath
        self.storageBucket = storageBucket
        self.fileName = fileName
        self.fileSize = fileSize
        self.mimeType = mimeType
        self.uploadedAt = uploadedAt
        self.analysisResult = analysisResult
        self.analysisConfidence = analysisConfidence
        self.isProcessed = isProcessed
        self.expiresAt = expiresAt ?? Date().addingTimeInterval(30 * 24 * 60 * 60)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var isExpired: Bool {
        return expiresAt < Date()
    }

    public var storageURL: String {
        return "\(storageBucket)/\(storagePath)"
    }
}

extension MockupUpload {
    public func validate() throws {
        guard !storagePath.isEmpty else {
            throw DomainError.validation("Storage path is required")
        }

        guard !fileName.isEmpty else {
            throw DomainError.validation("File name is required")
        }

        guard fileSize > 0 else {
            throw DomainError.validation("File size must be greater than 0")
        }

        guard fileSize <= 10 * 1024 * 1024 else {
            throw DomainError.validation("File size must not exceed 10MB")
        }

        guard mimeType.hasPrefix("image/") else {
            throw DomainError.validation("Only image files are supported")
        }

        if let confidence = analysisConfidence {
            guard confidence >= 0.0 && confidence <= 1.0 else {
                throw DomainError.validation("Analysis confidence must be between 0.0 and 1.0")
            }
        }
    }

    public func withAnalysis(result: MockupAnalysisResult, confidence: Double) -> MockupUpload {
        MockupUpload(
            id: id,
            prdRequestId: prdRequestId,
            storagePath: storagePath,
            storageBucket: storageBucket,
            fileName: fileName,
            fileSize: fileSize,
            mimeType: mimeType,
            uploadedAt: uploadedAt,
            analysisResult: result,
            analysisConfidence: confidence,
            isProcessed: isProcessed,
            expiresAt: expiresAt,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }

    public func markAsProcessed() -> MockupUpload {
        let newExpiresAt = Date().addingTimeInterval(7 * 24 * 60 * 60)
        return MockupUpload(
            id: id,
            prdRequestId: prdRequestId,
            storagePath: storagePath,
            storageBucket: storageBucket,
            fileName: fileName,
            fileSize: fileSize,
            mimeType: mimeType,
            uploadedAt: uploadedAt,
            analysisResult: analysisResult,
            analysisConfidence: analysisConfidence,
            isProcessed: true,
            expiresAt: newExpiresAt,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
}