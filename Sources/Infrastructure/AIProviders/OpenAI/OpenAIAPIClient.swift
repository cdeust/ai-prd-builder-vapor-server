import Foundation
import AsyncHTTPClient
import Domain

struct OpenAIAPIClient {
    private let apiKey: String
    private let httpClient: HTTPClient
    private let baseURL: String = "https://api.openai.com"

    init(apiKey: String, httpClient: HTTPClient) {
        self.apiKey = apiKey
        self.httpClient = httpClient
    }

    func sendRequest(model: String, prompt: String, maxTokens: Int) async throws -> OpenAIResponse {
        let requestBody = OpenAIRequest(
            model: model,
            messages: [OpenAIMessage(role: "user", content: prompt)],
            maxTokens: maxTokens,
            temperature: 0.7
        )

        let requestData = try JSONEncoder().encode(requestBody)

        var request = HTTPClientRequest(url: "\(baseURL)/v1/chat/completions")
        request.method = .POST
        request.headers.add(name: "Content-Type", value: "application/json")
        request.headers.add(name: "Authorization", value: "Bearer \(apiKey)")
        request.body = .bytes(requestData)

        let response = try await httpClient.execute(request, timeout: .seconds(60))

        guard response.status == .ok else {
            let errorBody = try await response.body.collect(upTo: 1024 * 1024)
            let errorMessage = String(buffer: errorBody)
            throw DomainError.processingFailed("OpenAI API error: \(response.status) - \(errorMessage)")
        }

        let responseBody = try await response.body.collect(upTo: 10 * 1024 * 1024)
        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: responseBody)

        return openAIResponse
    }
}