import Foundation
import Domain
import PRDGenerator
import ImplementationAnalysis

/// Core business logic for PRD generation - Application layer use case
/// Orchestrates the entire PRD generation workflow using ports and domain services
public final class GeneratePRDUseCase {
    private let aiProvider: AIProviderPort
    private let prdRepository: PRDRepositoryProtocol
    private let documentRepository: PRDDocumentRepositoryProtocol
    private let prdCodebaseLink: PRDCodebaseLink?
    private let codebaseRepository: CodebaseRepositoryProtocol?
    private let githubParser: GitHubParserPort?
    private let embeddingGenerator: EmbeddingGeneratorPort?
    private let mockupUploadRepository: MockupUploadRepositoryProtocol?
    private let contextRequestPort: ContextRequestPort?

    public init(
        aiProvider: AIProviderPort,
        prdRepository: PRDRepositoryProtocol,
        documentRepository: PRDDocumentRepositoryProtocol,
        prdCodebaseLink: PRDCodebaseLink? = nil,
        codebaseRepository: CodebaseRepositoryProtocol? = nil,
        githubParser: GitHubParserPort? = nil,
        embeddingGenerator: EmbeddingGeneratorPort? = nil,
        mockupUploadRepository: MockupUploadRepositoryProtocol? = nil,
        contextRequestPort: ContextRequestPort? = nil
    ) {
        self.aiProvider = aiProvider
        self.prdRepository = prdRepository
        self.documentRepository = documentRepository
        self.prdCodebaseLink = prdCodebaseLink
        self.codebaseRepository = codebaseRepository
        self.githubParser = githubParser
        self.embeddingGenerator = embeddingGenerator
        self.mockupUploadRepository = mockupUploadRepository
        self.contextRequestPort = contextRequestPort
    }

    /// Execute PRD generation workflow
    public func execute(_ command: GeneratePRDCommand) async throws -> PRDDocument {
        // 1. Fetch existing request and update status to processing
        guard var savedRequest = try await prdRepository.findById(command.requestId) else {
            throw DomainError.notFound("PRD request not found: \(command.requestId)")
        }

        savedRequest = savedRequest.withStatus(.processing)
        savedRequest = try await prdRepository.update(savedRequest)

        // 1.5. Fetch mockup analyses if available
        var mockupAnalyses: [Domain.MockupAnalysisResult]? = nil
        if let mockupRepo = mockupUploadRepository {
            let mockupUploads = try await mockupRepo.findByRequestId(command.requestId)
            mockupAnalyses = mockupUploads.compactMap { $0.analysisResult }

            if let analyses = mockupAnalyses, !analyses.isEmpty {
                print("✅ Found \(analyses.count) mockup analyses for PRD generation")
            }
        }

        // 1.6. Fetch linked codebase context if available
        var enrichedCommand = command
        if let prdCodebaseLink = prdCodebaseLink,
           let linkedCodebase = try await prdCodebaseLink.getCodebaseForPRD(prdRequestId: command.requestId),
           let codebaseRepository = codebaseRepository,
           let githubParser = githubParser {

            print("✅ Found linked codebase: \(linkedCodebase.id) - \(linkedCodebase.repositoryUrl)")

            // Build codebase context with PRD details for RAG search
            let codebaseContext = try await buildCodebaseContext(
                codebaseProject: linkedCodebase,
                codebaseRepository: codebaseRepository,
                githubParser: githubParser,
                prdTitle: command.title,
                prdDescription: command.description
            )

            print("✅ Built codebase context with \(codebaseContext.relevantFiles.count) files and \(codebaseContext.techStack.languages.count) languages")

            // Create enriched command with codebase context and mockup analyses
            enrichedCommand = GeneratePRDCommand(
                requestId: command.requestId,
                title: command.title,
                description: command.description,
                mockupSources: command.mockupSources,
                priority: command.priority,
                requester: command.requester,
                preferredProvider: command.preferredProvider,
                options: command.options,
                codebaseContext: codebaseContext,
                mockupAnalyses: mockupAnalyses,
                clarifications: command.clarifications
            )
        } else {
            // No codebase, but still include mockup analyses if available
            enrichedCommand = GeneratePRDCommand(
                requestId: command.requestId,
                title: command.title,
                description: command.description,
                mockupSources: command.mockupSources,
                priority: command.priority,
                requester: command.requester,
                preferredProvider: command.preferredProvider,
                options: command.options,
                codebaseContext: nil,
                mockupAnalyses: mockupAnalyses,
                clarifications: command.clarifications
            )
            print("⚠️ No codebase linked to PRD request: \(command.requestId)")
        }

        // 2. Generate PRD content using AI provider (with enriched command and context port)
        let result = try await aiProvider.generatePRD(from: enrichedCommand, contextRequestPort: contextRequestPort)

        // 3. Create PRD document
        let document = PRDDocument(
            requestId: savedRequest.id,
            title: command.title,
            content: result.content,
            sections: result.sections.map { section in
                PRDSection(
                    title: section.title,
                    content: section.content,
                    order: 0,
                    sectionType: mapSectionType(section.type)
                )
            },
            metadata: DocumentMetadata(
                wordCount: result.content.split(separator: " ").count,
                estimatedReadTime: PRDDocument.estimateReadTime(
                    wordCount: result.content.split(separator: " ").count
                )
            ),
            generatedBy: result.metadata.provider,
            confidence: result.confidence,
            professionalAnalysis: result.professionalAnalysis
        )

        // Validate document
        try document.validate()

        // 4. Save or update document
        let existingDocument = try await documentRepository.findByRequestId(command.requestId)
        let savedDocument: PRDDocument
        if let existing = existingDocument {
            let updatedDocument = PRDDocument(
                id: existing.id,
                requestId: savedRequest.id,
                title: command.title,
                content: result.content,
                sections: result.sections.map { section in
                    PRDSection(
                        title: section.title,
                        content: section.content,
                        order: 0,
                        sectionType: mapSectionType(section.type)
                    )
                },
                metadata: DocumentMetadata(
                    wordCount: result.content.split(separator: " ").count,
                    estimatedReadTime: PRDDocument.estimateReadTime(
                        wordCount: result.content.split(separator: " ").count
                    )
                ),
                generatedAt: existing.generatedAt,
                generatedBy: result.metadata.provider,
                confidence: result.confidence,
                version: existing.version + 1,
                professionalAnalysis: result.professionalAnalysis
            )
            savedDocument = try await documentRepository.update(updatedDocument)
        } else {
            savedDocument = try await documentRepository.save(document)
        }

        // 5. Update request status
        let completedRequest = savedRequest.withStatus(.completed)

        _ = try await prdRepository.update(completedRequest)

        return savedDocument
    }

    /// Map application section type to domain section type
    private func mapSectionType(_ type: String) -> SectionType {
        switch type.lowercased() {
        case "executive_summary", "summary":
            return .executiveSummary
        case "problem_statement", "problem":
            return .problemStatement
        case "user_stories", "stories":
            return .userStories
        case "functional_requirements", "functional":
            return .functionalRequirements
        case "non_functional_requirements", "non_functional":
            return .nonFunctionalRequirements
        case "technical_requirements", "technical":
            return .technicalRequirements
        case "acceptance_criteria", "acceptance":
            return .acceptanceCriteria
        case "timeline":
            return .timeline
        case "risks":
            return .risks
        default:
            return .appendix
        }
    }

    /// Build codebase context from a linked codebase project
    /// Uses RAG (Retrieval-Augmented Generation) if embeddings are available, falls back to file parsing
    private func buildCodebaseContext(
        codebaseProject: CodebaseProject,
        codebaseRepository: CodebaseRepositoryProtocol,
        githubParser: GitHubParserPort,
        prdTitle: String,
        prdDescription: String
    ) async throws -> CodebaseContext {
        // Parse GitHub URL to extract owner and repo
        guard let repoURL = GitHubURL.parse(codebaseProject.repositoryUrl) else {
            throw DomainError.processingFailed("Invalid repository URL: \(codebaseProject.repositoryUrl)")
        }

        // Fetch repository info for tech stack
        let repoInfo = try await githubParser.fetchRepositoryInfo(
            owner: repoURL.owner,
            repo: repoURL.repo,
            accessToken: nil
        )

        // Fetch languages
        let languages = try await githubParser.fetchLanguages(
            owner: repoURL.owner,
            repo: repoURL.repo,
            accessToken: nil
        )

        // Build tech stack info (AI will infer frameworks/patterns from files)
        let techStack = TechStackInfo(
            languages: languages,
            frameworks: codebaseProject.detectedFrameworks,
            architecturePatterns: codebaseProject.architecturePatterns.map { $0.name }
        )

        var relevantFiles: [Domain.CodeFileContext] = []

        // Check if codebase has been indexed (has embeddings) and we have embedding generator
        if codebaseProject.indexingStatus == .completed && codebaseProject.totalChunks > 0,
           let embeddingGenerator = embeddingGenerator {
            print("✅ Using RAG semantic search for codebase context (indexed with \(codebaseProject.totalChunks) chunks)")

            // Use RAG to find most relevant code chunks based on PRD description
            let ragUseCase = BuildRAGContextUseCase(
                codebaseRepository: codebaseRepository,
                embeddingGenerator: embeddingGenerator
            )

            let ragInput = BuildRAGContextUseCase.Input(
                projectId: codebaseProject.id,
                prdDescription: prdDescription,
                prdTitle: prdTitle,
                maxChunks: 10,
                similarityThreshold: 0.7
            )

            let ragOutput = try await ragUseCase.execute(ragInput)

            // Convert RAG output to CodeFileContext
            relevantFiles = ragOutput.relevantChunks.map { chunk in
                Domain.CodeFileContext(
                    filePath: chunk.filePath,
                    language: chunk.language,
                    excerpt: chunk.content,
                    purpose: "Code reference: \(chunk.chunkType)\(chunk.symbolName.map { " '\($0)'" } ?? "") (similarity: \(String(format: "%.2f", chunk.similarity)))"
                )
            }

            print("✅ Found \(relevantFiles.count) relevant code chunks with average similarity: \(String(format: "%.2f", ragOutput.averageSimilarity))")
        } else {
            print("⚠️ Codebase not indexed yet, falling back to GitHub file parsing")

            // Fetch repository file tree to find actual files
            let fileTree = try await githubParser.fetchFileTree(
                owner: repoURL.owner,
                repo: repoURL.repo,
                branch: codebaseProject.repositoryBranch,
                accessToken: nil
            )

            // Select relevant files based on what actually exists
            let relevantFilePaths = selectRelevantFiles(from: fileTree)

            // Fetch file contents
            let fileContents = try await githubParser.batchFetchFileContents(
                owner: repoURL.owner,
                repo: repoURL.repo,
                paths: relevantFilePaths,
                ref: codebaseProject.repositoryBranch,
                accessToken: nil
            )

            // Build file contexts from actual files
            relevantFiles = fileContents.map { (path, content) -> Domain.CodeFileContext in
                let excerpt = createExcerpt(from: content, maxLength: 500)

                return Domain.CodeFileContext(
                    filePath: path,
                    language: nil, // Let AI infer
                    excerpt: excerpt,
                    purpose: "" // Let AI infer from content
                )
            }
        }

        return CodebaseContext(
            projectId: codebaseProject.id,
            repositoryUrl: codebaseProject.repositoryUrl,
            repositoryBranch: codebaseProject.repositoryBranch,
            summary: repoInfo.description ?? "Repository: \(repoInfo.fullName)",
            relevantFiles: relevantFiles,
            techStack: techStack
        )
    }

    /// Select relevant files from actual repository contents
    private func selectRelevantFiles(from fileTree: [GitHubFileNode]) -> [String] {
        var selected: [String] = []

        // Priority order for file selection
        let priorityPatterns = [
            "readme",
            "package.json",
            "package.swift",
            "cargo.toml",
            "go.mod",
            "requirements.txt",
            "pom.xml",
            "build.gradle"
        ]

        // First pass: Find priority files (config/docs)
        for node in fileTree {
            let fileName = (node.path as NSString).lastPathComponent.lowercased()

            if priorityPatterns.contains(where: { fileName.contains($0) }) {
                selected.append(node.path)
                if selected.count >= 10 { break }
            }
        }

        // Second pass: Add some source files if we have room
        if selected.count < 10 {
            for node in fileTree {
                let ext = (node.path as NSString).pathExtension.lowercased()
                let isSourceFile = ["swift", "ts", "js", "py", "go", "rs", "java", "kt"].contains(ext)

                if isSourceFile && !selected.contains(node.path) {
                    selected.append(node.path)
                    if selected.count >= 10 { break }
                }
            }
        }

        return selected
    }

    /// Create excerpt from file content (first N characters)
    private func createExcerpt(from content: String, maxLength: Int = 500) -> String {
        if content.count <= maxLength {
            return content
        }
        let truncated = String(content.prefix(maxLength))
        return truncated + "..."
    }
}