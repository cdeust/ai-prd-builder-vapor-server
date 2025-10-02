import Foundation
import Domain
import PRDGenerator

struct PRDInputBuilder {
    func build(from request: GeneratePRDCommand) throws -> PRDGenerator.PRDInput {
        var mockupPaths: [String] = []

        for source in request.mockupSources {
            if let localPath = source.localPath {
                mockupPaths.append(localPath)
            } else if let url = source.url {
                mockupPaths.append(url.path)
            }
        }

        let guidelines = buildGuidelines(from: request.options)

        // ✅ Build enriched description with codebase context
        let text = buildEnrichedDescription(
            title: request.title,
            description: request.description,
            codebaseContext: request.codebaseContext
        )

        return PRDGenerator.PRDInput(
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

    /// Build enriched description with codebase context
    private func buildEnrichedDescription(
        title: String,
        description: String,
        codebaseContext: CodebaseContext?
    ) -> String {
        guard let context = codebaseContext else {
            return "\(title)\n\n\(description)"
        }

        var enrichedParts: [String] = [title, "", description]

        // Add codebase header
        enrichedParts.append("""

        ## Codebase Context

        This PRD should be aligned with an existing codebase:

        **Repository:** \(context.repositoryUrl) (branch: \(context.repositoryBranch))
        **Project ID:** \(context.projectId)
        **Summary:** \(context.summary)
        """)

        // Add tech stack info
        if !context.techStack.languages.isEmpty {
            let languagesText = context.techStack.languages
                .sorted { $0.value > $1.value }
                .map { "\($0.key) (\($0.value) bytes)" }
                .joined(separator: ", ")

            enrichedParts.append("""

            **Tech Stack:**
            - Languages: \(languagesText)
            """)

            if !context.techStack.frameworks.isEmpty {
                enrichedParts.append("- Frameworks: \(context.techStack.frameworks.joined(separator: ", "))")
            }

            if !context.techStack.architecturePatterns.isEmpty {
                enrichedParts.append("- Architecture: \(context.techStack.architecturePatterns.joined(separator: ", "))")
            }
        }

        // Add relevant files
        if !context.relevantFiles.isEmpty {
            enrichedParts.append("\n**Relevant Code Files:**\n")

            for file in context.relevantFiles {
                enrichedParts.append("""

                ### \(file.filePath)
                **Purpose:** \(file.purpose)
                \(file.language.map { "**Language:** \($0)" } ?? "")

                ```\(file.language?.lowercased() ?? "")
                \(file.excerpt)
                ```
                """)
            }
        }

        enrichedParts.append("""

        ---

        **IMPORTANT:** The PRD should be designed to integrate with or extend the existing codebase above.
        Consider the current architecture, tech stack, and coding patterns when proposing solutions.
        Ensure technical requirements align with the existing technologies and frameworks.
        """)

        return enrichedParts.joined(separator: "\n")
    }
}