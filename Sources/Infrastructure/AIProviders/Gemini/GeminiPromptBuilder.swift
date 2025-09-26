import Foundation
import Domain

struct GeminiPromptBuilder {
    func buildPRDPrompt(_ request: GeneratePRDCommand) -> String {
        var prompt = """
        Generate a comprehensive Product Requirements Document for the following:

        Title: \(request.title)
        Description: \(request.description)
        Priority: \(request.priority.rawValue)
        """

        if !request.mockupSources.isEmpty {
            prompt += "\nMockups: \(request.mockupSources.count) sources provided"
        }

        prompt += """

        Requirements:
        - Include Test Cases: \(request.options.includeTestCases)
        - Include API Spec: \(request.options.includeApiSpec)
        - Include Technical Details: \(request.options.includeTechnicalDetails)
        """

        if let audience = request.options.targetAudience {
            prompt += "\n- Target Audience: \(audience)"
        }

        prompt += """


        Create a detailed PRD with the following sections:
        1. Executive Summary
        2. Problem Statement
        3. User Stories
        4. Functional Requirements
        5. Non-Functional Requirements
        6. Technical Requirements
        7. Acceptance Criteria
        8. Timeline
        9. Risks

        Use clear markdown formatting with proper headers (# ## ###). Each section should be detailed and actionable.
        """

        if let customPrompt = request.options.customPrompt {
            prompt += "\n\nAdditional Requirements:\n\(customPrompt)"
        }

        return prompt
    }

    func buildAnalysisPrompt(_ text: String) -> String {
        return """
        Analyze the following requirements for completeness and clarity:

        \(text)

        Provide your analysis in JSON format:
        {
            "confidence": <0-100>,
            "clarificationsNeeded": [<array of specific questions>],
            "assumptions": [<array of assumptions being made>],
            "gaps": [<array of identified gaps>]
        }

        Be thorough and specific in your analysis.
        """
    }

    func buildMockupAnalysisPrompt(_ sources: [MockupSource]) -> String {
        let mockupDescriptions = sources.enumerated().map { index, source in
            "Mockup \(index + 1): \(source.type.rawValue) - \(source.location)"
        }.joined(separator: "\n")

        return """
        Analyze the following mockups and extract relevant information:

        \(mockupDescriptions)

        Provide your analysis in JSON format:
        {
            "extractedFeatures": [<array of features visible in mockups>],
            "userFlows": [<array of user interaction flows>],
            "uiComponents": [<array of UI components identified>],
            "businessLogic": [<array of business rules inferred>]
        }

        Be specific about what you observe in the mockups.
        """
    }
}