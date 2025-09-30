import Vapor
import PRDGenerator
import CommonModels
import DomainCore
import AIProvidersCore
import AIProviderImplementations

struct ClientMessage: Codable {
    let type: String
    let input: String?
    let response: String?
    let useChainOfThought: Bool?
    let useSelfConsistency: Bool?
}
