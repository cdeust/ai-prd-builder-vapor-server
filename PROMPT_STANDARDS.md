# Prompt Engineering Standards

## Overview

All prompts across the AI PRD Builder platforms (Swift, Vapor Server, Web) must follow Anthropic's best practices for prompt engineering, with consistent XML markup for better AI comprehension and results.

## Why XML Markup?

XML tags provide clear semantic structure that helps AI models:
1. **Distinguish** between instructions, input data, and output format requirements
2. **Hierarchically organize** complex prompts
3. **Improve consistency** across different AI providers (Claude, GPT, Gemini)
4. **Reduce ambiguity** in multi-part prompts
5. **Enable better reasoning** by clearly separating concerns

## Standard Prompt Structure

All prompts should follow this structure:

```xml
<task>Brief description of what the AI should do</task>

<input>
<!-- Structured input data -->
<field_name>value</field_name>
</input>

<instruction>
Detailed instructions on how to process the input.

Include:
- Specific requirements
- Constraints and limitations
- What to include/exclude
- Quality standards

<output_format>
Define expected output format (JSON, Markdown, etc.)
</output_format>
</instruction>
```

## Examples

### Good Prompt (With XML Markup)

```xml
<task>Analyze Requirements Completeness</task>

<input>
Feature: User authentication
Description: Users should be able to log in with email and password
</input>

<instruction>
Analyze the provided requirements to identify gaps and ambiguities.

Focus on:
- Missing technical specifications
- Unclear user flows
- Security considerations not addressed

<output_format>
{
  "confidence": <0-100>,
  "clarifications": ["question 1", "question 2"],
  "gaps": ["gap 1", "gap 2"]
}
</output_format>
</instruction>
```

### Bad Prompt (Without XML Markup)

```
Analyze these requirements for completeness:

Feature: User authentication
Users should be able to log in with email and password

Tell me what's missing and give me a JSON response with confidence,
clarifications, and gaps.
```

## Standardized Prompt Library

All prompt builders must use `StandardizedPrompts` enum located at:
`Sources/Infrastructure/AIProviders/Shared/StandardizedPrompts.swift`

### Available Methods:

1. **`buildPRDGenerationPrompt(_ request: GeneratePRDCommand)`**
   - Generates PRD creation prompt with codebase context
   - Includes mockup information if provided
   - Enforces focus on provided input only

2. **`buildRequirementsAnalysisPrompt(_ text: String)`**
   - Analyzes requirements for completeness
   - Identifies critical gaps and assumptions
   - Returns structured JSON response

3. **`buildMockupAnalysisPrompt(_ sources: [MockupSource])`**
   - Extracts features from UI/UX mockups
   - Identifies user flows and components
   - Maps business logic to visual elements

4. **`buildClarificationPrompt(question: String, context: String)`**
   - Formats interactive clarification questions
   - Provides context for better answers

5. **`buildValidationPrompt(prdContent: String, originalRequirements: String)`**
   - Validates generated PRD against requirements
   - Detects invented features or missing items
   - Ensures consistency across sections

## Implementation Requirements

### For New Prompts:

1. **Always use XML tags** for structure
2. **Separate concerns**: task, input, instruction, output_format
3. **Be explicit** about what to include/exclude
4. **Define output format** clearly
5. **Add to StandardizedPrompts** if reusable across providers

### For Existing Prompts:

1. **Migrate to StandardizedPrompts** when updating
2. **Test with multiple AI providers** (Claude, GPT, Gemini)
3. **Document any provider-specific variations**

## Provider-Specific Considerations

### Claude (Anthropic)
- Native XML support - works best with tags
- Respects `<thinking>` tags for reasoning
- Handles nested XML structures well

### GPT (OpenAI)
- XML improves structure but not native
- Benefits from clear `<instruction>` sections
- JSON output format works reliably

### Gemini (Google)
- Supports XML-like structure
- Prefers explicit role definitions
- Benefits from examples in prompts

## Testing Standards

All prompts should be tested for:

1. **Clarity**: AI understands the task correctly
2. **Consistency**: Same input produces similar outputs
3. **Completeness**: All required information is captured
4. **Correctness**: Output follows specified format
5. **Safety**: No hallucination or invented facts

## Migration Checklist

- [ ] Identify plain-text prompts in codebase
- [ ] Convert to XML markup structure
- [ ] Add to StandardizedPrompts if reusable
- [ ] Update prompt builder to use standardized version
- [ ] Test with all configured AI providers
- [ ] Document any special behavior or limitations

## References

- [Anthropic Prompt Engineering Guide](https://docs.anthropic.com/claude/docs/prompt-engineering)
- [XML Tags for Claude](https://docs.anthropic.com/claude/docs/use-xml-tags)
- OpenAI Best Practices
- Google Gemini Prompting Guide

## Enforcement

All PRs introducing new prompts must:
1. Use XML markup from `StandardizedPrompts`
2. Include tests demonstrating correct output
3. Document any provider-specific behavior
4. Follow the structure outlined in this document

---

**Last Updated**: 2025-10-02
**Maintained By**: Infrastructure Team
