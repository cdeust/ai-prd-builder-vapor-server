import Foundation
import FluentKit

public struct CreatePRDDocument: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
        try await database.schema("prd_documents")
            .id()
            .field("request_id", .uuid, .required)
            .field("title", .string, .required)
            .field("content", .string, .required)
            .field("sections", .string, .required)
            .field("metadata", .string, .required)
            .field("generated_at", .datetime, .required)
            .field("generated_by", .string, .required)
            .field("confidence", .double, .required)
            .field("version", .int, .required)
            .foreignKey("request_id", references: "prd_requests", "id", onDelete: .cascade)
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("prd_documents").delete()
    }
}