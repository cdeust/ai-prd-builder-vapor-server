import Vapor
import Infrastructure

// MARK: - Environment Loading Extensions

extension GitHubOAuthConfig {
    /// Load configuration from environment variables
    public static func fromEnvironment(_ app: Application) throws -> GitHubOAuthConfig? {
        guard let clientId = Environment.get("GITHUB_OAUTH_CLIENT_ID"),
              let clientSecret = Environment.get("GITHUB_OAUTH_CLIENT_SECRET") else {
            return nil
        }

        let callbackURL = Environment.get("GITHUB_OAUTH_CALLBACK_URL")
            ?? "http://localhost:\(app.http.server.configuration.port)/auth/github/callback"

        return GitHubOAuthConfig(
            clientId: clientId,
            clientSecret: clientSecret,
            callbackURL: callbackURL
        )
    }
}

extension GitHubTokenConfig {
    /// Load default token from environment
    public static func fromEnvironment() -> GitHubTokenConfig {
        GitHubTokenConfig(accessToken: Environment.get("GITHUB_ACCESS_TOKEN"))
    }
}

// MARK: - Storage Keys

extension Application {
    public struct GitHubConfigKey: StorageKey {
        public typealias Value = GitHubOAuthConfig
    }

    public struct GitHubTokenKey: StorageKey {
        public typealias Value = GitHubTokenConfig
    }

    public var githubOAuth: GitHubOAuthConfig? {
        get { storage[GitHubConfigKey.self] }
        set { storage[GitHubConfigKey.self] = newValue }
    }

    public var githubToken: GitHubTokenConfig {
        get { storage[GitHubTokenKey.self] ?? GitHubTokenConfig.fromEnvironment() }
        set { storage[GitHubTokenKey.self] = newValue }
    }
}
