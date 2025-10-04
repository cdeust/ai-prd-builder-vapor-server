import Foundation
import Domain
import PRDGenerator

struct PRDInputBuilder {
    // Using the new ContextOptimizer for token-aware context building
    func build(from request: GeneratePRDCommand) throws -> PRDGeneratorService.PRDInput {
        var mockupPaths: [String] = []

        for source in request.mockupSources {
            if let localPath = source.localPath {
                mockupPaths.append(localPath)
            } else if let url = source.url {
                mockupPaths.append(url.path)
            }
        }

        let guidelines = buildGuidelines(from: request.options)

        // ✅ Build optimized context with intelligent chunking
        let text = ContextOptimizer.buildOptimizedContext(
            title: request.title,
            description: request.description,
            codebaseContext: request.codebaseContext,
            mockupAnalyses: request.mockupAnalyses,
            clarifications: request.clarifications
        )

        return PRDGeneratorService.PRDInput(
            text: text,
            mockupPaths: mockupPaths,
            guidelines: guidelines
        )
    }

    func buildInteractivePrompt(from request: GeneratePRDCommand) -> String {
        var prompt = "Generate a comprehensive PRD for: \(request.title)\n\n"
        prompt += "Description: \(request.description)\n\n"

        if !request.mockupSources.isEmpty {
            prompt += "Mockups provided: \(request.mockupSources.count) files\n"
        }

        let options = request.options
        if let audience = options.targetAudience {
            prompt += "Target Audience: \(audience)\n"
        }
        if let customPrompt = options.customPrompt {
            prompt += "Additional Requirements: \(customPrompt)\n"
        }

        return prompt
    }

    func buildMockupAnalysisPrompt(paths: [String]) -> String {
        let pathsList = paths.joined(separator: "\n")
        return """
        Analyze the following mockup files and extract:
        1. Features and functionality
        2. User flows
        3. UI components
        4. Inferred business logic

        Mockup files:
        \(pathsList)
        """
    }

    func buildAnswersPrompt(questions: [String], answers: [String]) -> String {
        var prompt = "Here are the answers to your questions:\n\n"

        for (index, question) in questions.enumerated() {
            if index < answers.count {
                prompt += "Q: \(question)\n"
                prompt += "A: \(answers[index])\n\n"
            }
        }

        prompt += "Please continue with the PRD generation based on these answers."
        return prompt
    }

    private func buildGuidelines(from options: GenerationOptions) -> String {
        var guidelines: [String] = []

        if options.includeTestCases {
            guidelines.append("Include comprehensive test cases")
        }
        if options.includeApiSpec {
            guidelines.append("Include OpenAPI 3.1.0 specification")
        }
        if options.includeTechnicalDetails {
            guidelines.append("Include detailed technical requirements")
        }
        if let audience = options.targetAudience {
            guidelines.append("Target audience: \(audience)")
        }
        if let customPrompt = options.customPrompt {
            guidelines.append(customPrompt)
        }
        if let maxSections = options.maxSections {
            guidelines.append("Maximum sections: \(maxSections)")
        }

        return guidelines.joined(separator: "\n")
    }

}