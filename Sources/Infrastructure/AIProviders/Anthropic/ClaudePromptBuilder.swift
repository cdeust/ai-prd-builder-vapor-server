import Foundation
import Domain

struct ClaudePromptBuilder {
    func buildPRDPrompt(_ request: GeneratePRDCommand) -> String {
        var prompt = """
        <task>Generate Product Requirements Document</task>

        <input>
        Title: \(request.title)
        Description: \(request.description)
        Priority: \(request.priority.rawValue)
        """

        if !request.mockupSources.isEmpty {
            prompt += "\nMockups: \(request.mockupSources.count) sources provided"
        }

        prompt += """

        Options:
        - Include Test Cases: \(request.options.includeTestCases)
        - Include API Spec: \(request.options.includeApiSpec)
        - Include Technical Details: \(request.options.includeTechnicalDetails)
        """

        if let audience = request.options.targetAudience {
            prompt += "\n- Target Audience: \(audience)"
        }

        prompt += """

        </input>

        <instruction>
        Think carefully about this product requirement. Plan systematically and create a comprehensive PRD that includes:

        TODO: Executive Summary - Brief overview of the feature
        TODO: Problem Statement - Clear definition of what we're solving
        TODO: User Stories - Who will use this and how
        TODO: Functional Requirements - What the system must do
        TODO: Non-Functional Requirements - Performance, scalability, etc.
        TODO: Technical Requirements - Implementation considerations
        TODO: Acceptance Criteria - Definition of done
        TODO: Timeline - Development phases and milestones
        TODO: Risks - Potential challenges and mitigation strategies

        Use clear markdown formatting with proper headers. Each section should be detailed and actionable.
        """

        if let customPrompt = request.options.customPrompt {
            prompt += "\n\nAdditional Requirements:\n\(customPrompt)"
        }

        prompt += "\n</instruction>"

        return prompt
    }

    func buildAnalysisPrompt(_ text: String) -> String {
        return """
        <task>Analyze Requirements Completeness</task>

        <input>\(text)</input>

        <instruction>
        Think critically about these requirements. Analyze the completeness and clarity of the provided requirements.

        Provide your analysis in this JSON format:
        {
            "confidence": <0-100>,
            "clarificationsNeeded": [<array of specific questions>],
            "assumptions": [<array of assumptions being made>],
            "gaps": [<array of identified gaps>]
        }

        Be thorough in identifying what's missing or unclear.
        </instruction>
        """
    }

    func buildMockupAnalysisPrompt(_ sources: [MockupSource]) -> String {
        let mockupDescriptions = sources.enumerated().map { index, source in
            "Mockup \(index + 1): \(source.type.rawValue) - \(source.location)"
        }.joined(separator: "\n")

        return """
        <task>Extract Features from Mockups</task>

        <input>
        \(mockupDescriptions)
        </input>

        <instruction>
        Research and explore these mockups to extract:

        Provide your analysis in this JSON format:
        {
            "extractedFeatures": [<array of features visible in mockups>],
            "userFlows": [<array of user interaction flows>],
            "uiComponents": [<array of UI components identified>],
            "businessLogic": [<array of business rules inferred>]
        }

        Be specific about what you can see and infer from the mockups.
        </instruction>
        """
    }
}