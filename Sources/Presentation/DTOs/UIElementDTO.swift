import Foundation
import Vapor

public struct UIElementDTO: Content {
    let type: String
    let label: String?
    let confidence: Double
}
