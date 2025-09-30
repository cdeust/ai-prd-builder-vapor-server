import Foundation
import AsyncHTTPClient
import NIOCore
import Domain

public final class SupabaseStorageClient: MockupStoragePort {
    private let httpClient: HTTPClient
    private let supabaseURL: String
    private let apiKey: String
    private let bucketName: String

    public init(
        httpClient: HTTPClient,
        supabaseURL: String,
        apiKey: String,
        bucketName: String = "prd-mockups"
    ) {
        self.httpClient = httpClient
        self.supabaseURL = supabaseURL.hasSuffix("/") ? String(supabaseURL.dropLast()) : supabaseURL
        self.apiKey = apiKey
        self.bucketName = bucketName
    }

    public func upload(
        data: Data,
        fileName: String,
        requestId: UUID,
        mimeType: String
    ) async throws -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let sanitizedFileName = fileName.replacingOccurrences(of: " ", with: "_")
        let storagePath = "\(requestId.uuidString)/\(timestamp)_\(sanitizedFileName)"

        let uploadURL = "\(supabaseURL)/storage/v1/object/\(bucketName)/\(storagePath)"

        var request = HTTPClientRequest(url: uploadURL)
        request.method = .POST
        request.headers.add(name: "apikey", value: apiKey)
        request.headers.add(name: "Authorization", value: "Bearer \(apiKey)")
        request.headers.add(name: "Content-Type", value: mimeType)
        request.headers.add(name: "Content-Length", value: String(data.count))

        let buffer = ByteBuffer(data: data)
        request.body = .bytes(buffer)

        print("[SupabaseStorageClient] Uploading to: \(uploadURL)")
        let response = try await httpClient.execute(request, timeout: .seconds(60))

        guard response.status.code >= 200 && response.status.code < 300 else {
            let errorBody = try await response.body.collect(upTo: 1024 * 1024)
            let errorMessage = String(buffer: errorBody)
            print("[SupabaseStorageClient] Upload error: \(errorMessage)")
            throw DomainError.processingFailed("Storage upload failed: \(response.status) - \(errorMessage)")
        }

        print("[SupabaseStorageClient] Upload successful: \(storagePath)")
        return storagePath
    }

    public func download(path: String) async throws -> Data {
        let downloadURL = "\(supabaseURL)/storage/v1/object/\(bucketName)/\(path)"

        var request = HTTPClientRequest(url: downloadURL)
        request.method = .GET
        request.headers.add(name: "apikey", value: apiKey)
        request.headers.add(name: "Authorization", value: "Bearer \(apiKey)")

        print("[SupabaseStorageClient] Downloading from: \(downloadURL)")
        let response = try await httpClient.execute(request, timeout: .seconds(60))

        guard response.status == .ok else {
            let errorBody = try await response.body.collect(upTo: 1024 * 1024)
            let errorMessage = String(buffer: errorBody)
            print("[SupabaseStorageClient] Download error: \(errorMessage)")
            throw DomainError.processingFailed("Storage download failed: \(response.status) - \(errorMessage)")
        }

        let buffer = try await response.body.collect(upTo: 10 * 1024 * 1024)
        return Data(buffer: buffer)
    }

    public func delete(path: String) async throws {
        let deleteURL = "\(supabaseURL)/storage/v1/object/\(bucketName)/\(path)"

        var request = HTTPClientRequest(url: deleteURL)
        request.method = .DELETE
        request.headers.add(name: "apikey", value: apiKey)
        request.headers.add(name: "Authorization", value: "Bearer \(apiKey)")

        print("[SupabaseStorageClient] Deleting: \(deleteURL)")
        let response = try await httpClient.execute(request, timeout: .seconds(30))

        guard response.status.code >= 200 && response.status.code < 300 else {
            let errorBody = try await response.body.collect(upTo: 1024 * 1024)
            let errorMessage = String(buffer: errorBody)
            print("[SupabaseStorageClient] Delete error: \(errorMessage)")
            throw DomainError.processingFailed("Storage delete failed: \(response.status) - \(errorMessage)")
        }

        print("[SupabaseStorageClient] Delete successful: \(path)")
    }

    public func generateSignedURL(path: String, expiresIn: Int) async throws -> String {
        let signURL = "\(supabaseURL)/storage/v1/object/sign/\(bucketName)/\(path)"

        var request = HTTPClientRequest(url: signURL)
        request.method = .POST
        request.headers.add(name: "apikey", value: apiKey)
        request.headers.add(name: "Authorization", value: "Bearer \(apiKey)")
        request.headers.add(name: "Content-Type", value: "application/json")

        let payload = ["expiresIn": expiresIn]
        let jsonData = try JSONEncoder().encode(payload)
        request.body = .bytes(ByteBuffer(data: jsonData))

        print("[SupabaseStorageClient] Generating signed URL for: \(path)")
        let response = try await httpClient.execute(request, timeout: .seconds(30))

        guard response.status == .ok else {
            let errorBody = try await response.body.collect(upTo: 1024 * 1024)
            let errorMessage = String(buffer: errorBody)
            print("[SupabaseStorageClient] Signed URL error: \(errorMessage)")
            throw DomainError.processingFailed("Signed URL generation failed: \(response.status) - \(errorMessage)")
        }

        let responseBody = try await response.body.collect(upTo: 1024 * 1024)
        let responseData = try JSONDecoder().decode(SignedURLResponse.self, from: responseBody)

        let signedURL = "\(supabaseURL)/storage/v1\(responseData.signedURL)"
        print("[SupabaseStorageClient] Signed URL generated: \(signedURL)")
        return signedURL
    }

    public func deleteAllForRequest(requestId: UUID) async throws {
        let listURL = "\(supabaseURL)/storage/v1/object/list/\(bucketName)"
        let prefix = requestId.uuidString

        var request = HTTPClientRequest(url: listURL)
        request.method = .POST
        request.headers.add(name: "apikey", value: apiKey)
        request.headers.add(name: "Authorization", value: "Bearer \(apiKey)")
        request.headers.add(name: "Content-Type", value: "application/json")

        let payload: [String: Encodable] = ["prefix": prefix, "limit": 1000]

        // Create a proper encodable structure
        struct ListPayload: Encodable {
            let prefix: String
            let limit: Int
        }
        let listPayload = ListPayload(prefix: prefix, limit: 1000)
        let jsonData = try JSONEncoder().encode(listPayload)
        request.body = .bytes(ByteBuffer(data: jsonData))

        print("[SupabaseStorageClient] Listing files for request: \(requestId)")
        let response = try await httpClient.execute(request, timeout: .seconds(30))

        guard response.status == .ok else {
            let errorBody = try await response.body.collect(upTo: 1024 * 1024)
            let errorMessage = String(buffer: errorBody)
            throw DomainError.processingFailed("Storage list failed: \(response.status) - \(errorMessage)")
        }

        let responseBody = try await response.body.collect(upTo: 1024 * 1024)
        let files = try JSONDecoder().decode([StorageFile].self, from: responseBody)

        print("[SupabaseStorageClient] Found \(files.count) files to delete")
        for file in files {
            let filePath = "\(prefix)/\(file.name)"
            try await delete(path: filePath)
        }
    }

    public func exists(path: String) async throws -> Bool {
        let headURL = "\(supabaseURL)/storage/v1/object/\(bucketName)/\(path)"

        var request = HTTPClientRequest(url: headURL)
        request.method = .HEAD
        request.headers.add(name: "apikey", value: apiKey)
        request.headers.add(name: "Authorization", value: "Bearer \(apiKey)")

        let response = try await httpClient.execute(request, timeout: .seconds(30))
        return response.status == .ok
    }
}

private struct SignedURLResponse: Codable {
    let signedURL: String
}

private struct StorageFile: Codable {
    let name: String
}