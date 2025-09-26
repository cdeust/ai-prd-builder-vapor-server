import Foundation
import Domain

struct ResponseParser {
    func parseRequirementsAnalysis(from response: String) throws -> Domain.RequirementsAnalysis {
        let confidence = extractConfidence(from: response)
        let clarifications = extractList(from: response, section: "Clarifications")
        let assumptions = extractList(from: response, section: "Assumptions")
        let gaps = extractList(from: response, section: "Gaps")

        return Domain.RequirementsAnalysis(
            confidence: confidence,
            clarificationsNeeded: clarifications,
            assumptions: assumptions,
            gaps: gaps
        )
    }

    func parseMockupAnalysis(from response: String) throws -> Domain.MockupAnalysis {
        let features = extractList(from: response, section: "Features")
        let flows = extractList(from: response, section: "User Flows")
        let components = extractList(from: response, section: "UI Components")
        let logic = extractList(from: response, section: "Business Logic")

        return Domain.MockupAnalysis(
            extractedFeatures: features,
            userFlows: flows,
            uiComponents: components,
            businessLogic: logic
        )
    }

    func extractQuestions(from response: String) -> [String] {
        let questions = extractList(from: response, section: "Questions")
        return questions.isEmpty ? extractList(from: response, section: "Clarifications") : questions
    }

    private func extractConfidence(from response: String) -> Double {
        let patterns = [
            "confidence: (\\d+)",
            "(\\d+)% confident",
            "confidence score: (\\d+)"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: response, options: [], range: NSRange(location: 0, length: response.count)),
               match.numberOfRanges > 1 {
                let range = match.range(at: 1)
                if let swiftRange = Range(range, in: response) {
                    let confidenceStr = String(response[swiftRange])
                    if let value = Double(confidenceStr) {
                        return min(max(value / 100.0, 0.0), 1.0)
                    }
                }
            }
        }

        return 0.75
    }

    private func extractList(from response: String, section: String) -> [String] {
        let lines = response.components(separatedBy: .newlines)
        var inSection = false
        var items: [String] = []

        for line in lines {
            if line.lowercased().contains(section.lowercased()) {
                inSection = true
                continue
            }

            if inSection {
                if line.isEmpty || (line.contains(":") && !line.starts(with: "-") && !line.starts(with: "*")) {
                    break
                }

                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.starts(with: "-") || trimmed.starts(with: "*") || trimmed.starts(with: "•") {
                    let item = trimmed
                        .dropFirst()
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !item.isEmpty {
                        items.append(String(item))
                    }
                } else if !trimmed.isEmpty {
                    items.append(trimmed)
                }
            }
        }

        return items
    }
}