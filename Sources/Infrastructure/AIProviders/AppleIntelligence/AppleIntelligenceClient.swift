import Foundation
import AsyncHTTPClient
import NIOCore
import Domain
import CommonModels
import DomainCore
import PRDGenerator

public final class AppleIntelligenceClient: MockupAnalysisPort, @unchecked Sendable {
    private let httpClient: HTTPClient
    private let aiProvider: CommonModels.AIProvider
    private let configuration: DomainCore.Configuration

    public init(
        httpClient: HTTPClient,
        provider: CommonModels.AIProvider,
        configuration: DomainCore.Configuration
    ) {
        self.httpClient = httpClient
        self.aiProvider = provider
        self.configuration = configuration
    }

    public func analyzeMockup(
        imageURL: String,
        context: MockupAnalysisContext
    ) async throws -> (result: MockupAnalysisResult, confidence: Double) {
        let prompt = buildAnalysisPrompt(context: context, imageURL: imageURL)
        let response = try await sendAnalysisRequest(prompt: prompt)
        return try parseAnalysisResponse(response)
    }

    public func analyzeMockups(
        imageURLs: [String],
        context: MockupAnalysisContext
    ) async throws -> [(result: MockupAnalysisResult, confidence: Double)] {
        var results: [(result: MockupAnalysisResult, confidence: Double)] = []

        for imageURL in imageURLs {
            let result = try await analyzeMockup(imageURL: imageURL, context: context)
            results.append(result)
        }

        return results
    }

    public func isAvailable() async -> Bool {
        // Check if AI provider is available
        return true
    }

    private func buildAnalysisPrompt(context: MockupAnalysisContext, imageURL: String) -> String {
        return """
        Analyze this UI mockup image for a PRD titled "\(context.requestTitle)".

        Project Description: \(context.requestDescription)

        Image URL: \(imageURL)

        Please provide a comprehensive analysis including:

        1. UI Elements: Identify all interactive components (buttons, text fields, dropdowns, etc.) with their approximate positions and labels.

        2. Layout Structure: Describe the overall layout type (vertical, horizontal, grid, etc.), screen type (login, dashboard, form, etc.), and component hierarchy.

        3. Extracted Text: List all visible text including headings, labels, button text, and placeholder text with their categories.

        4. Color Scheme: Identify primary colors, accent colors, text colors, and background colors used in the design.

        5. User Flows: Infer possible user interaction flows based on the UI elements and their arrangement.

        6. Business Logic: Deduce potential business requirements and features based on the UI elements present.

        Provide your analysis in a structured JSON format matching this schema:
        {
          "uiElements": [{"type": "button|textField|label|...", "label": "text", "bounds": {"x": 0, "y": 0, "width": 0, "height": 0}, "confidence": 0.9}],
          "layout": {"screenType": "login|dashboard|form|...", "hierarchyLevels": 2, "layoutType": "vertical|horizontal|grid|...", "componentGroups": [{"name": "group", "components": ["elem1"], "purpose": "description"}]},
          "extractedText": [{"content": "text", "category": "heading|label|button|...", "bounds": {"x": 0, "y": 0, "width": 0, "height": 0}}],
          "colorScheme": {"primary": ["#hex"], "accent": ["#hex"], "text": ["#hex"], "background": ["#hex"]},
          "inferredFlows": [{"name": "flow", "steps": ["step1", "step2"], "confidence": 0.8}],
          "businessLogic": [{"feature": "name", "description": "desc", "confidence": 0.8, "requiredComponents": ["comp1"]}],
          "overallConfidence": 0.85
        }
        """
    }

    private func sendAnalysisRequest(prompt: String) async throws -> VisionAnalysisResponse {
        print("[AppleIntelligenceClient] Sending analysis request")

        let messages = [
            ChatMessage(role: .user, content: prompt)
        ]

        let result = await aiProvider.sendMessages(messages)

        let jsonString: String
        switch result {
        case .success(let content):
            jsonString = content
        case .failure(let error):
            throw DomainError.processingFailed("AI provider error: \(error)")
        }

        // Extract JSON from response (might be wrapped in markdown code blocks)
        let cleanedJSON = extractJSON(from: jsonString)

        let decoder = JSONDecoder()
        do {
            let response = try decoder.decode(VisionAnalysisResponse.self, from: cleanedJSON.data(using: .utf8)!)
            print("[AppleIntelligenceClient] Analysis completed with confidence: \(response.overallConfidence)")
            return response
        } catch {
            print("[AppleIntelligenceClient] Failed to parse response: \(error)")
            print("[AppleIntelligenceClient] Raw JSON response:")
            print(cleanedJSON)
            throw DomainError.processingFailed("Failed to parse AI response: \(error.localizedDescription)")
        }
    }

    private func extractJSON(from text: String) -> String {
        // Remove markdown code blocks if present
        let patterns = [
            "```json\\s*([\\s\\S]*?)```",
            "```\\s*([\\s\\S]*?)```"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseAnalysisResponse(_ response: VisionAnalysisResponse) throws -> (result: MockupAnalysisResult, confidence: Double) {
        let uiElements = response.uiElements.map { element in
            UIElement(
                type: UIElementType(rawValue: element.type) ?? .other,
                label: element.label,
                bounds: ElementBounds(x: element.bounds.x, y: element.bounds.y, width: element.bounds.width, height: element.bounds.height),
                confidence: element.confidence
            )
        }

        let layoutStructure = LayoutStructure(
            screenType: ScreenType(rawValue: response.layout.screenType) ?? .other,
            hierarchyLevels: response.layout.hierarchyLevels,
            primaryLayout: LayoutType(rawValue: response.layout.layoutType) ?? .mixed,
            componentGroups: response.layout.componentGroups.map { group in
                // Convert component references to strings (use label if available, otherwise type)
                let componentStrings = group.components.map { comp in
                    comp.label ?? comp.type ?? "unknown"
                }
                return ComponentGroup(name: group.name, components: componentStrings, purpose: group.purpose)
            }
        )

        let extractedText = response.extractedText.map { text in
            ExtractedText(
                text: text.content,
                category: TextCategory(rawValue: text.category) ?? .other,
                bounds: ElementBounds(x: text.bounds.x, y: text.bounds.y, width: text.bounds.width, height: text.bounds.height)
            )
        }

        let colorScheme = response.colorScheme.map { colors in
            ColorScheme(
                primaryColors: colors.primary,
                accentColors: colors.accent,
                textColors: colors.text,
                backgroundColors: colors.background
            )
        }

        let userFlows = response.inferredFlows.map { flow in
            UserFlow(flowName: flow.name, steps: flow.steps, confidence: flow.confidence ?? 0.0)
        }

        let businessLogic = response.businessLogic.map { logic in
            BusinessLogicInference(
                feature: logic.feature,
                description: logic.description,
                confidence: logic.confidence ?? 0.0,
                requiredComponents: logic.requiredComponents
            )
        }

        let result = MockupAnalysisResult(
            uiElements: uiElements,
            layoutStructure: layoutStructure,
            extractedText: extractedText,
            colorScheme: colorScheme,
            inferredUserFlows: userFlows,
            businessLogicInferences: businessLogic
        )

        return (result, response.overallConfidence)
    }
}
