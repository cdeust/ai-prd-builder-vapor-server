import Foundation
import Vapor

/// DTO for provider health status
public struct ProviderHealthResponseDTO: Content {
    public let providers: [String: ProviderHealthDTO]

    public init(providers: [String: ProviderHealthDTO]) {
        self.providers = providers
    }
}