import Foundation
import FluentKit

public struct CreatePRDRequest: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
        try await database.schema("prd_requests")
            .id()
            .field("title", .string, .required)
            .field("description", .string, .required)
            .field("mockup_sources", .string, .required)
            .field("priority", .string, .required)
            .field("preferred_provider", .string)
            .field("requester_id", .string, .required)
            .field("status", .string, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .field("completed_at", .datetime)
            .field("generated_document_id", .uuid)
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("prd_requests").delete()
    }
}