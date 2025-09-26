import Foundation

public enum SectionType: String, CaseIterable, Sendable {
    case executiveSummary
    case problemStatement
    case userStories
    case functionalRequirements
    case nonFunctionalRequirements
    case technicalRequirements
    case acceptanceCriteria
    case timeline
    case risks
    case appendix
}