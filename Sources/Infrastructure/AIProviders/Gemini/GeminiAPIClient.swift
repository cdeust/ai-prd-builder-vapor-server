import Foundation
import AsyncHTTPClient
import Domain

struct GeminiAPIClient {
    private let apiKey: String
    private let httpClient: HTTPClient
    private let baseURL: String = "https://generativelanguage.googleapis.com"

    init(apiKey: String, httpClient: HTTPClient) {
        self.apiKey = apiKey
        self.httpClient = httpClient
    }

    func sendRequest(model: String, prompt: String, maxTokens: Int) async throws -> GeminiResponse {
        let requestBody = GeminiRequest(
            contents: [GeminiContent(parts: [GeminiPart(text: prompt)])],
            generationConfig: GeminiGenerationConfig(maxOutputTokens: maxTokens, temperature: 0.7)
        )

        let requestData = try JSONEncoder().encode(requestBody)

        var request = HTTPClientRequest(url: "\(baseURL)/v1beta/models/\(model):generateContent?key=\(apiKey)")
        request.method = .POST
        request.headers.add(name: "Content-Type", value: "application/json")
        request.body = .bytes(requestData)

        let response = try await httpClient.execute(request, timeout: .seconds(60))

        guard response.status == .ok else {
            let errorBody = try await response.body.collect(upTo: 1024 * 1024)
            let errorMessage = String(buffer: errorBody)
            throw DomainError.processingFailed("Gemini API error: \(response.status) - \(errorMessage)")
        }

        let responseBody = try await response.body.collect(upTo: 10 * 1024 * 1024)
        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: responseBody)

        return geminiResponse
    }
}