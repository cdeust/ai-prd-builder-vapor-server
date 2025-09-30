import Foundation

public struct UIElement: Sendable, Codable, Equatable {
    public let type: UIElementType
    public let label: String?
    public let bounds: ElementBounds
    public let confidence: Double

    public init(type: UIElementType, label: String?, bounds: ElementBounds, confidence: Double) {
        self.type = type
        self.label = label
        self.bounds = bounds
        self.confidence = confidence
    }
}
