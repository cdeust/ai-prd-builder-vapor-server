import Foundation
import Domain
import ImplementationAnalysis

/// Mapper for converting between Codebase domain entities and DTOs
public enum CodebaseMapper {
    /// Convert Codebase entity to response DTO
    public static func toDTO(_ codebase: Codebase) -> CodebaseResponseDTO {
        return CodebaseResponseDTO(
            id: codebase.id,
            name: codebase.name,
            repositoryUrl: codebase.repositoryUrl,
            description: codebase.description,
            createdAt: codebase.createdAt,
            updatedAt: codebase.updatedAt,
            userId: codebase.userId
        )
    }

    /// Convert array of Codebase entities to response DTOs
    public static func toDTOs(_ codebases: [Codebase]) -> [CodebaseResponseDTO] {
        return codebases.map(toDTO)
    }
}

/// Mapper for converting between CodeFile domain entities and DTOs
public enum CodeFileMapper {
    /// Convert CodeFile entity to response DTO
    public static func toDTO(_ file: CodeFile) -> CodeFileResponseDTO {
        return CodeFileResponseDTO(
            id: file.id,
            codebaseId: file.codebaseProjectId,
            filePath: file.filePath,
            content: "", // Content not included in file metadata
            language: file.language?.rawValue,
            createdAt: file.createdAt,
            updatedAt: file.updatedAt
        )
    }

    /// Convert array of CodeFile entities to response DTOs
    public static func toDTOs(_ files: [CodeFile]) -> [CodeFileResponseDTO] {
        return files.map(toDTO)
    }

    /// Convert search result to DTO
    public static func toSearchResultDTO(_ result: SearchCodebaseUseCase.Output) -> SearchResultDTO {
        return SearchResultDTO(
            file: toDTO(result.file),
            similarity: result.similarity
        )
    }

    /// Convert array of search results to DTOs
    public static func toSearchResultDTOs(_ results: [SearchCodebaseUseCase.Output]) -> [SearchResultDTO] {
        return results.map(toSearchResultDTO)
    }
}
