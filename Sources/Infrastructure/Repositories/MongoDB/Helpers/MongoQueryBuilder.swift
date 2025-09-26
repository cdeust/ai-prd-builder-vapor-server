import Foundation
import MongoSwift
import Domain

struct MongoQueryBuilder {
    static func buildRequestFilter(id: UUID) -> BSONDocument {
        return ["_id": .string(id.uuidString)]
    }

    static func buildRequesterFilter(requesterId: String) -> BSONDocument {
        return ["requester_id": .string(requesterId)]
    }

    static func buildStatusFilter(status: RequestStatus) -> BSONDocument {
        return ["status": .string(status.rawValue)]
    }

    static func buildTextSearchFilter(searchTerm: String) -> BSONDocument {
        return ["$text": ["$search": .string(searchTerm)]]
    }

    static func buildTagsFilter(tags: [String]) -> BSONDocument {
        return ["tags": ["$in": .array(tags.map { .string($0) })]]
    }

    static func buildFindOptions(limit: Int? = nil, offset: Int? = nil, sortField: String? = nil, ascending: Bool = false) -> FindOptions {
        var options = FindOptions()

        if let limit = limit {
            options.limit = limit
        }

        if let offset = offset {
            options.skip = offset
        }

        if let sortField = sortField {
            options.sort = [sortField: .int32(ascending ? 1 : -1)]
        }

        return options
    }

    static func buildUpdateDocument<T: Encodable>(_ model: T) throws -> BSONDocument {
        let encodedDocument = try BSONEncoder().encode(model)
        return ["$set": .document(encodedDocument)]
    }

    static func buildConfidenceStatsAggregation() -> [BSONDocument] {
        return [
            [
                "$group": [
                    "_id": .null,
                    "avg_confidence": ["$avg": "$confidence"],
                    "min_confidence": ["$min": "$confidence"],
                    "max_confidence": ["$max": "$confidence"],
                    "total_documents": ["$sum": .int32(1)]
                ]
            ]
        ]
    }
}