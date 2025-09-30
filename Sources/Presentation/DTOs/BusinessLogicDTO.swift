import Foundation
import Vapor

public struct BusinessLogicDTO: Content {
    let feature: String
    let description: String
    let confidence: Double
    let requiredComponents: [String]
}
