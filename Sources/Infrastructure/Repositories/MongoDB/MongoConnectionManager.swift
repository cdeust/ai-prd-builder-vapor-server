import Foundation
import MongoSwift
import NIOPosix

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
        let requestsCollection = database.collection("prd_requests")
        let documentsCollection = database.collection("prd_documents")

        let _ = try await requestsCollection.createIndex([
            "requester_id": .int32(1),
            "created_at": .int32(-1)
        ], indexOptions: IndexOptions(name: "requester_created_idx"))

        let _ = try await requestsCollection.createIndex([
            "status": .int32(1)
        ], indexOptions: IndexOptions(name: "status_idx"))

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