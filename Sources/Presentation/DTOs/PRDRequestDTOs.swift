import Foundation
import Vapor
import Domain

// MARK: - Request DTOs

/// DTO for PRD generation requests
public struct GeneratePRDRequestDTO: Content {
    public let requestId: UUID?
    public let title: String
    public let description: String
    public let mockupSources: [MockupSourceDTO]?
    public let priority: String
    public let preferredProvider: String?
    public let options: GenerationOptionsDTO?

    public init(
        requestId: UUID? = nil,
        title: String,
        description: String,
        mockupSources: [MockupSourceDTO]? = nil,
        priority: String = "medium",
        preferredProvider: String? = nil,
        options: GenerationOptionsDTO? = nil
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

/// DTO for mockup sources
public struct MockupSourceDTO: Content {
    public let type: String
    public let url: String?
    public let localPath: String?
    public let content: String?

    public init(type: String, url: String? = nil, localPath: String? = nil, content: String? = nil) {
        self.type = type
        self.url = url
        self.localPath = localPath
        self.content = content
    }
}

/// DTO for generation options
public struct GenerationOptionsDTO: Content {
    public let includeTestCases: Bool?
    public let includeApiSpec: Bool?
    public let includeTechnicalDetails: Bool?
    public let maxSections: Int?
    public let targetAudience: String?
    public let customPrompt: String?

    public init(
        includeTestCases: Bool? = nil,
        includeApiSpec: Bool? = nil,
        includeTechnicalDetails: Bool? = nil,
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

/// DTO for requirements analysis requests
public struct AnalyzeRequirementsRequestDTO: Content {
    public let description: String
    public let mockupSources: [MockupSourceDTO]?

    public init(description: String, mockupSources: [MockupSourceDTO]? = nil) {
        self.description = description
        self.mockupSources = mockupSources
    }
}

// MARK: - Response DTOs

/// DTO for PRD generation responses
public struct PRDGenerationResponseDTO: Content {
    public let requestId: UUID
    public let status: String
    public let analysis: RequirementsAnalysisDTO?
    public let document: PRDDocumentDTO?
    public let message: String

    public init(
        requestId: UUID,
        status: String,
        analysis: RequirementsAnalysisDTO? = nil,
        document: PRDDocumentDTO? = nil,
        message: String
    ) {
        self.requestId = requestId
        self.status = status
        self.analysis = analysis
        self.document = document
        self.message = message
    }
}

/// DTO for requirements analysis responses
public struct RequirementsAnalysisDTO: Content {
    public let confidence: Int
    public let clarificationsNeeded: [String]
    public let assumptions: [String]
    public let gaps: [String]

    public init(
        confidence: Int,
        clarificationsNeeded: [String],
        assumptions: [String],
        gaps: [String]
    ) {
        self.confidence = confidence
        self.clarificationsNeeded = clarificationsNeeded
        self.assumptions = assumptions
        self.gaps = gaps
    }

    static func from(_ analysis: RequirementsAnalysis) -> RequirementsAnalysisDTO {
        return RequirementsAnalysisDTO(
            confidence: Int(analysis.confidence * 100), // Convert Double (0-1) to Int (0-100)
            clarificationsNeeded: analysis.clarificationsNeeded,
            assumptions: analysis.assumptions,
            gaps: analysis.gaps
        )
    }
}

/// DTO for PRD documents
public struct PRDDocumentDTO: Content {
    public let id: UUID
    public let requestId: UUID
    public let title: String
    public let content: String
    public let sections: [PRDSectionDTO]
    public let metadata: DocumentMetadataDTO
    public let generatedAt: Date
    public let generatedBy: String
    public let confidence: Double
    public let version: Int

    public init(
        id: UUID,
        requestId: UUID,
        title: String,
        content: String,
        sections: [PRDSectionDTO],
        metadata: DocumentMetadataDTO,
        generatedAt: Date,
        generatedBy: String,
        confidence: Double,
        version: Int
    ) {
        self.id = id
        self.requestId = requestId
        self.title = title
        self.content = content
        self.sections = sections
        self.metadata = metadata
        self.generatedAt = generatedAt
        self.generatedBy = generatedBy
        self.confidence = confidence
        self.version = version
    }

    static func from(_ document: PRDDocument) -> PRDDocumentDTO {
        return PRDDocumentDTO(
            id: document.id,
            requestId: document.requestId,
            title: document.title,
            content: document.content,
            sections: document.sections.map(PRDSectionDTO.from),
            metadata: DocumentMetadataDTO.from(document.metadata),
            generatedAt: document.generatedAt,
            generatedBy: document.generatedBy,
            confidence: document.confidence,
            version: document.version
        )
    }
}

/// DTO for PRD sections
public struct PRDSectionDTO: Content {
    public let id: UUID
    public let title: String
    public let content: String
    public let order: Int
    public let sectionType: String

    public init(id: UUID, title: String, content: String, order: Int, sectionType: String) {
        self.id = id
        self.title = title
        self.content = content
        self.order = order
        self.sectionType = sectionType
    }

    static func from(_ section: PRDSection) -> PRDSectionDTO {
        return PRDSectionDTO(
            id: section.id,
            title: section.title,
            content: section.content,
            order: section.order,
            sectionType: section.sectionType.rawValue
        )
    }
}

/// DTO for document metadata
public struct DocumentMetadataDTO: Content {
    public let format: String
    public let language: String
    public let wordCount: Int
    public let estimatedReadTime: Int
    public let tags: [String]
    public let attachments: [String]

    public init(
        format: String,
        language: String,
        wordCount: Int,
        estimatedReadTime: Int,
        tags: [String],
        attachments: [String]
    ) {
        self.format = format
        self.language = language
        self.wordCount = wordCount
        self.estimatedReadTime = estimatedReadTime
        self.tags = tags
        self.attachments = attachments
    }

    static func from(_ metadata: DocumentMetadata) -> DocumentMetadataDTO {
        return DocumentMetadataDTO(
            format: metadata.format.rawValue,
            language: metadata.language,
            wordCount: metadata.wordCount,
            estimatedReadTime: metadata.estimatedReadTime,
            tags: metadata.tags,
            attachments: metadata.attachments
        )
    }
}

/// DTO for generation status responses
public struct GenerationStatusResponseDTO: Content {
    public let requestId: UUID
    public let status: String
    public let progress: Int
    public let document: PRDDocumentDTO?
    public let createdAt: Date
    public let updatedAt: Date
    public let completedAt: Date?

    public init(
        requestId: UUID,
        status: String,
        progress: Int,
        document: PRDDocumentDTO? = nil,
        createdAt: Date,
        updatedAt: Date,
        completedAt: Date? = nil
    ) {
        self.requestId = requestId
        self.status = status
        self.progress = progress
        self.document = document
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
    }
}

/// DTO for PRD request lists
public struct PRDRequestListResponseDTO: Content {
    public let requests: [PRDRequestSummaryDTO]
    public let pagination: PaginationDTO

    public init(requests: [PRDRequestSummaryDTO], pagination: PaginationDTO) {
        self.requests = requests
        self.pagination = pagination
    }
}

/// DTO for PRD request summaries
public struct PRDRequestSummaryDTO: Content {
    public let id: UUID
    public let title: String
    public let status: String
    public let priority: String
    public let createdAt: Date
    public let completedAt: Date?

    public init(
        id: UUID,
        title: String,
        status: String,
        priority: String,
        createdAt: Date,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.priority = priority
        self.createdAt = createdAt
        self.completedAt = completedAt
    }

    // Removed - PRDRequestSummary not defined in Domain
}

/// DTO for pagination metadata
public struct PaginationDTO: Content {
    public let limit: Int
    public let offset: Int
    public let total: Int

    public init(limit: Int, offset: Int, total: Int) {
        self.limit = limit
        self.offset = offset
        self.total = total
    }
}

/// DTO for error responses
public struct ErrorResponseDTO: Content {
    public let error: ErrorDetailDTO

    public init(error: ErrorDetailDTO) {
        self.error = error
    }
}

/// DTO for error details
public struct ErrorDetailDTO: Content {
    public let code: String
    public let message: String
    public let timestamp: Date

    public init(code: String, message: String, timestamp: Date) {
        self.code = code
        self.message = message
        self.timestamp = timestamp
    }
}

// MARK: - AI Orchestrator Enhanced DTOs

/// DTO for provider information
public struct ProvidersResponseDTO: Content {
    public let providers: [ProviderStatusDTO]

    public init(providers: [ProviderStatusDTO]) {
        self.providers = providers
    }
}

/// DTO for individual provider status
public struct ProviderStatusDTO: Content {
    public let name: String
    public let isAvailable: Bool
    public let priority: Int
    public let capabilities: [String]
    public let lastUsed: Date?

    public init(name: String, isAvailable: Bool, priority: Int, capabilities: [String], lastUsed: Date?) {
        self.name = name
        self.isAvailable = isAvailable
        self.priority = priority
        self.capabilities = capabilities
        self.lastUsed = lastUsed
    }
}

/// DTO for provider health status
public struct ProviderHealthResponseDTO: Content {
    public let providers: [String: ProviderHealthDTO]

    public init(providers: [String: ProviderHealthDTO]) {
        self.providers = providers
    }
}

/// DTO for individual provider health
public struct ProviderHealthDTO: Content {
    public let isHealthy: Bool
    public let lastChecked: Date
    public let failureCount: Int
    public let avgResponseTime: TimeInterval

    public init(isHealthy: Bool, lastChecked: Date, failureCount: Int, avgResponseTime: TimeInterval) {
        self.isHealthy = isHealthy
        self.lastChecked = lastChecked
        self.failureCount = failureCount
        self.avgResponseTime = avgResponseTime
    }
}

/// Interactive message for WebSocket communication
public struct InteractiveMessage: Content {
    public let type: String
    public let questions: [String]?
    public let generateCommand: GeneratePRDCommand?
    public let answers: [String]?
    public let result: PRDDocumentDTO?

    public init(
        type: String,
        questions: [String]? = nil,
        generateCommand: GeneratePRDCommand? = nil,
        answers: [String]? = nil,
        result: PRDDocumentDTO? = nil
    ) {
        self.type = type
        self.questions = questions
        self.generateCommand = generateCommand
        self.answers = answers
        self.result = result
    }
}