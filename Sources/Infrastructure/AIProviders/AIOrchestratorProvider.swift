import Foundation
import Domain
import PRDGenerator
import CommonModels
import DomainCore
import Orchestration
import AIProvidersCore
import AIProviderImplementations
import ThinkingCore
import SessionManagement

/// AI Orchestrator provider that uses the existing Swift CLI ai-orchestrator
/// This bridges the Vapor server with the complete PRD generation system
public final class AIOrchestratorProvider: AIProviderPort {
    public let name: String = "ai-orchestrator"
    public let priority: Int = 100 // Highest priority - uses the full system

    private let orchestrator: Orchestrator
    private let sessionManager: SessionManager
    private let providerCoordinator: AIProviderCoordinator
    private let configuration: Configuration

    // Lazy-initialized PRD generator for on-demand generation
    private var prdGenerator: PRDGenerator?

    public init() throws {
        // Initialize configuration from environment or defaults
        self.configuration = Self.createConfiguration()

        // Initialize the provider coordinator
        self.providerCoordinator = AIProviderCoordinator()

        // Initialize the main orchestrator with privacy configuration
        let privacyConfig = Orchestrator.PrivacyConfiguration(
            allowExternalProviders: configuration.maxPrivacyLevel != .onDevice,
            requireUserConsent: false, // Server mode - consent handled by API
            logExternalCalls: true
        )
        self.orchestrator = Orchestrator(privacyConfig: privacyConfig)

        // Initialize session manager for handling interactive sessions
        self.sessionManager = SessionManager(orchestrator: orchestrator)

        // Note: Call initialize() after creation to complete async setup
    }

    /// Initialize the orchestrator and providers asynchronously
    public func initialize() async {
        await orchestrator.initialize()
    }

    public var isAvailable: Bool {
        get async {
            // Check if the orchestrator has available providers
            let providers = orchestrator.getAvailableProviders()
            return !providers.isEmpty
        }
    }

    public func generatePRD(from request: GeneratePRDCommand) async throws -> PRDGenerationResult {
        let startTime = Date()

        // Initialize PRD generator if needed
        let generator = try await getOrCreatePRDGenerator(preferredProvider: request.preferredProvider)

        do {
            // Build PRD input from request
            let prdInput = try buildPRDInput(from: request)

            // Generate PRD using the ai-orchestrator system
            let prdDocument = try await generator.generatePRD(from: prdInput)

            let processingTime = Date().timeIntervalSince(startTime)

            // Convert to Vapor format
            return try convertToPRDGenerationResult(
                prdDocument: prdDocument,
                processingTime: processingTime
            )

        } catch {
            throw convertError(error)
        }
    }

    public func analyzeRequirements(_ text: String) async throws -> Domain.RequirementsAnalysis {
        do {
            // Start a new session for analysis
            _ = sessionManager.startNewSession()

            // Use the chat interface to analyze requirements
            let (analysisResponse, _) = try await orchestrator.chat(
                message: "Analyze the following requirements and identify clarifications needed, assumptions, and gaps: \(text)"
            )

            // Parse the analysis response
            return try parseRequirementsAnalysis(from: analysisResponse)

        } catch {
            throw convertError(error)
        }
    }

    public func extractFromMockups(_ sources: [MockupSource]) async throws -> MockupAnalysis {
        do {
            // Build mockup paths from sources
            let mockupPaths = try sources.compactMap { source in
                source.localPath ?? source.url?.path
            }

            // Start a new session for mockup analysis
            _ = sessionManager.startNewSession()

            // Analyze mockups through orchestrator
            let mockupPrompt = buildMockupAnalysisPrompt(paths: mockupPaths)
            let (analysisResponse, _) = try await orchestrator.chat(
                message: mockupPrompt
            )

            // Parse the mockup analysis
            return try parseMockupAnalysis(from: analysisResponse)

        } catch {
            throw convertError(error)
        }
    }

    // MARK: - Helper Methods

    /// Create configuration from environment or defaults
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

    /// Parse privacy level from string
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

    /// Get or create PRD generator with appropriate provider
    private func getOrCreatePRDGenerator(preferredProvider: String? = nil) async throws -> PRDGenerator {
        if let existingGenerator = prdGenerator {
            return existingGenerator
        }

        // Select provider based on preference or use coordinator's default
        let provider: AIProvider
        if let preferredProvider = preferredProvider {
            _ = providerCoordinator.switchProvider(to: preferredProvider)
        }

        guard let selectedProvider = providerCoordinator.getCurrentProvider() else {
            throw DomainError.processingFailed("No AI provider available")
        }

        provider = selectedProvider

        // Create PRD generator with selected provider
        let generator = PRDGenerator(
            provider: provider,
            configuration: configuration,
            interactionHandler: nil // Server mode - no console interaction
        )

        self.prdGenerator = generator
        return generator
    }

    /// Build PRD input from Vapor request
    private func buildPRDInput(from request: GeneratePRDCommand) throws -> PRDGenerator.PRDInput {
        var mockupPaths: [String] = []

        // Convert mockup sources to paths
        for source in request.mockupSources {
            if let localPath = source.localPath {
                mockupPaths.append(localPath)
            } else if let url = source.url {
                mockupPaths.append(url.path)
            }
        }

        // Build guidelines from options
        let guidelines = buildGuidelines(from: request.options)

        // Combine title and description as text input
        let text = "\(request.title)\n\n\(request.description)"

        return PRDGenerator.PRDInput(
            text: text,
            mockupPaths: mockupPaths,
            guidelines: guidelines
        )
    }

    /// Build guidelines from generation options
    private func buildGuidelines(from options: GenerationOptions) -> String {
        var guidelines: [String] = []

        if options.includeTestCases {
            guidelines.append("Include comprehensive test cases")
        }
        if options.includeApiSpec {
            guidelines.append("Include OpenAPI 3.1.0 specification")
        }
        if options.includeTechnicalDetails {
            guidelines.append("Include detailed technical requirements")
        }
        if let audience = options.targetAudience {
            guidelines.append("Target audience: \(audience)")
        }
        if let customPrompt = options.customPrompt {
            guidelines.append(customPrompt)
        }
        if let maxSections = options.maxSections {
            guidelines.append("Maximum sections: \(maxSections)")
        }

        return guidelines.joined(separator: "\n")
    }

    /// Build mockup analysis prompt
    private func buildMockupAnalysisPrompt(paths: [String]) -> String {
        let pathsList = paths.joined(separator: "\n")
        return """
        Analyze the following mockup files and extract:
        1. Features and functionality
        2. User flows
        3. UI components
        4. Inferred business logic

        Mockup files:
        \(pathsList)
        """
    }

    /// Parse requirements analysis from AI response
    private func parseRequirementsAnalysis(from response: String) throws -> Domain.RequirementsAnalysis {
        // Simple parsing - in production, use structured output
        let confidence = extractConfidence(from: response)
        let clarifications = extractList(from: response, section: "Clarifications")
        let assumptions = extractList(from: response, section: "Assumptions")
        let gaps = extractList(from: response, section: "Gaps")

        return RequirementsAnalysis(
            confidence: confidence,
            clarificationsNeeded: clarifications,
            assumptions: assumptions,
            gaps: gaps
        )
    }

    /// Parse mockup analysis from AI response
    private func parseMockupAnalysis(from response: String) throws -> MockupAnalysis {
        // Simple parsing - in production, use structured output
        let features = extractList(from: response, section: "Features")
        let flows = extractList(from: response, section: "User Flows")
        let components = extractList(from: response, section: "UI Components")
        let logic = extractList(from: response, section: "Business Logic")

        return MockupAnalysis(
            extractedFeatures: features,
            userFlows: flows,
            uiComponents: components,
            businessLogic: logic
        )
    }

    /// Extract confidence score from response
    private func extractConfidence(from response: String) -> Double {
        // Look for confidence patterns
        let patterns = [
            "confidence: (\\d+)",
            "(\\d+)% confident",
            "confidence score: (\\d+)"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: response, options: [], range: NSRange(location: 0, length: response.count)),
               match.numberOfRanges > 1 {
                let range = match.range(at: 1)
                if let swiftRange = Range(range, in: response) {
                    let confidenceStr = String(response[swiftRange])
                    if let value = Double(confidenceStr) {
                        return min(max(value / 100.0, 0.0), 1.0) // Normalize to 0-1
                    }
                }
            }
        }

        return 0.75 // Default confidence
    }

    /// Extract list items from a section
    private func extractList(from response: String, section: String) -> [String] {
        // Simple extraction - look for section and bullet points
        let lines = response.components(separatedBy: .newlines)
        var inSection = false
        var items: [String] = []

        for line in lines {
            if line.lowercased().contains(section.lowercased()) {
                inSection = true
                continue
            }

            if inSection {
                if line.isEmpty || (line.contains(":") && !line.starts(with: "-") && !line.starts(with: "*")) {
                    // End of section
                    break
                }

                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.starts(with: "-") || trimmed.starts(with: "*") || trimmed.starts(with: "•") {
                    let item = trimmed
                        .dropFirst()
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !item.isEmpty {
                        items.append(String(item))
                    }
                } else if !trimmed.isEmpty {
                    items.append(trimmed)
                }
            }
        }

        return items
    }

    /// Convert ai-orchestrator PRDocument to Vapor format
    private func convertToPRDGenerationResult(
        prdDocument: PRDocument,
        processingTime: TimeInterval
    ) throws -> PRDGenerationResult {
        // Map sections
        let sections = prdDocument.sections.map { section in
            GeneratedSection(
                title: section.title,
                content: section.content,
                type: mapSectionType(section.title)
            )
        }

        // Extract provider information
        let providerName = providerCoordinator.getCurrentProvider()?.name ?? "ai-orchestrator"

        let metadata = GenerationMetadata(
            provider: providerName,
            modelVersion: "1.0.0", // Version from orchestrator
            processingTime: processingTime,
            tokensUsed: nil, // Would need token counting
            cost: nil // Would need cost calculation
        )

        // Generate formatted content from sections
        let formattedContent = generateFormattedContent(from: prdDocument)

        return PRDGenerationResult(
            content: formattedContent,
            sections: sections,
            confidence: 0.95, // High confidence from orchestrated generation
            metadata: metadata
        )
    }

    /// Map section title to type
    private func mapSectionType(_ title: String) -> String {
        let lowercased = title.lowercased()

        if lowercased.contains("executive") || lowercased.contains("summary") {
            return "executive_summary"
        } else if lowercased.contains("problem") {
            return "problem_statement"
        } else if lowercased.contains("user stor") {
            return "user_stories"
        } else if lowercased.contains("functional req") {
            return "functional_requirements"
        } else if lowercased.contains("non-functional") || lowercased.contains("nfr") {
            return "non_functional_requirements"
        } else if lowercased.contains("technical") {
            return "technical_requirements"
        } else if lowercased.contains("acceptance") || lowercased.contains("criteria") {
            return "acceptance_criteria"
        } else if lowercased.contains("timeline") || lowercased.contains("schedule") {
            return "timeline"
        } else if lowercased.contains("risk") {
            return "risks"
        } else if lowercased.contains("appendix") || lowercased.contains("addendum") {
            return "appendix"
        } else {
            return "other"
        }
    }

    /// Generate formatted content from PRDocument
    private func generateFormattedContent(from document: PRDocument) -> String {
        var content = "# \(document.title)\n\n"

        for section in document.sections {
            content += formatSection(section, level: 2)
        }

        return content
    }

    /// Format a section (overloaded for CommonModels.PRDSection)
    private func formatSection(_ section: CommonModels.PRDSection, level: Int) -> String {
        let headerPrefix = String(repeating: "#", count: level)
        var formatted = "\(headerPrefix) \(section.title)\n\n"
        formatted += "\(section.content)\n\n"

        // Handle subsections recursively
        for subsection in section.subsections {
            formatted += formatSection(subsection, level: level + 1)
        }

        return formatted
    }

    // MARK: - Advanced Features

    /// Generate PRD with interactive clarifications
    public func generatePRDWithClarifications(
        from request: GeneratePRDCommand,
        clarificationHandler: @escaping ([String]) async throws -> [String]
    ) async throws -> PRDGenerationResult {
        let startTime = Date()

        // Start a new interactive session
        let sessionId = sessionManager.startNewSession()

        // Build initial prompt with request details
        let initialPrompt = buildInteractivePRDPrompt(from: request)

        // Send initial request
        let (initialResponse, _) = try await orchestrator.chat(message: initialPrompt)
        var response = initialResponse

        // Handle clarification rounds if needed
        if configuration.enableClarificationPrompts {
            // Check if response contains questions
            let questions = extractQuestions(from: response)
            if !questions.isEmpty {
                // Get answers from handler
                let answers = try await clarificationHandler(questions)

                // Send answers back
                let answersPrompt = buildAnswersPrompt(questions: questions, answers: answers)
                let (finalResponse, _) = try await orchestrator.chat(message: answersPrompt)
                response = finalResponse
            }
        }

        // Generate final PRD from session context
        let generator = try await getOrCreatePRDGenerator(preferredProvider: request.preferredProvider)
        let prdInput = try buildPRDInput(from: request)
        let prdDocument = try await generator.generatePRD(from: prdInput)

        let processingTime = Date().timeIntervalSince(startTime)

        return try convertToPRDGenerationResult(
            prdDocument: prdDocument,
            processingTime: processingTime
        )
    }

    /// Get available AI providers from the orchestrator
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
                capabilities: getProviderCapabilities(providerName),
                lastUsed: nil // Could track this in session manager
            )
        }
    }

    /// Use specific provider for generation
    public func generatePRDWithProvider(
        from request: GeneratePRDCommand,
        providerName: String
    ) async throws -> PRDGenerationResult {
        // Switch to the requested provider
        let switched = providerCoordinator.switchProvider(to: providerName)
        if !switched {
            throw DomainError.validation("Provider '\(providerName)' is not available")
        }

        // Generate with the switched provider
        return try await generatePRD(from: request)
    }

    /// Export PRD in different formats
    public func exportPRD(
        _ result: PRDGenerationResult,
        format: ExportFormat
    ) async throws -> ExportedDocument {
        // Build PRDocument from result for export
        // Convert Domain.GeneratedSection to CommonModels.PRDSection
        let sections = result.sections.map { section in
            CommonModels.PRDSection(
                title: section.title,
                content: section.content,
                subsections: []
            )
        }

        // Determine title from first section or use default
        let title = sections.first?.title ?? "Product Requirements Document"

        let document = PRDocument(
            title: title,
            sections: sections
        )

        // Use exporter to generate formatted output
        let exporter = PRDExporter()
        let exportFormat = mapExportFormat(format)
        let exportedContent = try exporter.export(document: document, format: exportFormat)

        return ExportedDocument(
            content: exportedContent,
            format: format.rawValue,
            metadata: ExportMetadata(
                exportedAt: Date(),
                version: "1.0.0"
            )
        )
    }

    // MARK: - Helper Methods for Advanced Features

    /// Build interactive PRD prompt
    private func buildInteractivePRDPrompt(from request: GeneratePRDCommand) -> String {
        var prompt = "Generate a comprehensive PRD for: \(request.title)\n\n"
        prompt += "Description: \(request.description)\n\n"

        if !request.mockupSources.isEmpty {
            prompt += "Mockups provided: \(request.mockupSources.count) files\n"
        }

        let options = request.options
        if true {
            if let audience = options.targetAudience {
                prompt += "Target Audience: \(audience)\n"
            }
            if let customPrompt = options.customPrompt {
                prompt += "Additional Requirements: \(customPrompt)\n"
            }
        }

        return prompt
    }

    /// Extract questions from response
    private func extractQuestions(from response: String) -> [String] {
        // Look for question patterns
        return extractList(from: response, section: "Questions")
            .isEmpty ? extractList(from: response, section: "Clarifications") : extractList(from: response, section: "Questions")
    }

    /// Build answers prompt
    private func buildAnswersPrompt(questions: [String], answers: [String]) -> String {
        var prompt = "Here are the answers to your questions:\n\n"

        for (index, question) in questions.enumerated() {
            if index < answers.count {
                prompt += "Q: \(question)\n"
                prompt += "A: \(answers[index])\n\n"
            }
        }

        prompt += "Please continue with the PRD generation based on these answers."
        return prompt
    }

    /// Get provider capabilities
    private func getProviderCapabilities(_ providerName: String) -> [String] {
        switch providerName.lowercased() {
        case "apple", "mlx":
            return ["On-device processing", "Privacy-first", "Fast inference", "PRD generation"]
        case "anthropic":
            return ["Advanced reasoning", "Long context", "PRD generation", "Code analysis"]
        case "openai":
            return ["GPT-4 capabilities", "Function calling", "PRD generation", "Image analysis"]
        case "gemini":
            return ["Multi-modal", "Long context", "PRD generation", "Cost-effective"]
        default:
            return ["PRD generation"]
        }
    }

    /// Map export format
    private func mapExportFormat(_ format: ExportFormat) -> PRDExporter.ExportFormat {
        switch format {
        case .markdown:
            return .markdown
        case .json:
            return .json
        case .html:
            return .html
        case .pdf:
            // PDF not supported by PRDExporter, convert to HTML
            return .html
        }
    }
}

// MARK: - Supporting Types

/// Provider status information
public struct ProviderStatus {
    public let name: String
    public let isAvailable: Bool
    public let priority: Int
    public let capabilities: [String]
    public let lastUsed: Date?
}

/// Export format enum
public enum ExportFormat: String {
    case markdown = "markdown"
    case json = "json"
    case html = "html"
    case pdf = "pdf"
}

/// Exported document
public struct ExportedDocument {
    public let content: String
    public let format: String
    public let metadata: ExportMetadata
}

/// Export metadata
public struct ExportMetadata {
    public let exportedAt: Date
    public let version: String
}

// MARK: - Section Handling

extension AIOrchestratorProvider {
    /// Extract sections from PRD content
    private func extractSections(from content: String) -> [Domain.GeneratedSection] {
        let lines = content.components(separatedBy: .newlines)
        var sections: [Domain.GeneratedSection] = []
        var currentTitle = ""
        var currentContent = ""
        var currentType = "general"

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // Check for markdown headers
            if trimmedLine.hasPrefix("# ") || trimmedLine.hasPrefix("## ") || trimmedLine.hasPrefix("### ") {
                // Save previous section if exists
                if !currentTitle.isEmpty {
                    sections.append(Domain.GeneratedSection(
                        title: currentTitle,
                        content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines),
                        type: currentType
                    ))
                }

                // Start new section
                currentTitle = trimmedLine.replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
                currentContent = ""
                currentType = inferSectionType(from: currentTitle)
            } else {
                currentContent += line + "\n"
            }
        }

        // Add final section
        if !currentTitle.isEmpty {
            sections.append(Domain.GeneratedSection(
                title: currentTitle,
                content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines),
                type: currentType
            ))
        }

        return sections
    }

    /// Infer section type from title
    private func inferSectionType(from title: String) -> String {
        let lowercased = title.lowercased()

        if lowercased.contains("executive") || lowercased.contains("summary") {
            return "executive_summary"
        } else if lowercased.contains("problem") {
            return "problem_statement"
        } else if lowercased.contains("user stories") || lowercased.contains("stories") {
            return "user_stories"
        } else if lowercased.contains("functional requirements") || lowercased.contains("functional") {
            return "functional_requirements"
        } else if lowercased.contains("non-functional") || lowercased.contains("performance") {
            return "non_functional_requirements"
        } else if lowercased.contains("technical") {
            return "technical_requirements"
        } else if lowercased.contains("acceptance") {
            return "acceptance_criteria"
        } else if lowercased.contains("timeline") {
            return "timeline"
        } else if lowercased.contains("risks") {
            return "risks"
        } else {
            return "general"
        }
    }
}

// MARK: - Error Handling

extension AIOrchestratorProvider {
    /// Convert ai-orchestrator errors to domain errors
    private func convertError(_ error: Error) -> DomainError {
        // Check for specific error types from the ai-orchestrator system
        if let providerError = error as? AIProviderError {
            switch providerError {
            case .notConfigured:
                return .validation("AI provider not configured")
            case .invalidAPIKey:
                return .validation("Invalid or missing API key")
            case .networkError(let message):
                return .processingFailed("Network error: \(message)")
            case .rateLimitExceeded:
                return .processingFailed("Rate limit exceeded")
            case .invalidResponse:
                return .processingFailed("Invalid response from AI provider")
            case .serverError(let code, let message):
                return .processingFailed("Server error \(code): \(message)")
            case .unsupportedFeature(let feature):
                return .processingFailed("Unsupported feature: \(feature)")
            case .configurationError(let message):
                return .validation("Configuration error: \(message)")
            case .timeout:
                return .processingFailed("Request timed out")
            case .cancelled:
                return .processingFailed("Request was cancelled")
            }
        }

        // Check for configuration errors
        if error.localizedDescription.contains("configuration") {
            return .validation("Invalid configuration: \(error.localizedDescription)")
        }

        // Check for network errors
        if error.localizedDescription.contains("network") ||
           error.localizedDescription.contains("connection") {
            return .processingFailed("Network error: \(error.localizedDescription)")
        }

        // Default error conversion
        return .processingFailed("AI Orchestrator error: \(error.localizedDescription)")
    }
}