import Foundation
import Domain

struct ClaudeResponseParser {
    private let sectionExtractor = SectionExtractor()

    func extractSections(from content: String) -> [GeneratedSection] {
        return sectionExtractor.extractSections(from: content)
    }

    func parseRequirementsAnalysis(_ content: String) -> Domain.RequirementsAnalysis {
        if let jsonData = extractJSON(from: content),
           let data = jsonData.data(using: .utf8),
           let analysisResponse = try? JSONDecoder().decode(RequirementsAnalysisResponse.self, from: data) {
            return Domain.RequirementsAnalysis(
                confidence: Double(analysisResponse.confidence) / 100.0,
                clarificationsNeeded: analysisResponse.clarificationsNeeded,
                assumptions: analysisResponse.assumptions,
                gaps: analysisResponse.gaps
            )
        }

        return Domain.RequirementsAnalysis(
            confidence: 0.5,
            clarificationsNeeded: ["Unable to parse analysis - please provide more details"],
            assumptions: [],
            gaps: ["Analysis parsing failed"]
        )
    }

    func parseMockupAnalysis(_ content: String) -> Domain.MockupAnalysis {
        if let jsonData = extractJSON(from: content),
           let data = jsonData.data(using: .utf8),
           let analysisResponse = try? JSONDecoder().decode(MockupAnalysisResponse.self, from: data) {
            return Domain.MockupAnalysis(
                extractedFeatures: analysisResponse.extractedFeatures,
                userFlows: analysisResponse.userFlows,
                uiComponents: analysisResponse.uiComponents,
                businessLogic: analysisResponse.businessLogic
            )
        }

        return Domain.MockupAnalysis(
            extractedFeatures: [],
            userFlows: [],
            uiComponents: [],
            businessLogic: []
        )
    }

    func calculateConfidence(response: ClaudeResponse) -> Double {
        let contentLength = response.content.count

        var confidence = 0.7

        if contentLength > 1000 {
            confidence += 0.1
        }
        if contentLength > 2000 {
            confidence += 0.1
        }

        let headerCount = response.content.components(separatedBy: "# ").count - 1
        confidence += min(0.1, Double(headerCount) * 0.02)

        return min(1.0, confidence)
    }

    private func extractJSON(from content: String) -> String? {
        let pattern = #"\{(?:[^{}]|(?:\{[^{}]*\}))*\}"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let nsString = content as NSString
        let matches = regex?.matches(in: content, options: [], range: NSRange(location: 0, length: nsString.length))

        return matches?.first.map { nsString.substring(with: $0.range) }
    }
}