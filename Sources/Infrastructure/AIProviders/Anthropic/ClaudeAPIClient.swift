import Foundation
import AsyncHTTPClient
import Domain

struct ClaudeAPIClient {
    private let apiKey: String
    private let httpClient: HTTPClient
    private let baseURL: String = "https://api.anthropic.com"

    init(apiKey: String, httpClient: HTTPClient) {
        self.apiKey = apiKey
        self.httpClient = httpClient
    }

    func sendRequest(model: String, prompt: String, maxTokens: Int) async throws -> ClaudeResponse {
        let requestBody = ClaudeRequest(
            model: model,
            maxTokens: maxTokens,
            messages: [ClaudeMessage(role: "user", content: prompt)]
        )

        let requestData = try JSONEncoder().encode(requestBody)

        var request = HTTPClientRequest(url: "\(baseURL)/v1/messages")
        request.method = .POST
        request.headers.add(name: "Content-Type", value: "application/json")
        request.headers.add(name: "x-api-key", value: apiKey)
        request.headers.add(name: "anthropic-version", value: "2023-06-01")
        request.body = .bytes(requestData)

        let response = try await httpClient.execute(request, timeout: .seconds(60))

        guard response.status == .ok else {
            let errorBody = try await response.body.collect(upTo: 1024 * 1024)
            let errorMessage = String(buffer: errorBody)
            throw DomainError.processingFailed("Anthropic API error: \(response.status) - \(errorMessage)")
        }

        let responseBody = try await response.body.collect(upTo: 10 * 1024 * 1024)
        let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: responseBody)

        return claudeResponse
    }
}