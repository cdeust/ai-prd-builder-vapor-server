import Foundation
import Vapor

public struct ColorSchemeDTO: Content {
    let primaryColors: [String]
    let accentColors: [String]
    let textColors: [String]
    let backgroundColors: [String]
}
