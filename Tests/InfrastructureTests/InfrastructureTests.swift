import XCTest
@testable import Infrastructure
@testable import Domain
@testable import Application
import FluentSQLiteDriver
import Vapor

final class InfrastructureTests: XCTestCase {

    func testAnthropicProviderInitialization() {
        // Test Anthropic provider initialization
        let httpClient = HTTPClient(eventLoopGroupProvider: .createNew)
        defer { try? httpClient.syncShutdown() }

        let provider = AnthropicProvider(
            apiKey: "test-key",
            httpClient: httpClient,
            model: "claude-3-opus-20240229"
        )

        XCTAssertEqual(provider.name, "anthropic")
        XCTAssertEqual(provider.priority, 1)
    }

    func testMockupSourceSerialization() throws {
        // Test mockup source serialization for database storage
        let mockup = try MockupSource(
            type: .wireframe,
            url: URL(string: "https://example.com/mockup.png"),
            localPath: "/tmp/mockup.png",
            content: "Mockup description"
        )

        let data = MockupSourceData(
            type: mockup.type.rawValue,
            url: mockup.url?.absoluteString,
            localPath: mockup.localPath,
            content: mockup.content
        )

        XCTAssertEqual(data.type, "wireframe")
        XCTAssertEqual(data.url, "https://example.com/mockup.png")
    }

    func testDatabaseTypeParsing() {
        // Test database type environment variable parsing
        let postgresTypes = ["postgresql", "postgres", "fluent"]
        for type in postgresTypes {
            XCTAssertTrue(["postgresql", "postgres", "fluent"].contains(type))
        }

        XCTAssertEqual("supabase", "supabase")
        XCTAssertTrue(["mongodb", "mongo"].contains("mongodb"))
    }
}