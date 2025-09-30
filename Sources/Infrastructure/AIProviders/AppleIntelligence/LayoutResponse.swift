import Foundation
import AsyncHTTPClient
import NIOCore
import Domain

struct LayoutResponse: Codable {
    let screenType: String
    let hierarchyLevels: Int
    let layoutType: String
    let componentGroups: [ComponentGroupResponse]
}
