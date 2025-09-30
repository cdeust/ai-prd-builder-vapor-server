import Foundation

public struct ColorScheme: Sendable, Codable, Equatable {
    public let primaryColors: [String]
    public let accentColors: [String]
    public let textColors: [String]
    public let backgroundColors: [String]

    public init(
        primaryColors: [String],
        accentColors: [String],
        textColors: [String],
        backgroundColors: [String]
    ) {
        self.primaryColors = primaryColors
        self.accentColors = accentColors
        self.textColors = textColors
        self.backgroundColors = backgroundColors
    }
}
