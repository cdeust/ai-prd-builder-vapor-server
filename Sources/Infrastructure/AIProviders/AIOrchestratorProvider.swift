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
    private var prdGenerator: PRDGeneratorService?

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

    public func generatePRD(
        from request: GeneratePRDCommand,
        contextRequestPort: ContextRequestPort? = nil
    ) async throws -> PRDGenerationResult {
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
            // Use standardized prompt with XML markup for better results
            let prompt = StandardizedPrompts.buildRequirementsAnalysisPrompt(text)
            let (analysisResponse, _) = try await orchestrator.chat(message: prompt)
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
    ) async throws -> PRDGeneratorService {
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
        let generator = PRDGeneratorService(
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
