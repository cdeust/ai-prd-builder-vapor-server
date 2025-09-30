import Foundation

struct GeminiRequirementsAnalysisResponse: Codable {
    let confidence: Int
    let clarificationsNeeded: [String]
    let assumptions: [String]
    let gaps: [String]
}
