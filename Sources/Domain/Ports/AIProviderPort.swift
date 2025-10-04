import Foundation
import PRDGenerator

public protocol AIProviderPort: Sendable {
    var name: String { get }
    var priority: Int { get }
    var isAvailable: Bool { get async }

    func generatePRD(
        from command: GeneratePRDCommand,
        contextRequestPort: ContextRequestPort?
    ) async throws -> PRDGenerationResult

    func analyzeRequirements(_ text: String) async throws -> RequirementsAnalysis
    func extractFromMockups(_ sources: [MockupSource]) async throws -> MockupAnalysis
}
