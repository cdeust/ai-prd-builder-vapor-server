import Foundation

/// User clarification Q&A pair
public struct Clarification: Sendable, Codable, Equatable {
    public let question: String
    public let answer: String

    public init(question: String, answer: String) {
        self.question = question
        self.answer = answer
    }
}

public struct GeneratePRDCommand: Sendable, Codable {
    public let requestId: UUID
    public let title: String
    public let description: String
    public let mockupSources: [MockupSource]
    public let priority: Priority
    public let requester: RequesterInfo?
    public let preferredProvider: String?
    public let options: GenerationOptions
    public let codebaseContext: CodebaseContext?
    public let mockupAnalyses: [MockupAnalysisResult]?
    public let clarifications: [Clarification]?

    public init(
        requestId: UUID = UUID(),
        title: String,
        description: String,
        mockupSources: [MockupSource] = [],
        priority: Priority = .medium,
        requester: RequesterInfo? = nil,
        preferredProvider: String? = nil,
        options: GenerationOptions = GenerationOptions(),
        codebaseContext: CodebaseContext? = nil,
        mockupAnalyses: [MockupAnalysisResult]? = nil,
        clarifications: [Clarification]? = nil
    ) {
        self.requestId = requestId
        self.title = title
        self.description = description
        self.mockupSources = mockupSources
        self.priority = priority
        self.requester = requester
        self.preferredProvider = preferredProvider
        self.options = options
        self.codebaseContext = codebaseContext
        self.mockupAnalyses = mockupAnalyses
        self.clarifications = clarifications
    }
}

/// Context from a linked codebase project
public struct CodebaseContext: Sendable, Codable {
    public let projectId: UUID
    public let repositoryUrl: String
    public let repositoryBranch: String
    public let summary: String  // High-level summary of the codebase
    public let relevantFiles: [CodeFileContext]  // Selected relevant files
    public let techStack: TechStackInfo

    public init(
        projectId: UUID,
        repositoryUrl: String,
        repositoryBranch: String,
        summary: String,
        relevantFiles: [CodeFileContext],
        techStack: TechStackInfo
    ) {
        self.projectId = projectId
        self.repositoryUrl = repositoryUrl
        self.repositoryBranch = repositoryBranch
        self.summary = summary
        self.relevantFiles = relevantFiles
        self.techStack = techStack
    }
}

/// Context for a single code file
public struct CodeFileContext: Sendable, Codable {
    public let filePath: String
    public let language: String?
    public let excerpt: String  // Relevant excerpt (not full content to save tokens)
    public let purpose: String  // Inferred purpose/description

    public init(filePath: String, language: String?, excerpt: String, purpose: String) {
        self.filePath = filePath
        self.language = language
        self.excerpt = excerpt
        self.purpose = purpose
    }
}

/// Tech stack information
public struct TechStackInfo: Sendable, Codable {
    public let languages: [String: Int]  // {"Swift": 45, "TypeScript": 30}
    public let frameworks: [String]
    public let architecturePatterns: [String]

    public init(languages: [String: Int], frameworks: [String], architecturePatterns: [String]) {
        self.languages = languages
        self.frameworks = frameworks
        self.architecturePatterns = architecturePatterns
    }
}
