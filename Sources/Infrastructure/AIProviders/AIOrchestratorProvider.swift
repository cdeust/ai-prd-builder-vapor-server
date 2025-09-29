import Foundation
import Domain
import PRDGenerator
import CommonModels
import DomainCore
import Orchestration
import AIProvidersCore
import AIProviderImplementations
import ThinkingCore

public final class AIOrchestratorProvider: AIProviderPort, @unchecked Sendable {
    public let name: String = "ai-orchestrator"
    public let priority: Int = 100

    private let orchestrator: Orchestrator
    private let providerCoordinator: AIProviderCoordinator
    private let configuration: Configuration
    private var prdGenerator: PRDGenerator?

    private let inputBuilder = PRDInputBuilder()
    private let responseParser = ResponseParser()
    private let prdConverter = PRDConverter()
    private let capabilitiesMapper = ProviderCapabilitiesMapper()
    private let errorConverter = AIProviderErrorConverter()

    public init() throws {
        self.configuration = Self.createConfiguration()
        self.providerCoordinator = AIProviderCoordinator()

        let privacyConfig = Orchestrator.PrivacyConfiguration(
            allowExternalProviders: configuration.maxPrivacyLevel != .onDevice,
            requireUserConsent: false,
            logExternalCalls: true
        )
        self.orchestrator = Orchestrator(privacyConfig: privacyConfig)
    }

    public var isAvailable: Bool {
        get async {
            let providers = orchestrator.getAvailableProviders()
            return !providers.isEmpty
        }
    }

    public func generatePRD(from request: GeneratePRDCommand) async throws -> PRDGenerationResult {
        let startTime = Date()
        let generator = try await getOrCreatePRDGenerator(preferredProvider: request.preferredProvider)

        do {
            let prdInput = try inputBuilder.build(from: request)
            let prdDocument = try await generator.generatePRD(from: prdInput)
            let processingTime = Date().timeIntervalSince(startTime)
            let providerName = providerCoordinator.getCurrentProvider()?.name ?? "ai-orchestrator"

            return try prdConverter.convert(
                prdDocument: prdDocument,
                processingTime: processingTime,
                providerName: providerName
            )
        } catch {
            throw errorConverter.convert(error)
        }
    }

    public func analyzeRequirements(_ text: String) async throws -> Domain.RequirementsAnalysis {
        do {
            let (analysisResponse, _) = try await orchestrator.chat(
                message: "Analyze the following requirements and identify clarifications needed, assumptions, and gaps: \(text)"
            )
            return try responseParser.parseRequirementsAnalysis(from: analysisResponse)
        } catch {
            throw errorConverter.convert(error)
        }
    }

    public func extractFromMockups(_ sources: [MockupSource]) async throws -> Domain.MockupAnalysis {
        do {
            let mockupPaths = sources.compactMap { $0.localPath ?? $0.url?.path }

            let mockupPrompt = inputBuilder.buildMockupAnalysisPrompt(paths: mockupPaths)
            let (analysisResponse, _) = try await orchestrator.chat(message: mockupPrompt)

            return try responseParser.parseMockupAnalysis(from: analysisResponse)
        } catch {
            throw errorConverter.convert(error)
        }
    }

    public func generatePRDWithClarifications(
        from request: GeneratePRDCommand,
        clarificationHandler: @escaping ([String]) async throws -> [String],
        progressHandler: (@Sendable (String) async -> Void)? = nil,
        sectionHandler: (@Sendable (String, String, Int) async -> Void)? = nil
    ) async throws -> PRDGenerationResult {
        let startTime = Date()

        let generator = try await getOrCreatePRDGenerator(
            preferredProvider: request.preferredProvider,
            progressHandler: progressHandler,
            sectionHandler: sectionHandler,
            clarificationHandler: clarificationHandler
        )
        let prdInput = try inputBuilder.build(from: request)
        let prdDocument = try await generator.generatePRD(from: prdInput)
        let processingTime = Date().timeIntervalSince(startTime)
        let providerName = providerCoordinator.getCurrentProvider()?.name ?? "ai-orchestrator"

        return try prdConverter.convert(
            prdDocument: prdDocument,
            processingTime: processingTime,
            providerName: providerName
        )
    }

    public func getAvailableProviders() async throws -> [ProviderStatus] {
        let availableProviders = orchestrator.getAvailableProviders()
        let coordinatorProviders = providerCoordinator.availableProviders()

        return coordinatorProviders.map { providerName in
            let isAvailable = availableProviders.contains { $0.rawValue == providerName }
            let isCurrentProvider = providerCoordinator.getCurrentProvider()?.name == providerName

            return ProviderStatus(
                name: providerName,
                isAvailable: isAvailable,
                priority: isCurrentProvider ? 100 : 50,
                capabilities: capabilitiesMapper.getCapabilities(for: providerName),
                lastUsed: nil
            )
        }
    }

    public func generatePRDWithProvider(
        from request: GeneratePRDCommand,
        providerName: String
    ) async throws -> PRDGenerationResult {
        let switched = providerCoordinator.switchProvider(to: providerName)
        if !switched {
            throw DomainError.validation("Provider '\(providerName)' is not available")
        }
        return try await generatePRD(from: request)
    }

    public func exportPRD(
        _ result: PRDGenerationResult,
        format: ExportFormat
    ) async throws -> ExportedDocument {
        let (sections, title) = prdConverter.convertToExportDocument(result, format: format)
        let document = PRDocument(title: title, sections: sections)

        let exporter = PRDExporter()
        let exportFormat = prdConverter.mapExportFormat(format)
        let exportedContent = try exporter.export(document: document, format: exportFormat)

        return ExportedDocument(
            content: exportedContent,
            format: format.rawValue,
            metadata: ExportMetadata(exportedAt: Date(), version: "1.0.0")
        )
    }

    private func getOrCreatePRDGenerator(
        preferredProvider: String? = nil,
        progressHandler: (@Sendable (String) async -> Void)? = nil,
        sectionHandler: (@Sendable (String, String, Int) async -> Void)? = nil,
        clarificationHandler: (([String]) async throws -> [String])? = nil
    ) async throws -> PRDGenerator {
        if let preferredProvider = preferredProvider {
            _ = providerCoordinator.switchProvider(to: preferredProvider)
        }

        guard let selectedProvider = providerCoordinator.getCurrentProvider() else {
            throw DomainError.processingFailed("No AI provider available")
        }

        let interactionHandler: UserInteractionHandler?

        if let progressHandler = progressHandler, let sectionHandler = sectionHandler, let clarificationHandler = clarificationHandler {
            print("[AIOrchestratorProvider] ✅ Creating StreamingWebSocketInteractionHandler")
            interactionHandler = StreamingWebSocketInteractionHandler(
                progressCallback: progressHandler,
                sectionCallback: sectionHandler,
                clarificationCallback: clarificationHandler
            )
        } else {
            print("[AIOrchestratorProvider] ⚠️ Missing handlers - progress:\(progressHandler != nil) section:\(sectionHandler != nil) clarification:\(clarificationHandler != nil)")
            if let progressHandler = progressHandler {
                print("[AIOrchestratorProvider] Creating basic WebSocketInteractionHandler")
                interactionHandler = WebSocketInteractionHandler(progressCallback: progressHandler)
            } else {
                print("[AIOrchestratorProvider] ❌ No handler - PRDGenerator will print to console only!")
                interactionHandler = nil
            }
        }

        print("[AIOrchestratorProvider] Creating PRDGenerator with handler: \(interactionHandler != nil ? "YES" : "NO")")
        let generator = PRDGenerator(
            provider: selectedProvider,
            configuration: configuration,
            interactionHandler: interactionHandler
        )

        return generator
    }

    private static func createConfiguration() -> Configuration {
        return Configuration(
            anthropicAPIKey: ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"],
            openAIAPIKey: ProcessInfo.processInfo.environment["OPENAI_API_KEY"],
            geminiAPIKey: ProcessInfo.processInfo.environment["GEMINI_API_KEY"],
            maxPrivacyLevel: parsePrivacyLevel(ProcessInfo.processInfo.environment["MAX_PRIVACY_LEVEL"] ?? "onDevice"),
            preferredProvider: ProcessInfo.processInfo.environment["PREFERRED_PROVIDER"],
            modelPreferences: ModelPreferences(),
            debugMode: ProcessInfo.processInfo.environment["DEBUG_MODE"] == "true",
            enableClarificationPrompts: ProcessInfo.processInfo.environment["ENABLE_CLARIFICATIONS"] != "false"
        )
    }

    private static func parsePrivacyLevel(_ value: String) -> PrivacyLevel {
        switch value.lowercased() {
        case "ondevice", "on-device":
            return .onDevice
        case "privatecloud", "private-cloud":
            return .privateCloud
        case "external":
            return .external
        default:
            return .onDevice
        }
    }
}

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