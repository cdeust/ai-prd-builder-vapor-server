import Foundation
import Domain
import PRDGenerator
import CommonModels
import DomainCore
import Orchestration
import AIProvidersCore
import AIProviderImplementations
import ThinkingCore

final class WebSocketInteractionHandler: UserInteractionHandler, @unchecked Sendable {
    private let progressCallback: @Sendable (String) async -> Void

    init(progressCallback: @escaping @Sendable (String) async -> Void) {
        self.progressCallback = progressCallback
    }

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
        Task { [progressCallback] in
            await progressCallback(message)
        }
    }

    func showWarning(_ message: String) {
        Task { [progressCallback] in
            await progressCallback(message)
        }
    }

    func showProgress(_ message: String) {
        Task { [progressCallback] in
            await progressCallback(message)
        }
    }

    func showDebug(_ message: String) {
        Task { [progressCallback] in
            await progressCallback(message)
        }
    }

    func showSectionContent(_ content: String) {
        Task { [progressCallback] in
            await progressCallback(content)
        }
    }
}
