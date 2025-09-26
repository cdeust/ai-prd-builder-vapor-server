import XCTest
@testable import Presentation
@testable import Domain
@testable import Application
import XCTVapor

final class PresentationTests: XCTestCase {

    func testGeneratePRDRequestDTOCreation() {
        // Test DTO creation
        let dto = GeneratePRDRequestDTO(
            requestId: UUID(),
            title: "Test PRD",
            description: "Test Description",
            mockupSources: nil,
            priority: "high",
            preferredProvider: nil,
            options: nil
        )

        XCTAssertEqual(dto.title, "Test PRD")
        XCTAssertEqual(dto.priority, "high")
        XCTAssertNil(dto.mockupSources)
    }

    func testMockupSourceDTOMapping() {
        // Test mockup source DTO
        let dto = MockupSourceDTO(
            type: "wireframe",
            url: "https://example.com/mockup.png",
            localPath: nil,
            content: "Login screen mockup"
        )

        XCTAssertEqual(dto.type, "wireframe")
        XCTAssertNotNil(dto.url)
        XCTAssertNil(dto.localPath)
    }

    func testRequirementsAnalysisDTOMapping() {
        // Test requirements analysis DTO mapping
        let analysis = RequirementsAnalysis(
            confidence: 75,
            clarificationsNeeded: ["What authentication method?"],
            assumptions: ["OAuth2 will be used"],
            gaps: ["Security requirements"]
        )

        let dto = RequirementsAnalysisDTO.from(analysis)

        XCTAssertEqual(dto.confidence, 75)
        XCTAssertEqual(dto.clarificationsNeeded.count, 1)
        XCTAssertEqual(dto.assumptions.count, 1)
        XCTAssertEqual(dto.gaps.count, 1)
    }

    func testErrorResponseDTO() {
        // Test error response DTO
        let errorDetail = ErrorDetailDTO(
            code: "validation",
            message: "Title is required",
            timestamp: Date()
        )

        let errorResponse = ErrorResponseDTO(error: errorDetail)

        XCTAssertEqual(errorResponse.error.code, "validation")
        XCTAssertEqual(errorResponse.error.message, "Title is required")
    }

    func testProviderStatusDTO() {
        // Test provider status DTO
        let dto = ProviderStatusDTO(
            name: "anthropic",
            isAvailable: true,
            priority: 10,
            capabilities: ["PRD generation", "Analysis"],
            lastUsed: Date()
        )

        XCTAssertTrue(dto.isAvailable)
        XCTAssertEqual(dto.capabilities.count, 2)
        XCTAssertNotNil(dto.lastUsed)
    }
}