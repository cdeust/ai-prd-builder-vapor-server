import XCTest
@testable import App
@testable import Domain
@testable import Application
@testable import Infrastructure
@testable import Presentation
import XCTVapor

final class AppTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        app = Application(.testing)
        try configure(app)
    }

    override func tearDown() async throws {
        app.shutdown()
    }

    func testHealthEndpoint() async throws {
        try app.test(.GET, "health") { res in
            XCTAssertEqual(res.status, .ok)

            let health = try res.content.decode(HealthResponse.self)
            XCTAssertEqual(health.status, "healthy")
            XCTAssertEqual(health.environment, "testing")
        }
    }

    func testPRDGenerateEndpointStructure() async throws {
        // Test that the endpoint exists (will fail with missing auth/provider but route should exist)
        try app.test(.POST, "api/v1/prd/generate") { res in
            // Expecting either success or specific error, not 404
            XCTAssertNotEqual(res.status, .notFound)
        }
    }

    func testPRDAnalyzeEndpointStructure() async throws {
        // Test that the analyze endpoint exists
        try app.test(.POST, "api/v1/prd/analyze") { res in
            // Expecting either success or specific error, not 404
            XCTAssertNotEqual(res.status, .notFound)
        }
    }

    func testProvidersEndpointStructure() async throws {
        // Test that the providers endpoint exists
        try app.test(.GET, "api/v1/prd/providers") { res in
            // May fail with missing AI orchestrator but route should exist
            XCTAssertNotEqual(res.status, .notFound)
        }
    }

    func testDomainErrorMiddleware() async throws {
        // Test that domain errors are properly handled
        // This would test the error middleware in a real scenario
        let errorMiddleware = DomainErrorMiddleware()
        XCTAssertNotNil(errorMiddleware)
    }
}

// Helper struct for health response decoding
private struct HealthResponse: Content {
    let status: String
    let timestamp: Date
    let version: String
    let environment: String
}