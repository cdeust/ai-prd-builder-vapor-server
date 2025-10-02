import Foundation
import Domain

struct OpenAIPromptBuilder {
    /// Build PRD generation prompt using standardized XML markup
    func buildPRDPrompt(_ request: GeneratePRDCommand) -> String {
        return StandardizedPrompts.buildPRDGenerationPrompt(request)
    }

    /// Build requirements analysis prompt using standardized XML markup
    func buildAnalysisPrompt(_ text: String) -> String {
        return StandardizedPrompts.buildRequirementsAnalysisPrompt(text)
    }

    /// Build mockup analysis prompt using standardized XML markup
    func buildMockupAnalysisPrompt(_ sources: [MockupSource]) -> String {
        return StandardizedPrompts.buildMockupAnalysisPrompt(sources)
    }
}