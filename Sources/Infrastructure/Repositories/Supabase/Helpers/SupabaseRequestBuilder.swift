import Foundation
import AsyncHTTPClient
import Domain

struct SupabaseRequestBuilder {
    private let supabaseURL: String
    private let apiKey: String

    init(supabaseURL: String, apiKey: String) {
        self.supabaseURL = supabaseURL.hasSuffix("/") ? String(supabaseURL.dropLast()) : supabaseURL
        self.apiKey = apiKey
    }

    func buildInsertRequest<T: Encodable>(tableName: String, model: T) throws -> HTTPClientRequest {
        let requestData = try JSONEncoder().encode(model)
        var request = HTTPClientRequest(url: "\(supabaseURL)/rest/v1/\(tableName)")
        request.method = .POST
        addCommonHeaders(to: &request)
        request.headers.add(name: "Prefer", value: "return=representation")
        request.body = .bytes(requestData)
        return request
    }

    func buildFindByIdRequest(tableName: String, id: UUID) -> HTTPClientRequest {
        var request = HTTPClientRequest(url: "\(supabaseURL)/rest/v1/\(tableName)?id=eq.\(id.uuidString)&select=*")
        request.method = .GET
        addAuthHeaders(to: &request)
        return request
    }

    func buildFindByFieldRequest(tableName: String, field: String, value: String, limit: Int? = nil, offset: Int? = nil, orderBy: String? = nil) -> HTTPClientRequest {
        let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
        var urlComponents = "\(supabaseURL)/rest/v1/\(tableName)?\(field)=eq.\(encodedValue)&select=*"

        if let orderBy = orderBy {
            urlComponents += "&order=\(orderBy).desc"
        }
        if let limit = limit {
            urlComponents += "&limit=\(limit)"
        }
        if let offset = offset {
            urlComponents += "&offset=\(offset)"
        }

        var request = HTTPClientRequest(url: urlComponents)
        request.method = .GET
        addAuthHeaders(to: &request)
        return request
    }

    func buildUpdateRequest<T: Encodable>(tableName: String, id: UUID, model: T) throws -> HTTPClientRequest {
        let requestData = try JSONEncoder().encode(model)
        var request = HTTPClientRequest(url: "\(supabaseURL)/rest/v1/\(tableName)?id=eq.\(id.uuidString)")
        request.method = .PATCH
        addCommonHeaders(to: &request)
        request.headers.add(name: "Prefer", value: "return=representation")
        request.body = .bytes(requestData)
        return request
    }

    func buildDeleteRequest(tableName: String, id: UUID) -> HTTPClientRequest {
        var request = HTTPClientRequest(url: "\(supabaseURL)/rest/v1/\(tableName)?id=eq.\(id.uuidString)")
        request.method = .DELETE
        addAuthHeaders(to: &request)
        return request
    }

    func buildCountRequest(tableName: String, field: String, value: String) -> HTTPClientRequest {
        var request = HTTPClientRequest(url: "\(supabaseURL)/rest/v1/\(tableName)?\(field)=eq.\(value)&select=count")
        request.method = .GET
        addAuthHeaders(to: &request)
        request.headers.add(name: "Prefer", value: "count=exact")
        return request
    }

    private func addCommonHeaders(to request: inout HTTPClientRequest) {
        request.headers.add(name: "Content-Type", value: "application/json")
        addAuthHeaders(to: &request)
    }

    private func addAuthHeaders(to request: inout HTTPClientRequest) {
        request.headers.add(name: "apikey", value: apiKey)
        request.headers.add(name: "Authorization", value: "Bearer \(apiKey)")
    }
}