import Foundation

public protocol AIProviderPort {
    var name: String { get }
    var priority: Int { get }
    var isAvailable: Bool { get async }

    func generatePRD(from command: GeneratePRDCommand) async throws -> PRDGenerationResult
    func analyzeRequirements(_ text: String) async throws -> RequirementsAnalysis
    func extractFromMockups(_ sources: [MockupSource]) async throws -> MockupAnalysis
}