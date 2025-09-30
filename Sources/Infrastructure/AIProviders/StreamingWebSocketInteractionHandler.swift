import Foundation
import Domain
import PRDGenerator
import CommonModels
import DomainCore
import Orchestration
import AIProvidersCore
import AIProviderImplementations
import ThinkingCore

final class StreamingWebSocketInteractionHandler: UserInteractionHandler, @unchecked Sendable {
    private let progressCallback: @Sendable (String) async -> Void
    private let sectionCallback: @Sendable (String, String, Int) async -> Void
    private let clarificationCallback: ([String]) async throws -> [String]

    private var currentSectionTitle: String?
    private var currentSectionContent: String?
    private var isCapturingContent = false
    private var capturedContentLines: [String] = []
    private var sectionOrder = 0

    private let messageQueue = DispatchQueue(label: "com.prd.websocket.messages", qos: .userInitiated)

    init(
        progressCallback: @escaping @Sendable (String) async -> Void,
        sectionCallback: @escaping @Sendable (String, String, Int) async -> Void,
        clarificationCallback: @escaping ([String]) async throws -> [String]
    ) {
        self.progressCallback = progressCallback
        self.sectionCallback = sectionCallback
        self.clarificationCallback = clarificationCallback
    }

    func askQuestion(_ question: String) async -> String {
        print("[StreamingHandler] ❓ Question asked: \(question)")

        do {
            let answers = try await clarificationCallback([question])
            return answers.first ?? ""
        } catch {
            print("[StreamingHandler] ❌ Error getting answer: \(error)")
            return ""
        }
    }

    func askMultipleChoice(_ question: String, options: [String]) async -> String {
        print("[StreamingHandler] ❓ Multiple choice question: \(question)")
        print("[StreamingHandler] Options: \(options)")

        do {
            let answers = try await clarificationCallback([question])
            return answers.first ?? options.first ?? ""
        } catch {
            print("[StreamingHandler] ❌ Error getting answer: \(error)")
            return options.first ?? ""
        }
    }

    func askYesNo(_ question: String) async -> Bool {
        print("[StreamingHandler] ❓ Yes/No question: \(question)")

        do {
            let answers = try await clarificationCallback([question])
            let answer = answers.first?.lowercased() ?? "no"
            return answer == "yes" || answer == "y" || answer == "true"
        } catch {
            print("[StreamingHandler] ❌ Error getting answer: \(error)")
            return false
        }
    }

    func showInfo(_ message: String) {
        print("[StreamingHandler] 📥 Received: \(message)")

        messageQueue.async { [weak self] in
            guard let self = self else { return }

            let group = DispatchGroup()
            group.enter()

            Task {
                await self.handleMessage(message)
                group.leave()
            }

            group.wait()
            print("[StreamingHandler] ✅ Sent: \(message)")
        }
    }

    private func handleMessage(_ message: String) async {
        print("[StreamingHandler] 📢 Message: \(message)")

        if message == "📝 SECTION_CONTENT_START" {
            isCapturingContent = true
            capturedContentLines = []
            print("[StreamingHandler] 📝 Started capturing section content")
        } else if message == "📝 SECTION_CONTENT_END" {
            isCapturingContent = false
            currentSectionContent = capturedContentLines.joined(separator: "\n")
            print("[StreamingHandler] 📝 Finished capturing section content (\(capturedContentLines.count) lines)")
            capturedContentLines = []
        } else if isCapturingContent {
            capturedContentLines.append(message)
        } else if message.contains("🔄 Generating:") {
            await sendPreviousSectionIfNeeded()

            let title = message
                .replacingOccurrences(of: "🔄 Generating:", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            currentSectionTitle = title
            currentSectionContent = nil

            print("[StreamingHandler] 🆕 Starting new section: \(title)")
        } else if message.contains("✅") && message.contains("complete") {
            await sendPreviousSectionIfNeeded()
            currentSectionTitle = nil
            currentSectionContent = nil
        }

        if !isCapturingContent {
            await progressCallback(message)
        }
    }

    private func sendPreviousSectionIfNeeded() async {
        guard let title = currentSectionTitle, let content = currentSectionContent, !content.isEmpty else {
            return
        }

        sectionOrder += 1

        print("[StreamingHandler] 📄 Sending section to preview: \(title) (order: \(sectionOrder))")
        print("[StreamingHandler] 📄 Content length: \(content.count) characters")
        await sectionCallback(title, content, sectionOrder)

        currentSectionContent = nil
    }

    func showWarning(_ message: String) {
        print("[StreamingHandler] ⚠️ Warning: \(message)")
        showInfo(message)
    }

    func showProgress(_ message: String) {
        print("[StreamingHandler] ⏳ Progress: \(message)")
        showInfo(message)
    }

    func showDebug(_ message: String) {
        print("[StreamingHandler] 🔍 Debug: \(message)")
        showInfo(message)
    }

    func showSectionContent(_ content: String) {
        print("[StreamingHandler] 📝 Section content received")
        showInfo(content)
    }

    // MARK: - Professional Analysis Methods

    func showProfessionalAnalysis(_ summary: String, hasCritical: Bool) {
        print("[StreamingHandler] 🔬 Professional Analysis: \(summary)")
        Task {
            await progressCallback("🔬 Professional Analysis: \(hasCritical ? "⚠️ CRITICAL ISSUES FOUND" : "✅ No critical issues")")
            await progressCallback(summary)
        }
    }

    func showArchitecturalConflict(_ conflict: String, severity: String) {
        print("[StreamingHandler] ⚡ Architectural Conflict [\(severity)]: \(conflict)")
        Task {
            let icon = severity == "critical" ? "🔴" : severity == "high" ? "🟡" : "🟢"
            await progressCallback("\(icon) Conflict: \(conflict)")
        }
    }

    func showTechnicalChallenge(_ challenge: String, priority: String) {
        print("[StreamingHandler] 🚨 Technical Challenge [\(priority)]: \(challenge)")
        Task {
            let icon = priority == "critical" ? "🚨" : priority == "high" ? "⚠️" : "📋"
            await progressCallback("\(icon) Challenge: \(challenge)")
        }
    }

    func showComplexityScore(_ score: Int, needsBreakdown: Bool) {
        print("[StreamingHandler] 📊 Complexity Score: \(score) points")
        Task {
            await progressCallback("📊 Complexity: \(score) story points \(needsBreakdown ? "(needs breakdown)" : "")")
        }
    }
}
