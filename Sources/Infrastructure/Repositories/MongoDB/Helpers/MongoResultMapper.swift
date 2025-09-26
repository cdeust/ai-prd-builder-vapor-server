import Foundation
import MongoSwift
import Domain

struct MongoResultMapper {
    static func mapCursor<T: Codable, D>(
        _ cursor: MongoCursor<T>,
        transform: (T) throws -> D
    ) async throws -> [D] {
        var results: [D] = []
        for try await model in cursor {
            results.append(try transform(model))
        }
        return results
    }

    static func mapUpdateResult(_ result: UpdateResult?, entityId: UUID, entityType: String) throws {
        guard let result = result, result.matchedCount > 0 else {
            throw DomainError.notFound("\(entityType) with ID \(entityId)")
        }
    }

    static func mapDeleteResult(_ result: DeleteResult?, entityId: UUID, entityType: String) throws {
        guard let result = result, result.deletedCount > 0 else {
            throw DomainError.notFound("\(entityType) with ID \(entityId)")
        }
    }

    static func extractConfidenceStats(from result: BSONDocument) -> ConfidenceStats {
        return ConfidenceStats(
            average: result["avg_confidence"]?.doubleValue ?? 0,
            minimum: result["min_confidence"]?.doubleValue ?? 0,
            maximum: result["max_confidence"]?.doubleValue ?? 0,
            totalDocuments: result["total_documents"]?.int32Value ?? 0
        )
    }
}