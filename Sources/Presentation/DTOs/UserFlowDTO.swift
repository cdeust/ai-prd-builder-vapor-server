import Foundation
import Vapor

public struct UserFlowDTO: Content {
    let flowName: String
    let steps: [String]
    let confidence: Double
}
