import Foundation
import Domain

public final class MockupProcessingService: Sendable {
    private let storagePort: MockupStoragePort
    private let analysisPort: MockupAnalysisPort
    private let uploadRepository: MockupUploadRepositoryProtocol
    private let prdRepository: PRDRepositoryProtocol

    public init(
        storagePort: MockupStoragePort,
        analysisPort: MockupAnalysisPort,
        uploadRepository: MockupUploadRepositoryProtocol,
        prdRepository: PRDRepositoryProtocol
    ) {
        self.storagePort = storagePort
        self.analysisPort = analysisPort
        self.uploadRepository = uploadRepository
        self.prdRepository = prdRepository
    }

    /// Upload and process a mockup image
    /// Requires PRD request to exist first for optimal contextual analysis
    public func uploadMockup(
        data: Data,
        fileName: String,
        mimeType: String,
        requestId: UUID
    ) async throws -> MockupUpload {
        // Enforce Request-First workflow for best analysis quality
        // PRD request must exist to provide context (title, description) for AI analysis
        guard let request = try await prdRepository.findById(requestId) else {
            throw DomainError.notFound(
                "PRD request not found: \(requestId). " +
                "Please create a PRD request first using POST /api/v1/prd/requests " +
                "to enable contextual mockup analysis with higher confidence scores."
            )
        }

        let currentCount = try await uploadRepository.countByRequestId(requestId)
        guard currentCount < 20 else {
            throw DomainError.validation("Maximum 20 mockups allowed per request")
        }

        let storagePath = try await storagePort.upload(
            data: data,
            fileName: fileName,
            requestId: requestId,
            mimeType: mimeType
        )

        let upload = MockupUpload(
            prdRequestId: requestId,
            storagePath: storagePath,
            fileName: fileName,
            fileSize: Int64(data.count),
            mimeType: mimeType
        )

        try upload.validate()
        let savedUpload = try await uploadRepository.save(upload)

        // Analyze immediately (blocking) - client will show waiting screen
        do {
            try await analyzeAndUpdateMockup(uploadId: savedUpload.id, request: request)
            print("[MockupProcessingService] ✅ Mockup analysis completed: \(savedUpload.id)")

            // Fetch updated upload with analysis results
            guard let analyzedUpload = try await uploadRepository.findById(savedUpload.id) else {
                return savedUpload
            }
            return analyzedUpload
        } catch {
            print("[MockupProcessingService] ❌ Mockup analysis failed: \(savedUpload.id) - \(error)")
            throw error
        }
    }

    /// Analyze a mockup and update with results
    public func analyzeAndUpdateMockup(
        uploadId: UUID,
        request: PRDRequest
    ) async throws {
        guard let upload = try await uploadRepository.findById(uploadId) else {
            throw DomainError.notFound("Mockup upload not found: \(uploadId)")
        }

        let signedURL = try await storagePort.generateSignedURL(
            path: upload.storagePath,
            expiresIn: 3600
        )

        let existingAnalyses = try await uploadRepository.findByRequestId(request.id)
            .compactMap { $0.analysisResult }

        let context = MockupAnalysisContext(
            requestTitle: request.title,
            requestDescription: request.description,
            existingMockupAnalyses: existingAnalyses
        )

        let (analysisResult, confidence) = try await analysisPort.analyzeMockup(
            imageURL: signedURL,
            context: context
        )

        let updatedUpload = upload.withAnalysis(result: analysisResult, confidence: confidence)
        _ = try await uploadRepository.update(updatedUpload)

        print("[MockupProcessingService] Mockup analyzed: \(uploadId) with confidence: \(confidence)")
    }

    /// Get all mockups for a request
    public func getMockupsForRequest(requestId: UUID) async throws -> [MockupUpload] {
        return try await uploadRepository.findByRequestId(requestId)
    }

    /// Get mockup with temporary access URL
    public func getMockupWithURL(uploadId: UUID, expiresIn: Int = 3600) async throws -> (upload: MockupUpload, url: String) {
        guard let upload = try await uploadRepository.findById(uploadId) else {
            throw DomainError.notFound("Mockup upload not found: \(uploadId)")
        }

        let signedURL = try await storagePort.generateSignedURL(
            path: upload.storagePath,
            expiresIn: expiresIn
        )

        return (upload, signedURL)
    }

    /// Delete a specific mockup
    public func deleteMockup(uploadId: UUID) async throws {
        guard let upload = try await uploadRepository.findById(uploadId) else {
            throw DomainError.notFound("Mockup upload not found: \(uploadId)")
        }

        try await storagePort.delete(path: upload.storagePath)
        try await uploadRepository.delete(uploadId)

        print("[MockupProcessingService] Mockup deleted: \(uploadId)")
    }

    /// Process all unprocessed mockups for a request
    public func processUnanalyzedMockups(requestId: UUID) async throws {
        guard let request = try await prdRepository.findById(requestId) else {
            throw DomainError.notFound("PRD request not found: \(requestId)")
        }

        let unprocessed = try await uploadRepository.findUnprocessedByRequestId(requestId)
            .filter { $0.analysisResult == nil }

        print("[MockupProcessingService] Processing \(unprocessed.count) unanalyzed mockups")

        for upload in unprocessed {
            try await analyzeAndUpdateMockup(uploadId: upload.id, request: request)
        }
    }

    /// Mark mockups as processed after PRD generation
    public func markMockupsAsProcessed(requestId: UUID) async throws {
        try await uploadRepository.markAsProcessed(requestId: requestId)
        print("[MockupProcessingService] Marked mockups as processed for request: \(requestId)")
    }

    /// Get consolidated analysis from all mockups
    public func getConsolidatedAnalysis(requestId: UUID) async throws -> ConsolidatedMockupAnalysis {
        let uploads = try await uploadRepository.findByRequestId(requestId)
        let analyses = uploads.compactMap { $0.analysisResult }

        guard !analyses.isEmpty else {
            throw DomainError.validation("No analyzed mockups found for request")
        }

        let allUIElements = analyses.flatMap { $0.uiElements }
        let allUserFlows = analyses.flatMap { $0.inferredUserFlows }
        let allBusinessLogic = analyses.flatMap { $0.businessLogicInferences }
        let allExtractedText = analyses.flatMap { $0.extractedText }

        let averageConfidence = uploads.compactMap { $0.analysisConfidence }.reduce(0.0, +) / Double(uploads.count)

        return ConsolidatedMockupAnalysis(
            totalMockups: uploads.count,
            analyzedMockups: analyses.count,
            uiElements: Array(Set(allUIElements.map { $0.type.rawValue })),
            userFlows: allUserFlows,
            businessLogicInferences: allBusinessLogic,
            extractedText: allExtractedText.map { $0.text },
            averageConfidence: averageConfidence
        )
    }
}


