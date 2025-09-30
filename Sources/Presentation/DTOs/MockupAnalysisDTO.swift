import Foundation
import Vapor
import Domain

public struct MockupAnalysisDTO: Content {
    let uiElements: [UIElementDTO]
    let layoutStructure: LayoutStructureDTO
    let extractedText: [String]
    let colorScheme: ColorSchemeDTO?
    let inferredUserFlows: [UserFlowDTO]
    let businessLogicInferences: [BusinessLogicDTO]
    let analyzedAt: Date

    static func from(_ analysis: MockupAnalysisResult) -> MockupAnalysisDTO {
        MockupAnalysisDTO(
            uiElements: analysis.uiElements.map { UIElementDTO(
                type: $0.type.rawValue,
                label: $0.label,
                confidence: $0.confidence
            )},
            layoutStructure: LayoutStructureDTO(
                screenType: analysis.layoutStructure.screenType.rawValue,
                hierarchyLevels: analysis.layoutStructure.hierarchyLevels,
                primaryLayout: analysis.layoutStructure.primaryLayout.rawValue
            ),
            extractedText: analysis.extractedText.map { $0.text },
            colorScheme: analysis.colorScheme.map { ColorSchemeDTO(
                primaryColors: $0.primaryColors,
                accentColors: $0.accentColors,
                textColors: $0.textColors,
                backgroundColors: $0.backgroundColors
            )},
            inferredUserFlows: analysis.inferredUserFlows.map { UserFlowDTO(
                flowName: $0.flowName,
                steps: $0.steps,
                confidence: $0.confidence
            )},
            businessLogicInferences: analysis.businessLogicInferences.map { BusinessLogicDTO(
                feature: $0.feature,
                description: $0.description,
                confidence: $0.confidence,
                requiredComponents: $0.requiredComponents
            )},
            analyzedAt: analysis.analyzedAt
        )
    }
}
