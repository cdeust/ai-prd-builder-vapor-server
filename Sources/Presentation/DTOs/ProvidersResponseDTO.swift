import Foundation
import Vapor

/// DTO for provider information
public struct ProvidersResponseDTO: Content {
    public let providers: [ProviderStatusDTO]

    public init(providers: [ProviderStatusDTO]) {
        self.providers = providers
    }
}