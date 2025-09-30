import Foundation
import Domain
import PRDGenerator
import CommonModels
import DomainCore
import ThinkingCore
import Orchestration

final class NonInteractiveHandler: UserInteractionHandler {
    func askQuestion(_ question: String) async -> String {
        return ""
    }

    func askMultipleChoice(_ question: String, options: [String]) async -> String {
        return options.first ?? ""
    }

    func askYesNo(_ question: String) async -> Bool {
        return true
    }

    func showInfo(_ message: String) {
    }

    func showWarning(_ message: String) {
    }

    func showProgress(_ message: String) {
    }

    func showDebug(_ message: String) {
    }

    func showSectionContent(_ content: String) {
    }
}
