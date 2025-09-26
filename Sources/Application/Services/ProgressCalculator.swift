import Foundation
import Domain

/// Utility for calculating progress based on request status
public final class ProgressCalculator {

    public init() {}

    /// Calculate progress percentage based on status
    public func calculateProgress(for status: RequestStatus) -> Int {
        switch status {
        case .pending:
            return 0
        case .processing:
            return 50
        case .clarificationNeeded:
            return 25
        case .completed:
            return 100
        case .failed(_):
            return 0
        case .cancelled:
            return 0
        }
    }
}