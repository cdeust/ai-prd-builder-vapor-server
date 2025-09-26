import Foundation

/// Status of PRD generation
public enum GenerationStatus: String, CaseIterable {
    case needsClarification = "needs_clarification"
    case completed = "completed"
    case failed = "failed"
}