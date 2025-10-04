import Foundation

/// GitHub OAuth Configuration
public struct GitHubOAuthConfig: Sendable {
    public let clientId: String
    public let clientSecret: String
    public let callbackURL: String
    public let scopes: [String]

    public init(
        clientId: String,
        clientSecret: String,
        callbackURL: String,
        scopes: [String] = ["repo", "user:email"]
    ) {
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.callbackURL = callbackURL
        self.scopes = scopes
    }

    /// Authorization URL for redirecting users
    public var authorizationURL: String {
        let scopeString = scopes.joined(separator: "%20")
        return "https://github.com/login/oauth/authorize?client_id=\(clientId)&redirect_uri=\(callbackURL)&scope=\(scopeString)"
    }
}

/// GitHub Token Configuration
public struct GitHubTokenConfig: Sendable {
    public let accessToken: String?

    public init(accessToken: String?) {
        self.accessToken = accessToken
    }
}
