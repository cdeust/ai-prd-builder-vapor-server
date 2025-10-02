import Foundation
import AsyncHTTPClient
import Logging
import Domain
import ImplementationAnalysis

/// Supabase-backed implementation of PRDCodebaseLink
/// Persists PRD-Codebase links to the prd_codebase_links table
public final class SupabasePRDCodebaseLinkRepository: PRDCodebaseLink {
    private let httpClient: SupabaseHTTPClient
    private let requestBuilder: SupabaseRequestBuilder
    private let logger: Logger

    public init(
        httpClient: HTTPClient,
        supabaseURL: String,
        apiKey: String,
        schema: String = "public",
        logger: Logger = Logger(label: "supabase.prd.codebase.link.repository")
    ) {
        self.httpClient = SupabaseHTTPClient(httpClient: httpClient, supabaseURL: supabaseURL, apiKey: apiKey)
        self.requestBuilder = SupabaseRequestBuilder(supabaseURL: supabaseURL, apiKey: apiKey, schema: schema)
        self.logger = logger
    }

    /// Link a PRD request to a codebase project
    public func linkPRDToCodebase(prdRequestId: UUID, codebaseProjectId: UUID) async throws {
        logger.info("🔗 Linking PRD \(prdRequestId) to codebase \(codebaseProjectId)")

        let link = PRDCodebaseLinkDTO(
            prd_request_id: prdRequestId,
            codebase_project_id: codebaseProjectId,
            created_at: Date(),
            updated_at: Date()
        )

        let request = try requestBuilder.buildInsertRequest(tableName: "prd_codebase_links", model: link)
        let _: [PRDCodebaseLinkDTO] = try await httpClient.execute(request)

        logger.info("✅ Successfully linked PRD \(prdRequestId) to codebase \(codebaseProjectId)")
    }

    /// Link a codebase project to a PRD request (same operation, different signature)
    public func linkCodebaseToPRD(prdId: UUID, codebaseId: UUID) async throws {
        try await linkPRDToCodebase(prdRequestId: prdId, codebaseProjectId: codebaseId)
    }

    /// Get the codebase linked to a PRD request (returns first for backward compatibility)
    public func getCodebaseForPRD(prdRequestId: UUID) async throws -> CodebaseProject? {
        let codebases = try await getCodebasesForPRD(prdRequestId: prdRequestId)
        return codebases.first
    }

    /// Get all codebases linked to a PRD request
    public func getCodebasesForPRD(prdRequestId: UUID) async throws -> [CodebaseProject] {
        logger.info("🔍 Looking up codebases linked to PRD \(prdRequestId)")

        // Find all links by PRD request ID (no limit for multiple codebases)
        let linkRequest = requestBuilder.buildFindByFieldRequest(
            tableName: "prd_codebase_links",
            field: "prd_request_id",
            value: prdRequestId.uuidString,
            limit: 100 // Support up to 100 linked codebases
        )

        let links: [PRDCodebaseLinkDTO] = try await httpClient.execute(linkRequest)

        if links.isEmpty {
            logger.warning("⚠️ No codebases linked to PRD \(prdRequestId)")
            return []
        }

        logger.info("✅ Found \(links.count) codebase(s) linked to PRD \(prdRequestId)")

        // Fetch all codebase project details
        var codebases: [CodebaseProject] = []
        for link in links {
            let codebaseRequest = requestBuilder.buildFindByIdRequest(
                tableName: "codebase_projects",
                id: link.codebase_project_id
            )

            let codebaseResults: [CodebaseProjectDTO] = try await httpClient.execute(codebaseRequest)
            if let project = codebaseResults.first?.toDomain() {
                codebases.append(project)
            }
        }

        return codebases
    }

    /// Unlink a PRD request from a codebase project
    public func unlinkPRDFromCodebase(prdRequestId: UUID, codebaseProjectId: UUID) async throws {
        logger.info("🔓 Unlinking PRD \(prdRequestId) from codebase \(codebaseProjectId)")

        let request = requestBuilder.buildDeleteByFieldRequest(
            tableName: "prd_codebase_links",
            field: "prd_request_id",
            value: prdRequestId.uuidString
        )

        try await httpClient.executeDelete(request)

        logger.info("✅ Successfully unlinked PRD \(prdRequestId) from codebase \(codebaseProjectId)")
    }
}

// MARK: - DTOs

/// Supabase DTO for prd_codebase_links table
struct PRDCodebaseLinkDTO: Codable {
    let id: UUID?
    let prd_request_id: UUID
    let codebase_project_id: UUID
    let created_at: Date
    let updated_at: Date

    init(
        id: UUID? = nil,
        prd_request_id: UUID,
        codebase_project_id: UUID,
        created_at: Date,
        updated_at: Date
    ) {
        self.id = id
        self.prd_request_id = prd_request_id
        self.codebase_project_id = codebase_project_id
        self.created_at = created_at
        self.updated_at = updated_at
    }
}
