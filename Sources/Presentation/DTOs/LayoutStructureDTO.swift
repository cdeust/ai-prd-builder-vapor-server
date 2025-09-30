import Foundation
import Vapor

public struct LayoutStructureDTO: Content {
    let screenType: String
    let hierarchyLevels: Int
    let primaryLayout: String
}
