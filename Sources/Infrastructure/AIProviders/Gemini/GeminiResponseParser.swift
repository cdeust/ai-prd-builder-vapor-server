import Foundation
import Domain

struct GeminiResponseParser {
    private let sectionExtractor = SectionExtractor()

    func extractSections(from response: GeminiResponse) -> [GeneratedSection] {
        guard let content = getContent(from: response) else {
            return []
        }
        return sectionExtractor.extractSections(from: content)
    }

    func parseRequirementsAnalysis(from response: GeminiResponse) -> Domain.RequirementsAnalysis {
        guard let content = getContent(from: response) else {
            return createDefaultAnalysis()
        }

        if let jsonData = extractJSON(from: content),
           let data = jsonData.data(using: .utf8),
           let analysisResponse = try? JSONDecoder().decode(GeminiRequirementsAnalysisResponse.self, from: data) {
            return Domain.RequirementsAnalysis(
                confidence: Double(analysisResponse.confidence) / 100.0,
                clarificationsNeeded: analysisResponse.clarificationsNeeded,
                assumptions: analysisResponse.assumptions,
                gaps: analysisResponse.gaps
            )
        }

        return createDefaultAnalysis()
    }

    func parseMockupAnalysis(from response: GeminiResponse) -> Domain.MockupAnalysis {
        guard let content = getContent(from: response) else {
            return createDefaultMockupAnalysis()
        }

        if let jsonData = extractJSON(from: content),
           let data = jsonData.data(using: .utf8),
           let analysisResponse = try? JSONDecoder().decode(GeminiMockupAnalysisResponse.self, from: data) {
            return Domain.MockupAnalysis(
                extractedFeatures: analysisResponse.extractedFeatures,
                userFlows: analysisResponse.userFlows,
                uiComponents: analysisResponse.uiComponents,
                businessLogic: analysisResponse.businessLogic
            )
        }

        return createDefaultMockupAnalysis()
    }

    func calculateConfidence(response: GeminiResponse) -> Double {
        guard let content = getContent(from: response) else {
            return 0.5
        }

        let contentLength = content.count

        var confidence = 0.7

        if contentLength > 1000 {
            confidence += 0.1
        }
        if contentLength > 2000 {
            confidence += 0.1
        }

        let headerCount = content.components(separatedBy: "# ").count - 1
        confidence += min(0.1, Double(headerCount) * 0.02)

        return min(1.0, confidence)
    }

    private func getContent(from response: GeminiResponse) -> String? {
        return response.candidates?.first?.content.parts.first?.text
    }

    private func extractJSON(from content: String) -> String? {
        let pattern = #"\{(?:[^{}]|(?:\{[^{}]*\}))*\}"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let nsString = content as NSString
        let matches = regex?.matches(in: content, options: [], range: NSRange(location: 0, length: nsString.length))

        return matches?.first.map { nsString.substring(with: $0.range) }
    }

    private func createDefaultAnalysis() -> Domain.RequirementsAnalysis {
        return Domain.RequirementsAnalysis(
            confidence: 0.5,
            clarificationsNeeded: ["Unable to parse analysis - please provide more details"],
            assumptions: [],
            gaps: ["Analysis parsing failed"]
        )
    }

    private func createDefaultMockupAnalysis() -> Domain.MockupAnalysis {
        return Domain.MockupAnalysis(
            extractedFeatures: [],
            userFlows: [],
            uiComponents: [],
            businessLogic: []
        )
    }
}