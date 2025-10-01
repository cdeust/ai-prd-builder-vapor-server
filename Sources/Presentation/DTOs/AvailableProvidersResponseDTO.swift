import Foundation
import Vapor

struct AvailableProvidersResponseDTO: Content {
    let providers: [AvailableProviderDTO]
}
