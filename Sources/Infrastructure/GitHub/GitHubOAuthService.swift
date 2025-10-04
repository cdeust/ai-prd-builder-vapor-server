import Foundation
import AsyncHTTPClient
import NIOCore
import Vapor

/// Service for handling GitHub OAuth flow
public final class GitHubOAuthService: Sendable {
    private let httpClient: HTTPClient
    private let config: GitHubOAuthConfig

    public init(httpClient: HTTPClient, config: GitHubOAuthConfig) {
        self.httpClient = httpClient
        self.config = config
    }

    /// Exchange authorization code for access token
    /// - Parameter code: The authorization code from GitHub callback
    /// - Returns: GitHub access token
    public func exchangeCodeForToken(code: String) async throws -> GitHubAccessToken {
        var request = HTTPClientRequest(url: "https://github.com/login/oauth/access_token")
        request.method = .POST
        request.headers.add(name: "Accept", value: "application/json")
        request.headers.add(name: "Content-Type", value: "application/json")

        let body = TokenExchangeRequest(
            clientId: config.clientId,
            clientSecret: config.clientSecret,
            code: code,
            redirectUri: config.callbackURL
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.body = .bytes(ByteBuffer(data: try encoder.encode(body)))

        let response = try await httpClient.execute(request, timeout: .seconds(30))

        guard response.status == .ok else {
            let errorBody = try await response.body.collect(upTo: 1024 * 1024)
            let errorMessage = String(buffer: errorBody)
            throw GitHubOAuthError.tokenExchangeFailed(errorMessage)
        }

        let responseBody = try await response.body.collect(upTo: 1024 * 1024)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(GitHubAccessToken.self, from: responseBody)
    }

    /// Fetch authenticated user information
    /// - Parameter accessToken: The GitHub access token
    /// - Returns: GitHub user information
    public func fetchUserInfo(accessToken: String) async throws -> GitHubUser {
        var request = HTTPClientRequest(url: "https://api.github.com/user")
        request.method = .GET
        request.headers.add(name: "Accept", value: "application/vnd.github.v3+json")
        request.headers.add(name: "Authorization", value: "Bearer \(accessToken)")
        request.headers.add(name: "User-Agent", value: "ai-prd-builder-vapor/1.0")

        let response = try await httpClient.execute(request, timeout: .seconds(30))

        guard response.status == .ok else {
            let errorBody = try await response.body.collect(upTo: 1024 * 1024)
            let errorMessage = String(buffer: errorBody)
            throw GitHubOAuthError.userInfoFailed(errorMessage)
        }

        let responseBody = try await response.body.collect(upTo: 1024 * 1024)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(GitHubUser.self, from: responseBody)
    }
}

// MARK: - Models

struct TokenExchangeRequest: Codable {
    let clientId: String
    let clientSecret: String
    let code: String
    let redirectUri: String
}

public struct GitHubAccessToken: Codable {
    public let accessToken: String
    public let tokenType: String
    public let scope: String

    public init(accessToken: String, tokenType: String, scope: String) {
        self.accessToken = accessToken
        self.tokenType = tokenType
        self.scope = scope
    }
}

public struct GitHubUser: Codable {
    public let id: Int
    public let login: String
    public let name: String?
    public let email: String?
    public let avatarUrl: String
    public let htmlUrl: String
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: Int,
        login: String,
        name: String?,
        email: String?,
        avatarUrl: String,
        htmlUrl: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.login = login
        self.name = name
        self.email = email
        self.avatarUrl = avatarUrl
        self.htmlUrl = htmlUrl
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Errors

public enum GitHubOAuthError: Error, CustomStringConvertible {
    case tokenExchangeFailed(String)
    case userInfoFailed(String)
    case invalidState
    case missingConfiguration

    public var description: String {
        switch self {
        case .tokenExchangeFailed(let message):
            return "Failed to exchange code for token: \(message)"
        case .userInfoFailed(let message):
            return "Failed to fetch user info: \(message)"
        case .invalidState:
            return "Invalid OAuth state parameter"
        case .missingConfiguration:
            return "GitHub OAuth is not configured. Set GITHUB_OAUTH_CLIENT_ID and GITHUB_OAUTH_CLIENT_SECRET"
        }
    }
}
