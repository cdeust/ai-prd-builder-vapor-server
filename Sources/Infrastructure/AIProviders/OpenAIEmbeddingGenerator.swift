import Foundation
import AsyncHTTPClient
import NIOCore
import ImplementationAnalysis

/// OpenAI embedding generator using text-embedding-3-small
public final class OpenAIEmbeddingGenerator: EmbeddingGeneratorPort, @unchecked Sendable {
    private let httpClient: HTTPClient
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1"

    public var embeddingDimension: Int { 1536 }
    public var modelName: String { "text-embedding-3-small" }

    public init(httpClient: HTTPClient, apiKey: String) {
        self.httpClient = httpClient
        self.apiKey = apiKey
    }

    public func generateEmbedding(text: String) async throws -> [Float] {
        let embeddings = try await generateEmbeddings(texts: [text])
        guard let embedding = embeddings.first else {
            throw EmbeddingError.emptyResponse
        }
        return embedding
    }

    public func generateEmbeddings(texts: [String]) async throws -> [[Float]] {
        var request = HTTPClientRequest(url: "\(baseURL)/embeddings")
        request.method = .POST
        request.headers.add(name: "Content-Type", value: "application/json")
        request.headers.add(name: "Authorization", value: "Bearer \(apiKey)")

        let requestBody = EmbeddingRequest(
            input: texts,
            model: modelName,
            encoding_format: "float"
        )

        let encoder = JSONEncoder()
        let bodyData = try encoder.encode(requestBody)
        request.body = .bytes(ByteBuffer(data: bodyData))

        let response = try await httpClient.execute(request, timeout: .seconds(30))

        guard response.status == .ok else {
            let errorBody = try await response.body.collect(upTo: 1024 * 1024)
            let errorMessage = String(buffer: errorBody)
            throw EmbeddingError.apiError(statusCode: response.status.code, message: errorMessage)
        }

        let responseBody = try await response.body.collect(upTo: 10 * 1024 * 1024)
        let decoder = JSONDecoder()
        let embeddingResponse = try decoder.decode(EmbeddingResponse.self, from: responseBody)

        return embeddingResponse.data.map { $0.embedding }
    }
}

// MARK: - Request/Response Models

private struct EmbeddingRequest: Codable {
    let input: [String]
    let model: String
    let encoding_format: String
}

private struct EmbeddingResponse: Codable {
    let data: [EmbeddingData]
    let model: String
    let usage: Usage

    struct EmbeddingData: Codable {
        let embedding: [Float]
        let index: Int
    }

    struct Usage: Codable {
        let prompt_tokens: Int
        let total_tokens: Int
    }
}

// MARK: - Errors

public enum EmbeddingError: Error, CustomStringConvertible {
    case emptyResponse
    case apiError(statusCode: UInt, message: String)
    case invalidAPIKey

    public var description: String {
        switch self {
        case .emptyResponse:
            return "OpenAI returned empty embedding response"
        case .apiError(let statusCode, let message):
            return "OpenAI API error (\(statusCode)): \(message)"
        case .invalidAPIKey:
            return "Invalid OpenAI API key"
        }
    }
}
