import Foundation
import MongoSwift
import Domain

public final class MongoPRDDocumentSearchRepository {
    private let collection: MongoCollection<MongoPRDDocumentModel>

    public init(database: MongoDatabase) {
        self.collection = database.collection("prd_documents", withType: MongoPRDDocumentModel.self)
    }

    public func searchByText(_ searchTerm: String, limit: Int = 20) async throws -> [PRDDocument] {
        let filter = MongoQueryBuilder.buildTextSearchFilter(searchTerm: searchTerm)
        let options = FindOptions(
            limit: limit,
            sort: ["score": ["$meta": "textScore"]]
        )

        do {
            let cursor = try await collection.find(filter, options: options)
            return try await MongoResultMapper.mapCursor(cursor) { try $0.toDomainEntity() }
        } catch {
            throw DomainError.processingFailed("MongoDB text search error: \(error.localizedDescription)")
        }
    }

    public func findByTags(_ tags: [String]) async throws -> [PRDDocument] {
        let filter = MongoQueryBuilder.buildTagsFilter(tags: tags)
        let options = MongoQueryBuilder.buildFindOptions(sortField: "generated_at", ascending: false)

        do {
            let cursor = try await collection.find(filter, options: options)
            return try await MongoResultMapper.mapCursor(cursor) { try $0.toDomainEntity() }
        } catch {
            throw DomainError.processingFailed("MongoDB findByTags error: \(error.localizedDescription)")
        }
    }

    public func getConfidenceStats() async throws -> ConfidenceStats {
        let pipeline = MongoQueryBuilder.buildConfidenceStatsAggregation()

        do {
            let cursor = try await collection.aggregate(pipeline)
            guard let result = try await cursor.next() else {
                return ConfidenceStats(average: 0, minimum: 0, maximum: 0, totalDocuments: 0)
            }
            return MongoResultMapper.extractConfidenceStats(from: result)
        } catch {
            throw DomainError.processingFailed("MongoDB confidence stats error: \(error.localizedDescription)")
        }
    }
}