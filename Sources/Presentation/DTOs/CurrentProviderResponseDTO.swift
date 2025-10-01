import Foundation
import Vapor

struct CurrentProviderResponseDTO: Content {
    let name: String
    let priority: Int
    let isAvailable: Bool
    let configuredProvider: String
}
