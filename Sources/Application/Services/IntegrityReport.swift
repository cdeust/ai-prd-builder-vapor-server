import Foundation
import Domain

public struct IntegrityReport: Sendable, CustomStringConvertible {
    public let totalChecked: Int
    public let missingInStorage: Int
    public let missingUploads: [UUID]

    public var description: String {
        "Checked: \(totalChecked), Missing: \(missingInStorage)"
    }

    public init(totalChecked: Int, missingInStorage: Int, missingUploads: [UUID]) {
        self.totalChecked = totalChecked
        self.missingInStorage = missingInStorage
        self.missingUploads = missingUploads
    }
}
