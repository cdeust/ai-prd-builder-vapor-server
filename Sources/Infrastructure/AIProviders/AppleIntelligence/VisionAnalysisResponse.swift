import Foundation
import AsyncHTTPClient
import NIOCore
import Domain

struct VisionAnalysisResponse: Codable {
    let uiElements: [UIElementResponse]
    let layout: LayoutResponse
    let extractedText: [TextResponse]
    let colorScheme: ColorSchemeResponse?
    let inferredFlows: [FlowResponse]
    let businessLogic: [BusinessLogicResponse]
    let overallConfidence: Double
}
