import Foundation

public struct LayoutStructure: Sendable, Codable, Equatable {
    public let screenType: ScreenType
    public let hierarchyLevels: Int
    public let primaryLayout: LayoutType
    public let componentGroups: [ComponentGroup]

    public init(
        screenType: ScreenType,
        hierarchyLevels: Int,
        primaryLayout: LayoutType,
        componentGroups: [ComponentGroup]
    ) {
        self.screenType = screenType
        self.hierarchyLevels = hierarchyLevels
        self.primaryLayout = primaryLayout
        self.componentGroups = componentGroups
    }
}
