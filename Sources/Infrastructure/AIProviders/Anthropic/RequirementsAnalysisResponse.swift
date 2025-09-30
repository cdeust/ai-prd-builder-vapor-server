import Foundation

struct RequirementsAnalysisResponse: Codable {
    let confidence: Int
    let clarificationsNeeded: [String]
    let assumptions: [String]
    let gaps: [String]
}
