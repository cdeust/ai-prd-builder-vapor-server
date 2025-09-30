import Vapor
import Domain
import Application

public final class MockupController: RouteCollection, @unchecked Sendable {
    private let mockupProcessingService: MockupProcessingService
    private let mockupCleanupService: MockupCleanupService

    public init(
        mockupProcessingService: MockupProcessingService,
        mockupCleanupService: MockupCleanupService
    ) {
        self.mockupProcessingService = mockupProcessingService
        self.mockupCleanupService = mockupCleanupService
    }

    public func boot(routes: RoutesBuilder) throws {
        let mockups = routes.grouped("api", "v1", "mockups")

        // Upload and management
        mockups.post("upload", use: uploadMockup)
        mockups.get(":uploadId", use: getMockup)
        mockups.delete(":uploadId", use: deleteMockup)

        // Request-specific operations
        mockups.get("request", ":requestId", use: listMockupsForRequest)
        mockups.get("request", ":requestId", "analysis", use: getConsolidatedAnalysis)
        mockups.post("request", ":requestId", "analyze", use: analyzeUnprocessedMockups)

        // Admin/cleanup operations
        mockups.post("cleanup", "expired", use: cleanupExpired)
        mockups.post("cleanup", "request", ":requestId", use: cleanupForRequest)
        mockups.get("storage", "stats", use: getStorageStats)
    }

    // MARK: - Upload and Management

    func uploadMockup(req: Request) async throws -> MockupUploadResponseDTO {
        let uploadRequest = try req.content.decode(MockupUploadRequestDTO.self)

        guard let requestId = UUID(uuidString: uploadRequest.requestId) else {
            throw Abort(.badRequest, reason: "Invalid request ID")
        }

        guard let imageData = Data(base64Encoded: uploadRequest.imageData) else {
            throw Abort(.badRequest, reason: "Invalid base64 image data")
        }

        let upload = try await mockupProcessingService.uploadMockup(
            data: imageData,
            fileName: uploadRequest.fileName,
            mimeType: uploadRequest.mimeType,
            requestId: requestId
        )

        return MockupUploadResponseDTO(
            id: upload.id.uuidString,
            requestId: upload.prdRequestId.uuidString,
            fileName: upload.fileName,
            fileSize: upload.fileSize,
            mimeType: upload.mimeType,
            uploadedAt: upload.uploadedAt,
            isProcessed: upload.isProcessed,
            expiresAt: upload.expiresAt
        )
    }

    func getMockup(req: Request) async throws -> MockupDetailResponseDTO {
        guard let uploadIdString = req.parameters.get("uploadId"),
              let uploadId = UUID(uuidString: uploadIdString) else {
            throw Abort(.badRequest, reason: "Invalid upload ID")
        }

        let expiresIn = req.query["expiresIn"] ?? 3600
        let (upload, url) = try await mockupProcessingService.getMockupWithURL(
            uploadId: uploadId,
            expiresIn: expiresIn
        )

        return MockupDetailResponseDTO(
            id: upload.id.uuidString,
            requestId: upload.prdRequestId.uuidString,
            fileName: upload.fileName,
            fileSize: upload.fileSize,
            mimeType: upload.mimeType,
            uploadedAt: upload.uploadedAt,
            isProcessed: upload.isProcessed,
            expiresAt: upload.expiresAt,
            signedUrl: url,
            urlExpiresIn: expiresIn,
            analysisResult: upload.analysisResult.map(MockupAnalysisDTO.from),
            analysisConfidence: upload.analysisConfidence
        )
    }

    func deleteMockup(req: Request) async throws -> HTTPStatus {
        guard let uploadIdString = req.parameters.get("uploadId"),
              let uploadId = UUID(uuidString: uploadIdString) else {
            throw Abort(.badRequest, reason: "Invalid upload ID")
        }

        try await mockupProcessingService.deleteMockup(uploadId: uploadId)
        return .noContent
    }

    // MARK: - Request-Specific Operations

    func listMockupsForRequest(req: Request) async throws -> MockupListResponseDTO {
        guard let requestIdString = req.parameters.get("requestId"),
              let requestId = UUID(uuidString: requestIdString) else {
            throw Abort(.badRequest, reason: "Invalid request ID")
        }

        let uploads = try await mockupProcessingService.getMockupsForRequest(requestId: requestId)

        return MockupListResponseDTO(
            requestId: requestId.uuidString,
            totalCount: uploads.count,
            mockups: uploads.map { upload in
                MockupSummaryDTO(
                    id: upload.id.uuidString,
                    fileName: upload.fileName,
                    fileSize: upload.fileSize,
                    uploadedAt: upload.uploadedAt,
                    isAnalyzed: upload.analysisResult != nil,
                    analysisConfidence: upload.analysisConfidence,
                    isProcessed: upload.isProcessed
                )
            }
        )
    }

    func getConsolidatedAnalysis(req: Request) async throws -> ConsolidatedAnalysisResponseDTO {
        guard let requestIdString = req.parameters.get("requestId"),
              let requestId = UUID(uuidString: requestIdString) else {
            throw Abort(.badRequest, reason: "Invalid request ID")
        }

        let analysis = try await mockupProcessingService.getConsolidatedAnalysis(requestId: requestId)

        return ConsolidatedAnalysisResponseDTO(
            requestId: requestId.uuidString,
            totalMockups: analysis.totalMockups,
            analyzedMockups: analysis.analyzedMockups,
            uiElements: analysis.uiElements,
            userFlows: analysis.userFlows.map { UserFlowDTO(
                flowName: $0.flowName,
                steps: $0.steps,
                confidence: $0.confidence
            )},
            businessLogicInferences: analysis.businessLogicInferences.map { BusinessLogicDTO(
                feature: $0.feature,
                description: $0.description,
                confidence: $0.confidence,
                requiredComponents: $0.requiredComponents
            )},
            extractedText: analysis.extractedText,
            averageConfidence: analysis.averageConfidence
        )
    }

    func analyzeUnprocessedMockups(req: Request) async throws -> AnalysisJobResponseDTO {
        guard let requestIdString = req.parameters.get("requestId"),
              let requestId = UUID(uuidString: requestIdString) else {
            throw Abort(.badRequest, reason: "Invalid request ID")
        }

        Task {
            try? await mockupProcessingService.processUnanalyzedMockups(requestId: requestId)
        }

        return AnalysisJobResponseDTO(
            requestId: requestId.uuidString,
            status: "processing",
            message: "Analysis started for unprocessed mockups"
        )
    }

    // MARK: - Admin/Cleanup Operations

    func cleanupExpired(req: Request) async throws -> CleanupResultDTO {
        let result = try await mockupCleanupService.cleanupExpiredMockups()

        return CleanupResultDTO(
            totalProcessed: result.totalProcessed,
            deletedCount: result.deletedCount,
            failedCount: result.failedCount,
            reclaimedBytes: result.reclaimedBytes
        )
    }

    func cleanupForRequest(req: Request) async throws -> CleanupResultDTO {
        guard let requestIdString = req.parameters.get("requestId"),
              let requestId = UUID(uuidString: requestIdString) else {
            throw Abort(.badRequest, reason: "Invalid request ID")
        }

        let result = try await mockupCleanupService.cleanupForCompletedRequest(requestId: requestId)

        return CleanupResultDTO(
            totalProcessed: result.totalProcessed,
            deletedCount: result.deletedCount,
            failedCount: result.failedCount,
            reclaimedBytes: result.reclaimedBytes
        )
    }

    func getStorageStats(req: Request) async throws -> StorageStatsDTO {
        let stats = try await mockupCleanupService.getStorageStatistics()

        return StorageStatsDTO(
            totalMockups: stats.totalMockups,
            totalBytes: stats.totalBytes,
            processedMockups: stats.processedMockups,
            unprocessedMockups: stats.unprocessedMockups,
            expiredMockups: stats.expiredMockups
        )
    }
}

// MARK: - DTOs

public struct MockupUploadRequestDTO: Content {
    let requestId: String
    let fileName: String
    let mimeType: String
    let imageData: String // base64 encoded
}

public struct MockupUploadResponseDTO: Content {
    let id: String
    let requestId: String
    let fileName: String
    let fileSize: Int64
    let mimeType: String
    let uploadedAt: Date
    let isProcessed: Bool
    let expiresAt: Date
}

public struct MockupDetailResponseDTO: Content {
    let id: String
    let requestId: String
    let fileName: String
    let fileSize: Int64
    let mimeType: String
    let uploadedAt: Date
    let isProcessed: Bool
    let expiresAt: Date
    let signedUrl: String
    let urlExpiresIn: Int
    let analysisResult: MockupAnalysisDTO?
    let analysisConfidence: Double?
}

public struct MockupListResponseDTO: Content {
    let requestId: String
    let totalCount: Int
    let mockups: [MockupSummaryDTO]
}

public struct MockupSummaryDTO: Content {
    let id: String
    let fileName: String
    let fileSize: Int64
    let uploadedAt: Date
    let isAnalyzed: Bool
    let analysisConfidence: Double?
    let isProcessed: Bool
}

public struct ConsolidatedAnalysisResponseDTO: Content {
    let requestId: String
    let totalMockups: Int
    let analyzedMockups: Int
    let uiElements: [String]
    let userFlows: [UserFlowDTO]
    let businessLogicInferences: [BusinessLogicDTO]
    let extractedText: [String]
    let averageConfidence: Double
}

public struct UserFlowDTO: Content {
    let flowName: String
    let steps: [String]
    let confidence: Double
}

public struct BusinessLogicDTO: Content {
    let feature: String
    let description: String
    let confidence: Double
    let requiredComponents: [String]
}

public struct MockupAnalysisDTO: Content {
    let uiElements: [UIElementDTO]
    let layoutStructure: LayoutStructureDTO
    let extractedText: [String]
    let colorScheme: ColorSchemeDTO?
    let inferredUserFlows: [UserFlowDTO]
    let businessLogicInferences: [BusinessLogicDTO]
    let analyzedAt: Date

    static func from(_ analysis: MockupAnalysisResult) -> MockupAnalysisDTO {
        MockupAnalysisDTO(
            uiElements: analysis.uiElements.map { UIElementDTO(
                type: $0.type.rawValue,
                label: $0.label,
                confidence: $0.confidence
            )},
            layoutStructure: LayoutStructureDTO(
                screenType: analysis.layoutStructure.screenType.rawValue,
                hierarchyLevels: analysis.layoutStructure.hierarchyLevels,
                primaryLayout: analysis.layoutStructure.primaryLayout.rawValue
            ),
            extractedText: analysis.extractedText.map { $0.text },
            colorScheme: analysis.colorScheme.map { ColorSchemeDTO(
                primaryColors: $0.primaryColors,
                accentColors: $0.accentColors,
                textColors: $0.textColors,
                backgroundColors: $0.backgroundColors
            )},
            inferredUserFlows: analysis.inferredUserFlows.map { UserFlowDTO(
                flowName: $0.flowName,
                steps: $0.steps,
                confidence: $0.confidence
            )},
            businessLogicInferences: analysis.businessLogicInferences.map { BusinessLogicDTO(
                feature: $0.feature,
                description: $0.description,
                confidence: $0.confidence,
                requiredComponents: $0.requiredComponents
            )},
            analyzedAt: analysis.analyzedAt
        )
    }
}

public struct UIElementDTO: Content {
    let type: String
    let label: String?
    let confidence: Double
}

public struct LayoutStructureDTO: Content {
    let screenType: String
    let hierarchyLevels: Int
    let primaryLayout: String
}

public struct ColorSchemeDTO: Content {
    let primaryColors: [String]
    let accentColors: [String]
    let textColors: [String]
    let backgroundColors: [String]
}

public struct AnalysisJobResponseDTO: Content {
    let requestId: String
    let status: String
    let message: String
}

public struct CleanupResultDTO: Content {
    let totalProcessed: Int
    let deletedCount: Int
    let failedCount: Int
    let reclaimedBytes: Int64
}

public struct StorageStatsDTO: Content {
    let totalMockups: Int
    let totalBytes: Int64
    let processedMockups: Int
    let unprocessedMockups: Int
    let expiredMockups: Int
}