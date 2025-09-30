import Foundation

struct GeminiMockupAnalysisResponse: Codable {
    let extractedFeatures: [String]
    let userFlows: [String]
    let uiComponents: [String]
    let businessLogic: [String]
}
