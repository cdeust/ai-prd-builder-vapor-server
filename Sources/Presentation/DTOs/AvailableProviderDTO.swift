import Foundation
import Vapor

struct AvailableProviderDTO: Content {
    let id: String
    let name: String
    let description: String
    let isAvailable: Bool
    let priority: Int
    let requiresApiKey: Bool
    let model: String?

    init(id: String, name: String, description: String, isAvailable: Bool, priority: Int, requiresApiKey: Bool, model: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.isAvailable = isAvailable
        self.priority = priority
        self.requiresApiKey = requiresApiKey
        self.model = model
    }
}
