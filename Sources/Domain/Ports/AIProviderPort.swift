import Foundation

/// Port interface for AI provider implementations
/// This follows the Hexagonal Architecture pattern
public protocol AIProviderPort {
    /// Provider name
    var name: String { get }

    /// Provider priority (higher = preferred)
    var priority: Int { get }

    /// Check if provider is available
    var isAvailable: Bool { get async }

    /// Generate a PRD from the given command
    func generatePRD(from command: GeneratePRDCommand) async throws -> PRDGenerationResult

    /// Analyze requirements and identify gaps
    func analyzeRequirements(_ text: String) async throws -> RequirementsAnalysis

    /// Extract information from mockups
    func extractFromMockups(_ sources: [MockupSource]) async throws -> MockupAnalysis
}

/// Command to generate a PRD
public struct GeneratePRDCommand: Sendable, Codable {
    public let requestId: UUID
    public let title: String
    public let description: String
    public let mockupSources: [MockupSource]
    public let priority: Priority
    public let preferredProvider: String?
    public let options: GenerationOptions

    public init(
        requestId: UUID = UUID(),
        title: String,
        description: String,
        mockupSources: [MockupSource] = [],
        priority: Priority = .medium,
        preferredProvider: String? = nil,
        options: GenerationOptions = GenerationOptions()
    ) {
        self.requestId = requestId
        self.title = title
        self.description = description
        self.mockupSources = mockupSources
        self.priority = priority
        self.preferredProvider = preferredProvider
        self.options = options
    }
}

/// Options for PRD generation
public struct GenerationOptions: Sendable, Codable {
    public let includeTestCases: Bool
    public let includeApiSpec: Bool
    public let includeTechnicalDetails: Bool
    public let maxSections: Int?
    public let targetAudience: String?
    public let customPrompt: String?

    public init(
        includeTestCases: Bool = true,
        includeApiSpec: Bool = true,
        includeTechnicalDetails: Bool = true,
        maxSections: Int? = nil,
        targetAudience: String? = nil,
        customPrompt: String? = nil
    ) {
        self.includeTestCases = includeTestCases
        self.includeApiSpec = includeApiSpec
        self.includeTechnicalDetails = includeTechnicalDetails
        self.maxSections = maxSections
        self.targetAudience = targetAudience
        self.customPrompt = customPrompt
    }
}

/// Result of PRD generation
public struct PRDGenerationResult {
    public let content: String
    public let sections: [GeneratedSection]
    public let confidence: Double
    public let metadata: GenerationMetadata

    public init(
        content: String,
        sections: [GeneratedSection],
        confidence: Double,
        metadata: GenerationMetadata
    ) {
        self.content = content
        self.sections = sections
        self.confidence = confidence
        self.metadata = metadata
    }
}

/// Generated section in PRD
public struct GeneratedSection {
    public let title: String
    public let content: String
    public let type: String

    public init(title: String, content: String, type: String) {
        self.title = title
        self.content = content
        self.type = type
    }
}

/// Metadata about generation
public struct GenerationMetadata {
    public let provider: String
    public let modelVersion: String?
    public let processingTime: TimeInterval
    public let tokensUsed: Int?
    public let cost: Double?

    public init(
        provider: String,
        modelVersion: String? = nil,
        processingTime: TimeInterval,
        tokensUsed: Int? = nil,
        cost: Double? = nil
    ) {
        self.provider = provider
        self.modelVersion = modelVersion
        self.processingTime = processingTime
        self.tokensUsed = tokensUsed
        self.cost = cost
    }
}

/// Requirements analysis result
public struct RequirementsAnalysis {
    public let confidence: Double
    public let clarificationsNeeded: [String]
    public let assumptions: [String]
    public let gaps: [String]

    public init(
        confidence: Double,
        clarificationsNeeded: [String],
        assumptions: [String],
        gaps: [String]
    ) {
        self.confidence = confidence
        self.clarificationsNeeded = clarificationsNeeded
        self.assumptions = assumptions
        self.gaps = gaps
    }
}

/// Mockup analysis result
public struct MockupAnalysis {
    public let extractedFeatures: [String]
    public let userFlows: [String]
    public let uiComponents: [String]
    public let businessLogic: [String]

    public init(
        extractedFeatures: [String],
        userFlows: [String],
        uiComponents: [String],
        businessLogic: [String]
    ) {
        self.extractedFeatures = extractedFeatures
        self.userFlows = userFlows
        self.uiComponents = uiComponents
        self.businessLogic = businessLogic
    }
}