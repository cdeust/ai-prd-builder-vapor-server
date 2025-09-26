import XCTest
@testable import Application
@testable import Domain

final class ApplicationTests: XCTestCase {

    func testGeneratePRDCommandCreation() {
        // Test command object creation
        let command = GeneratePRDCommand(
            requestId: UUID(),
            title: "Test Feature",
            description: "Implement test feature",
            mockupSources: [],
            priority: .medium,
            preferredProvider: "anthropic",
            options: GenerationOptions()
        )

        XCTAssertEqual(command.title, "Test Feature")
        XCTAssertEqual(command.priority, .medium)
        XCTAssertTrue(command.options.includeTestCases)
    }

    func testGenerationOptionsDefaults() {
        // Test default generation options
        let options = GenerationOptions()

        XCTAssertTrue(options.includeTestCases)
        XCTAssertTrue(options.includeApiSpec)
        XCTAssertTrue(options.includeTechnicalDetails)
        XCTAssertEqual(options.maxSections, 10)
        XCTAssertEqual(options.targetAudience, "technical")
        XCTAssertNil(options.customPrompt)
    }

    func testRequirementsAnalysisConfidence() {
        // Test requirements analysis confidence levels
        let analysis = RequirementsAnalysis(
            confidence: 85,
            clarificationsNeeded: [],
            assumptions: ["User authentication required"],
            gaps: []
        )

        XCTAssertEqual(analysis.confidence, 85)
        XCTAssertEqual(analysis.assumptions.count, 1)
        XCTAssertTrue(analysis.clarificationsNeeded.isEmpty)
    }
}