import Foundation
import MongoSwift
import NIOPosix
import NIOCore
import Domain

/// MongoDB implementation of PRD repository
/// Uses MongoDB Swift driver for document-based storage with flexible schema
public final class MongoPRDRepository: PRDRepositoryProtocol {
    private let collection: MongoCollection<MongoPRDRequestModel>
    private let collectionName = "prd_requests"

    public init(database: MongoDatabase) {
        self.collection = database.collection(collectionName, withType: MongoPRDRequestModel.self)
    }

    public func save(_ request: PRDRequest) async throws -> PRDRequest {
        let mongoModel = try MongoPRDRequestModel.from(domainEntity: request)

        do {
            _ = try await collection.insertOne(mongoModel)
            return request
        } catch {
            throw DomainError.processingFailed("MongoDB save error: \(error.localizedDescription)")
        }
    }

    public func findById(_ id: UUID) async throws -> PRDRequest? {
        let filter: BSONDocument = ["_id": .string(id.uuidString)]

        do {
            guard let mongoModel = try await collection.findOne(filter) else {
                return nil
            }
            return try mongoModel.toDomainEntity()
        } catch {
            throw DomainError.processingFailed("MongoDB findById error: \(error.localizedDescription)")
        }
    }

    public func findByRequesterId(_ requesterId: String, limit: Int, offset: Int) async throws -> [PRDRequest] {
        let filter: BSONDocument = ["requester_id": .string(requesterId)]
        let options = FindOptions(
            limit: limit,
            skip: offset,
            sort: ["created_at": .int32(-1)] // Descending order
        )

        do {
            let cursor = try await collection.find(filter, options: options)
            var results: [PRDRequest] = []

            for try await mongoModel in cursor {
                results.append(try mongoModel.toDomainEntity())
            }

            return results
        } catch {
            throw DomainError.processingFailed("MongoDB findByRequesterId error: \(error.localizedDescription)")
        }
    }

    public func update(_ request: PRDRequest) async throws -> PRDRequest {
        let filter: BSONDocument = ["_id": .string(request.id.uuidString)]
        let mongoModel = try MongoPRDRequestModel.from(domainEntity: request)

        do {
            let updateDocument = try BSONEncoder().encode(mongoModel)
            let update: BSONDocument = ["$set": .document(updateDocument)]

            let result = try await collection.updateOne(filter: filter, update: update)

            guard let result = result, result.matchedCount > 0 else {
                throw DomainError.notFound("PRD request with ID \(request.id)")
            }

            return request
        } catch let error as DomainError {
            throw error
        } catch {
            throw DomainError.processingFailed("MongoDB update error: \(error.localizedDescription)")
        }
    }

    public func delete(_ id: UUID) async throws {
        let filter: BSONDocument = ["_id": .string(id.uuidString)]

        do {
            let result = try await collection.deleteOne(filter)

            guard let result = result, result.deletedCount > 0 else {
                throw DomainError.notFound("PRD request with ID \(id)")
            }
        } catch let error as DomainError {
            throw error
        } catch {
            throw DomainError.processingFailed("MongoDB delete error: \(error.localizedDescription)")
        }
    }

    public func findByStatus(_ status: RequestStatus) async throws -> [PRDRequest] {
        let filter: BSONDocument = ["status": .string(status.rawValue)]
        let options = FindOptions(sort: ["created_at": .int32(-1)])

        do {
            let cursor = try await collection.find(filter, options: options)
            var results: [PRDRequest] = []

            for try await mongoModel in cursor {
                results.append(try mongoModel.toDomainEntity())
            }

            return results
        } catch {
            throw DomainError.processingFailed("MongoDB findByStatus error: \(error.localizedDescription)")
        }
    }

    public func countByStatus(_ status: RequestStatus) async throws -> Int {
        let filter: BSONDocument = ["status": .string(status.rawValue)]

        do {
            return try await collection.countDocuments(filter)
        } catch {
            throw DomainError.processingFailed("MongoDB countByStatus error: \(error.localizedDescription)")
        }
    }
}

// MARK: - MongoDB Document Repository

/// MongoDB implementation of PRD document repository
public final class MongoPRDDocumentRepository: PRDDocumentRepositoryProtocol {
    private let collection: MongoCollection<MongoPRDDocumentModel>
    private let collectionName = "prd_documents"

    public init(database: MongoDatabase) {
        self.collection = database.collection(collectionName, withType: MongoPRDDocumentModel.self)
    }

    public func save(_ document: PRDDocument) async throws -> PRDDocument {
        let mongoModel = try MongoPRDDocumentModel.from(domainEntity: document)

        do {
            _ = try await collection.insertOne(mongoModel)
            return document
        } catch {
            throw DomainError.processingFailed("MongoDB document save error: \(error.localizedDescription)")
        }
    }

    public func findById(_ id: UUID) async throws -> PRDDocument? {
        let filter: BSONDocument = ["_id": .string(id.uuidString)]

        do {
            guard let mongoModel = try await collection.findOne(filter) else {
                return nil
            }
            return try mongoModel.toDomainEntity()
        } catch {
            throw DomainError.processingFailed("MongoDB document findById error: \(error.localizedDescription)")
        }
    }

    public func findByRequestId(_ requestId: UUID) async throws -> PRDDocument? {
        let filter: BSONDocument = ["request_id": .string(requestId.uuidString)]

        do {
            guard let mongoModel = try await collection.findOne(filter) else {
                return nil
            }
            return try mongoModel.toDomainEntity()
        } catch {
            throw DomainError.processingFailed("MongoDB document findByRequestId error: \(error.localizedDescription)")
        }
    }

    public func update(_ document: PRDDocument) async throws -> PRDDocument {
        let filter: BSONDocument = ["_id": .string(document.id.uuidString)]
        let mongoModel = try MongoPRDDocumentModel.from(domainEntity: document)

        do {
            let updateDocument = try BSONEncoder().encode(mongoModel)
            let update: BSONDocument = ["$set": .document(updateDocument)]

            let result = try await collection.updateOne(filter: filter, update: update)

            guard let result = result, result.matchedCount > 0 else {
                throw DomainError.notFound("PRD document with ID \(document.id)")
            }

            return document
        } catch let error as DomainError {
            throw error
        } catch {
            throw DomainError.processingFailed("MongoDB document update error: \(error.localizedDescription)")
        }
    }

    public func delete(_ id: UUID) async throws {
        let filter: BSONDocument = ["_id": .string(id.uuidString)]

        do {
            let result = try await collection.deleteOne(filter)

            guard let result = result, result.deletedCount > 0 else {
                throw DomainError.notFound("PRD document with ID \(id)")
            }
        } catch let error as DomainError {
            throw error
        } catch {
            throw DomainError.processingFailed("MongoDB document delete error: \(error.localizedDescription)")
        }
    }
}

// MARK: - MongoDB Models

/// MongoDB model for PRD requests
public struct MongoPRDRequestModel: Codable {
    let _id: String // MongoDB ObjectId as string
    let title: String
    let description: String
    let mockup_sources: [MockupSourceData]
    let priority: String
    let preferred_provider: String?
    let requester_id: String
    let status: String
    let created_at: Date
    let updated_at: Date
    let completed_at: Date?
    let generated_document_id: String?

    static func from(domainEntity: PRDRequest) throws -> MongoPRDRequestModel {
        return MongoPRDRequestModel(
            _id: domainEntity.id.uuidString,
            title: domainEntity.title,
            description: domainEntity.description,
            mockup_sources: domainEntity.mockupSources.map { mockup in
                MockupSourceData(
                    type: mockup.type.rawValue,
                    url: mockup.url?.absoluteString,
                    localPath: mockup.location,
                    content: nil
                )
            },
            priority: domainEntity.priority.rawValue,
            preferred_provider: nil,
            requester_id: domainEntity.requester.id,
            status: domainEntity.status.rawValue,
            created_at: domainEntity.createdAt,
            updated_at: Date(),
            completed_at: nil,
            generated_document_id: nil
        )
    }

    func toDomainEntity() throws -> PRDRequest {
        guard let id = UUID(uuidString: _id) else {
            throw DomainError.processingFailed("Invalid UUID format in MongoDB data: \(_id)")
        }

        let mockupSources = mockup_sources.compactMap { data in
            let mockupType: MockupType = MockupType(rawValue: data.type) ?? MockupType.url
            let location = data.url ?? data.localPath ?? data.content ?? ""
            return try? MockupSource(
                type: mockupType,
                location: location,
                metadata: nil
            )
        }

        let requester = Requester(id: requester_id)

        return PRDRequest(
            id: id,
            title: title,
            description: description,
            mockupSources: mockupSources,
            priority: Priority(rawValue: priority) ?? .medium,
            requester: requester,
            metadata: RequestMetadata(),
            createdAt: created_at,
            status: RequestStatus.from(rawValue: status)
        )
    }
}

/// MongoDB model for PRD documents
public struct MongoPRDDocumentModel: Codable {
    let _id: String // MongoDB ObjectId as string
    let request_id: String
    let title: String
    let content: String
    let sections: [PRDSectionData]
    let metadata: DocumentMetadataData
    let generated_at: Date
    let generated_by: String
    let confidence: Double
    let version: Int

    // MongoDB-specific fields for enhanced querying
    let word_count: Int // Denormalized for efficient queries
    let tags: [String] // Denormalized for text search
    let search_text: String // Full-text search index

    static func from(domainEntity: PRDDocument) throws -> MongoPRDDocumentModel {
        let sections = domainEntity.sections.map { section in
            PRDSectionData(
                id: section.id,
                title: section.title,
                content: section.content,
                order: section.order,
                sectionType: section.sectionType.rawValue
            )
        }

        let metadata = DocumentMetadataData(
            format: domainEntity.metadata.format.rawValue,
            language: domainEntity.metadata.language,
            wordCount: domainEntity.metadata.wordCount,
            estimatedReadTime: domainEntity.metadata.estimatedReadTime,
            tags: domainEntity.metadata.tags,
            attachments: domainEntity.metadata.attachments
        )

        // Create search text for full-text search
        let searchText = [
            domainEntity.title,
            domainEntity.content,
            domainEntity.sections.map { $0.title + " " + $0.content }.joined(separator: " ")
        ].joined(separator: " ")

        return MongoPRDDocumentModel(
            _id: domainEntity.id.uuidString,
            request_id: domainEntity.requestId.uuidString,
            title: domainEntity.title,
            content: domainEntity.content,
            sections: sections,
            metadata: metadata,
            generated_at: domainEntity.generatedAt,
            generated_by: domainEntity.generatedBy,
            confidence: domainEntity.confidence,
            version: domainEntity.version,
            word_count: domainEntity.metadata.wordCount,
            tags: domainEntity.metadata.tags,
            search_text: searchText
        )
    }

    func toDomainEntity() throws -> PRDDocument {
        guard let id = UUID(uuidString: _id),
              let requestId = UUID(uuidString: request_id) else {
            throw DomainError.processingFailed("Invalid UUID format in MongoDB document data")
        }

        let prdSections = sections.map { data in
            PRDSection(
                id: data.id,
                title: data.title,
                content: data.content,
                order: data.order,
                sectionType: SectionType(rawValue: data.sectionType) ?? .appendix
            )
        }

        let documentMetadata = DocumentMetadata(
            format: DocumentFormat(rawValue: metadata.format) ?? .markdown,
            language: metadata.language,
            wordCount: metadata.wordCount,
            estimatedReadTime: metadata.estimatedReadTime,
            tags: metadata.tags,
            attachments: metadata.attachments
        )

        return PRDDocument(
            id: id,
            requestId: requestId,
            title: title,
            content: content,
            sections: prdSections,
            metadata: documentMetadata,
            generatedAt: generated_at,
            generatedBy: generated_by,
            confidence: confidence,
            version: version
        )
    }
}

// MARK: - Helper Data Structures

public struct MockupSourceData: Codable {
    let type: String
    let url: String?
    let localPath: String?
    let content: String?
}

public struct PRDSectionData: Codable {
    let id: UUID
    let title: String
    let content: String
    let order: Int
    let sectionType: String
}

public struct DocumentMetadataData: Codable {
    let format: String
    let language: String
    let wordCount: Int
    let estimatedReadTime: Int
    let tags: [String]
    let attachments: [String]
}

// MARK: - MongoDB Connection Manager

/// MongoDB connection manager for database setup
public final class MongoConnectionManager {
    private let client: MongoClient
    private let database: MongoDatabase

    public init(connectionString: String, databaseName: String) throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.client = try MongoClient(connectionString, using: eventLoopGroup)
        self.database = client.db(databaseName)
    }

    public func getDatabase() -> MongoDatabase {
        return database
    }

    public func createIndexes() async throws {
        // Create indexes for efficient querying
        let requestsCollection = database.collection("prd_requests")
        let documentsCollection = database.collection("prd_documents")

        // PRD Requests indexes
        let _ = try await requestsCollection.createIndex([
            "requester_id": .int32(1),
            "created_at": .int32(-1)
        ], indexOptions: IndexOptions(name: "requester_created_idx"))

        let _ = try await requestsCollection.createIndex([
            "status": .int32(1)
        ], indexOptions: IndexOptions(name: "status_idx"))

        // PRD Documents indexes
        let _ = try await documentsCollection.createIndex([
            "request_id": .int32(1)
        ], indexOptions: IndexOptions(name: "request_id_idx", unique: true))

        let _ = try await documentsCollection.createIndex([
            "search_text": "text"
        ], indexOptions: IndexOptions(name: "search_text_idx"))

        let _ = try await documentsCollection.createIndex([
            "tags": .int32(1)
        ], indexOptions: IndexOptions(name: "tags_idx"))

        let _ = try await documentsCollection.createIndex([
            "generated_at": .int32(-1)
        ], indexOptions: IndexOptions(name: "generated_at_idx"))
    }

    public func close() async throws {
        try await client.close()
    }
}

// MARK: - MongoDB Search Extensions

extension MongoPRDDocumentRepository {
    /// Search documents by text content
    public func searchByText(_ searchTerm: String, limit: Int = 20) async throws -> [PRDDocument] {
        let filter: BSONDocument = ["$text": ["$search": .string(searchTerm)]]
        let options = FindOptions(
            limit: limit,
            sort: ["score": ["$meta": "textScore"]]
        )

        do {
            let cursor = try await collection.find(filter, options: options)
            var results: [PRDDocument] = []

            for try await mongoModel in cursor {
                results.append(try mongoModel.toDomainEntity())
            }

            return results
        } catch {
            throw DomainError.processingFailed("MongoDB text search error: \(error.localizedDescription)")
        }
    }

    /// Find documents by tags
    public func findByTags(_ tags: [String]) async throws -> [PRDDocument] {
        let filter: BSONDocument = ["tags": ["$in": .array(tags.map { .string($0) })]]
        let options = FindOptions(sort: ["generated_at": .int32(-1)])

        do {
            let cursor = try await collection.find(filter, options: options)
            var results: [PRDDocument] = []

            for try await mongoModel in cursor {
                results.append(try mongoModel.toDomainEntity())
            }

            return results
        } catch {
            throw DomainError.processingFailed("MongoDB findByTags error: \(error.localizedDescription)")
        }
    }

    /// Aggregate documents by confidence levels
    public func getConfidenceStats() async throws -> ConfidenceStats {
        let pipeline: [BSONDocument] = [
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

        do {
            let cursor = try await collection.aggregate(pipeline)
            guard let result = try await cursor.next() else {
                return ConfidenceStats(average: 0, minimum: 0, maximum: 0, totalDocuments: 0)
            }

            return ConfidenceStats(
                average: result["avg_confidence"]?.doubleValue ?? 0,
                minimum: result["min_confidence"]?.doubleValue ?? 0,
                maximum: result["max_confidence"]?.doubleValue ?? 0,
                totalDocuments: result["total_documents"]?.int32Value ?? 0
            )
        } catch {
            throw DomainError.processingFailed("MongoDB confidence stats error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Statistics Model

public struct ConfidenceStats {
    public let average: Double
    public let minimum: Double
    public let maximum: Double
    public let totalDocuments: Int32
}