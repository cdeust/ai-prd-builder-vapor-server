import Vapor
import Infrastructure

/// Controller for GitHub OAuth authentication
public final class GitHubAuthController: RouteCollection, @unchecked Sendable {
    private let oauthService: GitHubOAuthService?
    private let oauthConfig: GitHubOAuthConfig?
    private let tokenConfig: GitHubTokenConfig

    public init(
        oauthService: GitHubOAuthService?,
        oauthConfig: GitHubOAuthConfig?,
        tokenConfig: GitHubTokenConfig
    ) {
        self.oauthService = oauthService
        self.oauthConfig = oauthConfig
        self.tokenConfig = tokenConfig
    }

    public func boot(routes: RoutesBuilder) throws {
        let auth = routes.grouped("auth", "github")

        auth.get("login", use: initiateOAuth)
        auth.get("callback", use: handleCallback)
        auth.get("status", use: checkStatus)
    }

    // MARK: - OAuth Flow

    /// GET /auth/github/login
    /// Initiate OAuth flow by redirecting to GitHub
    @Sendable
    private func initiateOAuth(req: Request) async throws -> Response {
        guard let config = oauthConfig else {
            throw Abort(.notImplemented, reason: "GitHub OAuth is not configured")
        }

        // Generate state for CSRF protection
        let state = UUID().uuidString
        req.session.data["github_oauth_state"] = state

        let authURL = "\(config.authorizationURL)&state=\(state)"
        return req.redirect(to: authURL)
    }

    /// GET /auth/github/callback
    /// Handle OAuth callback from GitHub
    @Sendable
    private func handleCallback(req: Request) async throws -> Response {
        guard let oauthService = oauthService else {
            throw Abort(.notImplemented, reason: "GitHub OAuth is not configured")
        }

        // Verify state parameter for CSRF protection
        let receivedState = try req.query.get(String.self, at: "state")
        let storedState = req.session.data["github_oauth_state"]

        guard receivedState == storedState else {
            throw Abort(.badRequest, reason: "Invalid OAuth state")
        }

        // Get authorization code
        let code = try req.query.get(String.self, at: "code")

        do {
            // Exchange code for access token
            let tokenResponse = try await oauthService.exchangeCodeForToken(code: code)

            // Fetch user information
            let user = try await oauthService.fetchUserInfo(accessToken: tokenResponse.accessToken)

            // Store access token in session (in production, store in database)
            req.session.data["github_access_token"] = tokenResponse.accessToken
            req.session.data["github_user_id"] = String(user.id)
            req.session.data["github_username"] = user.login

            req.logger.info("✅ GitHub OAuth successful for user: \(user.login)")

            // Create success response
            let response = GitHubAuthSuccessResponse(
                success: true,
                message: "GitHub authentication successful",
                user: GitHubUserDTO(
                    id: user.id,
                    login: user.login,
                    name: user.name,
                    email: user.email,
                    avatarUrl: user.avatarUrl
                ),
                accessToken: tokenResponse.accessToken
            )

            return try await response.encodeResponse(for: req)

        } catch {
            req.logger.error("❌ GitHub OAuth failed: \(error)")
            throw Abort(.unauthorized, reason: "GitHub authentication failed: \(error.localizedDescription)")
        }
    }

    /// GET /auth/github/status
    /// Check current authentication status
    @Sendable
    private func checkStatus(req: Request) async throws -> GitHubAuthStatusResponse {
        let isAuthenticated = req.session.data["github_access_token"] != nil
        let username = req.session.data["github_username"]
        let hasEnvToken = tokenConfig.accessToken != nil

        return GitHubAuthStatusResponse(
            authenticated: isAuthenticated,
            username: username,
            oauthConfigured: oauthConfig != nil,
            environmentTokenConfigured: hasEnvToken
        )
    }
}

// MARK: - DTOs

public struct GitHubAuthSuccessResponse: Content {
    public let success: Bool
    public let message: String
    public let user: GitHubUserDTO
    public let accessToken: String
}

public struct GitHubUserDTO: Content {
    public let id: Int
    public let login: String
    public let name: String?
    public let email: String?
    public let avatarUrl: String
}

public struct GitHubAuthStatusResponse: Content {
    public let authenticated: Bool
    public let username: String?
    public let oauthConfigured: Bool
    public let environmentTokenConfigured: Bool
}

// MARK: - Session Extensions

// MARK: - Request Extensions

extension Request {
    /// Get GitHub access token from session or environment
    /// Note: Environment token must be passed from App layer via controller
    public var githubAccessToken: String? {
        // Check session (user-specific OAuth token)
        return session.data["github_access_token"]
    }
}
