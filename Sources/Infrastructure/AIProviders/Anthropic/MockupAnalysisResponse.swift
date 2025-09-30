import Foundation

struct MockupAnalysisResponse: Codable {
    let extractedFeatures: [String]
    let userFlows: [String]
    let uiComponents: [String]
    let businessLogic: [String]
}
