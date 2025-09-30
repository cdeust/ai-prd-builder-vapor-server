import Foundation

public struct MockupAnalysisResult: Sendable, Codable, Equatable {
    public let uiElements: [UIElement]
    public let layoutStructure: LayoutStructure
    public let extractedText: [ExtractedText]
    public let colorScheme: ColorScheme?
    public let inferredUserFlows: [UserFlow]
    public let businessLogicInferences: [BusinessLogicInference]
    public let analyzedAt: Date

    public init(
        uiElements: [UIElement],
        layoutStructure: LayoutStructure,
        extractedText: [ExtractedText],
        colorScheme: ColorScheme? = nil,
        inferredUserFlows: [UserFlow],
        businessLogicInferences: [BusinessLogicInference],
        analyzedAt: Date = Date()
    ) {
        self.uiElements = uiElements
        self.layoutStructure = layoutStructure
        self.extractedText = extractedText
        self.colorScheme = colorScheme
        self.inferredUserFlows = inferredUserFlows
        self.businessLogicInferences = businessLogicInferences
        self.analyzedAt = analyzedAt
    }
}

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

public enum UIElementType: String, Sendable, Codable {
    case button
    case textField
    case label
    case image
    case icon
    case navigationBar
    case tabBar
    case tableView
    case collectionView
    case card
    case dropdown
    case checkbox
    case radioButton
    case slider
    case toggle
    case searchBar
    case other
}

public struct ElementBounds: Sendable, Codable, Equatable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

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

public enum ScreenType: String, Sendable, Codable {
    case login
    case dashboard
    case form
    case list
    case detail
    case settings
    case profile
    case search
    case other
}

public enum LayoutType: String, Sendable, Codable {
    case vertical
    case horizontal
    case grid
    case stack
    case card
    case mixed
}

public struct ComponentGroup: Sendable, Codable, Equatable {
    public let name: String
    public let components: [String]
    public let purpose: String?

    public init(name: String, components: [String], purpose: String?) {
        self.name = name
        self.components = components
        self.purpose = purpose
    }
}

public struct ExtractedText: Sendable, Codable, Equatable {
    public let text: String
    public let category: TextCategory
    public let bounds: ElementBounds

    public init(text: String, category: TextCategory, bounds: ElementBounds) {
        self.text = text
        self.category = category
        self.bounds = bounds
    }
}

public enum TextCategory: String, Sendable, Codable {
    case heading
    case subheading
    case body
    case label
    case button
    case placeholder
    case error
    case other
}

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

public struct UserFlow: Sendable, Codable, Equatable {
    public let flowName: String
    public let steps: [String]
    public let confidence: Double

    public init(flowName: String, steps: [String], confidence: Double) {
        self.flowName = flowName
        self.steps = steps
        self.confidence = confidence
    }
}

public struct BusinessLogicInference: Sendable, Codable, Equatable {
    public let feature: String
    public let description: String
    public let confidence: Double
    public let requiredComponents: [String]

    public init(feature: String, description: String, confidence: Double, requiredComponents: [String]) {
        self.feature = feature
        self.description = description
        self.confidence = confidence
        self.requiredComponents = requiredComponents
    }
}