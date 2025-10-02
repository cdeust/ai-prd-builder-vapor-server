import Foundation
import Domain

/// Centralized prompt library with consistent XML markup across all AI providers
/// Follows Anthropic best practices for prompt engineering
public enum StandardizedPrompts {

    // MARK: - PRD Generation Prompts

    public static func buildPRDGenerationPrompt(_ request: GeneratePRDCommand) -> String {
        var components: [String] = []

        components.append("""
        <task>Generate Product Requirements Document</task>

        <input>
        <title>\(request.title)</title>
        <description>\(request.description)</description>
        <priority>\(request.priority.rawValue)</priority>
        """)

        if !request.mockupSources.isEmpty {
            components.append("""
            <mockups count="\(request.mockupSources.count)">
            Mockup sources provided for visual context
            </mockups>
            """)
        }

        if let codebaseContext = request.codebaseContext {
            components.append("""
            <codebase_context>
            <repository>\(codebaseContext.repositoryUrl)</repository>
            <languages>\(codebaseContext.techStack.languages.keys.joined(separator: ", "))</languages>
            <summary>\(codebaseContext.summary)</summary>
            </codebase_context>
            """)
        }

        components.append("</input>")

        components.append("""

        <instruction>
        Generate a comprehensive Product Requirements Document based entirely on the provided input.

        Your document should include:
        - Executive summary derived from the description
        - Target users identified from context
        - User stories extracted from requirements
        - Feature list based on described functionality
        - Technical requirements
        - Acceptance criteria
        - Success metrics

        CRITICAL: Only use information explicitly provided in the input. Do not invent facts or make unsupported assumptions.

        Structure your output using clear markdown formatting with appropriate headings and sections.
        </instruction>
        """)

        return components.joined(separator: "\n")
    }

    // MARK: - Requirements Analysis Prompts

    public static func buildRequirementsAnalysisPrompt(_ text: String) -> String {
        return """
        <task>Analyze Requirements Completeness</task>

        <input>
        \(text)
        </input>

        <instruction>
        Analyze the provided requirements to identify what information is missing or unclear.
        Focus on CRITICAL decisions that cannot be inferred and would significantly impact the architecture.

        Evaluate:
        1. What architectural decisions cannot be determined from the input
        2. What critical technical constraints are not specified
        3. What assumptions you're forced to make that could be wrong
        4. Your confidence level in generating an accurate PRD

        Generate clarification questions ONLY for:
        - Architectural decisions that have multiple valid approaches
        - Technical constraints that would change the implementation
        - Critical features that are ambiguous or contradictory
        - Scale/performance requirements that affect design

        DO NOT ask about:
        - Standard best practices (these can be assumed)
        - Implementation details that don't affect architecture
        - Technologies when reasonable defaults exist

        <output_format>
        Provide your analysis in JSON format:
        {
          "confidence": <0-100>,
          "clarificationsNeeded": ["specific question 1", "specific question 2"],
          "assumptions": ["assumption 1", "assumption 2"],
          "gaps": ["gap 1", "gap 2"]
        }
        </output_format>
        </instruction>
        """
    }

    // MARK: - Mockup Analysis Prompts

    public static func buildMockupAnalysisPrompt(_ sources: [MockupSource]) -> String {
        let mockupDescriptions = sources.enumerated()
            .map { index, source in
                let path = source.localPath ?? source.url?.path ?? "unknown"
                return "<mockup index=\"\(index + 1)\" path=\"\(path)\" />"
            }
            .joined(separator: "\n")

        return """
        <task>Analyze UI/UX Mockups</task>

        <mockups>
        \(mockupDescriptions)
        </mockups>

        <instruction>
        Analyze the provided mockup files to extract product requirements and functionality.

        Extract and describe:
        - Key features visible in the UI
        - User workflows and interaction patterns
        - Data fields, forms, and input elements
        - Navigation structure and hierarchy
        - Business logic implied by the interface
        - User roles if apparent from the UI
        - Integration points suggested by the design

        Focus on observable, concrete elements rather than assumptions.

        <output_format>
        Provide your analysis in JSON format:
        {
          "extractedFeatures": ["feature 1", "feature 2"],
          "userFlows": ["flow 1", "flow 2"],
          "uiComponents": ["component 1", "component 2"],
          "businessLogic": ["rule 1", "rule 2"],
          "navigationStructure": "description"
        }
        </output_format>
        </instruction>
        """
    }

    // MARK: - Interactive Clarification Prompts

    public static func buildClarificationPrompt(question: String, context: String) -> String {
        return """
        <task>Provide Clarification</task>

        <question>
        \(question)
        </question>

        <context>
        \(context)
        </context>

        <instruction>
        Based on the question and context provided, give a clear, concise answer that will help refine the PRD generation.

        If the question cannot be answered from the context, state what additional information would be helpful.
        </instruction>
        """
    }

    // MARK: - Validation Prompts

    public static func buildValidationPrompt(prdContent: String, originalRequirements: String) -> String {
        return """
        <task>Validate PRD Accuracy</task>

        <original_requirements>
        \(originalRequirements)
        </original_requirements>

        <generated_prd>
        \(prdContent)
        </generated_prd>

        <instruction>
        Compare the generated PRD against the original requirements to validate accuracy.

        Check for:
        - All requirements are addressed in the PRD
        - No invented features or requirements
        - Technical accuracy of proposed solutions
        - Consistency across sections
        - Clarity and completeness

        <output_format>
        Provide validation results in JSON format:
        {
          "isValid": <true/false>,
          "confidence": <0-100>,
          "missingRequirements": ["req 1", "req 2"],
          "inventedItems": ["item 1", "item 2"],
          "inconsistencies": ["inconsistency 1", "inconsistency 2"],
          "suggestions": ["suggestion 1", "suggestion 2"]
        }
        </output_format>
        </instruction>
        """
    }
}
