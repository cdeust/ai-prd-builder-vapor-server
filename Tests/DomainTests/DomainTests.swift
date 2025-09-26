import XCTest
@testable import Domain

final class DomainTests: XCTestCase {

    func testPRDRequestValidation() throws {
        // Test PRDRequest validation
        let request = PRDRequest(
            id: UUID(),
            title: "Test PRD",
            description: "Test Description",
            mockupSources: [],
            priority: .high,
            preferredProvider: nil,
            requesterId: "test-user",
            status: .pending,
            createdAt: Date(),
            updatedAt: Date()
        )

        XCTAssertNoThrow(try request.validate())
    }

    func testPRDRequestWithEmptyTitle() throws {
        // Test validation failure with empty title
        let request = PRDRequest(
            id: UUID(),
            title: "",
            description: "Test Description",
            mockupSources: [],
            priority: .medium,
            preferredProvider: nil,
            requesterId: "test-user",
            status: .pending,
            createdAt: Date(),
            updatedAt: Date()
        )

        XCTAssertThrowsError(try request.validate())
    }

    func testMockupSourceValidation() throws {
        // Test MockupSource value object
        let mockup = try MockupSource(
            type: .wireframe,
            url: URL(string: "https://example.com/mockup.png"),
            localPath: nil,
            content: "Test mockup"
        )

        XCTAssertEqual(mockup.type, .wireframe)
        XCTAssertNotNil(mockup.url)
    }

    func testPriorityOrdering() {
        // Test Priority enum ordering
        XCTAssertTrue(Priority.critical > Priority.high)
        XCTAssertTrue(Priority.high > Priority.medium)
        XCTAssertTrue(Priority.medium > Priority.low)
    }
}