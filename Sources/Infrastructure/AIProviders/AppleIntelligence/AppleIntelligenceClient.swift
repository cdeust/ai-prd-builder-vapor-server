import Foundation
import AsyncHTTPClient
import NIOCore
import Domain

public final class AppleIntelligenceClient: MockupAnalysisPort {
    private let httpClient: HTTPClient
    private let apiKey: String
    private let baseURL: String

    public init(
        httpClient: HTTPClient,
        apiKey: String,
        baseURL: String = "https://api.intelligence.apple.com/v1"
    ) {
        self.httpClient = httpClient
        self.apiKey = apiKey
        self.baseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
    }

    public func analyzeMockup(
        imageURL: String,
        context: MockupAnalysisContext
    ) async throws -> (result: MockupAnalysisResult, confidence: Double) {
        let prompt = buildAnalysisPrompt(context: context)
        let response = try await sendAnalysisRequest(imageURL: imageURL, prompt: prompt)
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
        do {
            var request = HTTPClientRequest(url: "\(baseURL)/health")
            request.method = .GET
            request.headers.add(name: "Authorization", value: "Bearer \(apiKey)")

            let response = try await httpClient.execute(request, timeout: .seconds(10))
            return response.status == .ok
        } catch {
            return false
        }
    }

    private func buildAnalysisPrompt(context: MockupAnalysisContext) -> String {
        return """
        Analyze this UI mockup image for a PRD titled "\(context.requestTitle)".

        Project Description: \(context.requestDescription)

        Please provide a comprehensive analysis including:

        1. UI Elements: Identify all interactive components (buttons, text fields, dropdowns, etc.) with their approximate positions and labels.

        2. Layout Structure: Describe the overall layout type (vertical, horizontal, grid, etc.), screen type (login, dashboard, form, etc.), and component hierarchy.

        3. Extracted Text: List all visible text including headings, labels, button text, and placeholder text with their categories.

        4. Color Scheme: Identify primary colors, accent colors, text colors, and background colors used in the design.

        5. User Flows: Infer possible user interaction flows based on the UI elements and their arrangement.

        6. Business Logic: Deduce potential business requirements and features based on the UI elements present.

        Provide your analysis in a structured JSON format with confidence scores for inferences.
        """
    }

    private func sendAnalysisRequest(imageURL: String, prompt: String) async throws -> VisionAnalysisResponse {
        let requestBody = VisionAnalysisRequest(
            imageURL: imageURL,
            prompt: prompt,
            features: ["ui_detection", "text_recognition", "layout_analysis", "color_extraction"]
        )

        let requestData = try JSONEncoder().encode(requestBody)

        var request = HTTPClientRequest(url: "\(baseURL)/vision/analyze")
        request.method = .POST
        request.headers.add(name: "Authorization", value: "Bearer \(apiKey)")
        request.headers.add(name: "Content-Type", value: "application/json")
        request.body = .bytes(requestData)

        print("[AppleIntelligenceClient] Sending analysis request for: \(imageURL)")
        let response = try await httpClient.execute(request, timeout: .seconds(120))

        guard response.status == .ok else {
            let errorBody = try await response.body.collect(upTo: 1024 * 1024)
            let errorMessage = String(buffer: errorBody)
            print("[AppleIntelligenceClient] Analysis error: \(errorMessage)")
            throw DomainError.processingFailed("Vision analysis failed: \(response.status) - \(errorMessage)")
        }

        let responseBody = try await response.body.collect(upTo: 10 * 1024 * 1024)
        let responseData = try JSONDecoder().decode(VisionAnalysisResponse.self, from: responseBody)
        print("[AppleIntelligenceClient] Analysis completed with confidence: \(responseData.overallConfidence)")
        return responseData
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
                ComponentGroup(name: group.name, components: group.components, purpose: group.purpose)
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
            UserFlow(flowName: flow.name, steps: flow.steps, confidence: flow.confidence)
        }

        let businessLogic = response.businessLogic.map { logic in
            BusinessLogicInference(
                feature: logic.feature,
                description: logic.description,
                confidence: logic.confidence,
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

private struct VisionAnalysisRequest: Codable {
    let imageURL: String
    let prompt: String
    let features: [String]
}

private struct VisionAnalysisResponse: Codable {
    let uiElements: [UIElementResponse]
    let layout: LayoutResponse
    let extractedText: [TextResponse]
    let colorScheme: ColorSchemeResponse?
    let inferredFlows: [FlowResponse]
    let businessLogic: [BusinessLogicResponse]
    let overallConfidence: Double
}

private struct UIElementResponse: Codable {
    let type: String
    let label: String?
    let bounds: BoundsResponse
    let confidence: Double
}

private struct BoundsResponse: Codable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

private struct LayoutResponse: Codable {
    let screenType: String
    let hierarchyLevels: Int
    let layoutType: String
    let componentGroups: [ComponentGroupResponse]
}

private struct ComponentGroupResponse: Codable {
    let name: String
    let components: [String]
    let purpose: String?
}

private struct TextResponse: Codable {
    let content: String
    let category: String
    let bounds: BoundsResponse
}

private struct ColorSchemeResponse: Codable {
    let primary: [String]
    let accent: [String]
    let text: [String]
    let background: [String]
}

private struct FlowResponse: Codable {
    let name: String
    let steps: [String]
    let confidence: Double
}

private struct BusinessLogicResponse: Codable {
    let feature: String
    let description: String
    let confidence: Double
    let requiredComponents: [String]
}