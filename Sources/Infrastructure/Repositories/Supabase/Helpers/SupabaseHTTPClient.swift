import Foundation
import AsyncHTTPClient
import NIOCore
import Domain

struct SupabaseHTTPClient {
    private let httpClient: HTTPClient
    private let supabaseURL: String
    private let apiKey: String

    init(httpClient: HTTPClient, supabaseURL: String, apiKey: String) {
        self.httpClient = httpClient
        self.supabaseURL = supabaseURL.hasSuffix("/") ? String(supabaseURL.dropLast()) : supabaseURL
        self.apiKey = apiKey
    }

    func execute<T: Decodable>(_ request: HTTPClientRequest) async throws -> T {
        print("[SupabaseHTTPClient] Executing request: \(request.method) \(request.url)")
        let response = try await httpClient.execute(request, timeout: .seconds(30))
        print("[SupabaseHTTPClient] Response status: \(response.status.code)")

        guard response.status.code >= 200 && response.status.code < 300 else {
            let errorBody = try await response.body.collect(upTo: 1024 * 1024)
            let errorMessage = String(buffer: errorBody)
            print("[SupabaseHTTPClient] Error response: \(errorMessage)")
            throw DomainError.processingFailed("Supabase error: \(response.status) - \(errorMessage)")
        }

        let responseBody = try await response.body.collect(upTo: 10 * 1024 * 1024)
        let responseString = String(buffer: responseBody)
        print("[SupabaseHTTPClient] Response body: \(responseString)")
        return try JSONDecoder().decode(T.self, from: responseBody)
    }

    func executeDelete(_ request: HTTPClientRequest) async throws {
        let response = try await httpClient.execute(request, timeout: .seconds(30))

        guard response.status.code >= 200 && response.status.code < 300 else {
            let errorBody = try await response.body.collect(upTo: 1024 * 1024)
            let errorMessage = String(buffer: errorBody)
            throw DomainError.processingFailed("Supabase delete error: \(response.status) - \(errorMessage)")
        }
    }

    func executeCount(_ request: HTTPClientRequest) async throws -> Int {
        let response = try await httpClient.execute(request, timeout: .seconds(30))

        guard response.status == .ok else {
            let errorBody = try await response.body.collect(upTo: 1024 * 1024)
            let errorMessage = String(buffer: errorBody)
            throw DomainError.processingFailed("Supabase count error: \(response.status) - \(errorMessage)")
        }

        if let contentRange = response.headers.first(name: "content-range"),
           let countString = contentRange.split(separator: "/").last,
           let count = Int(countString) {
            return count
        }

        return 0
    }
}