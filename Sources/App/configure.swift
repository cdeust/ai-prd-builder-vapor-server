import Vapor
import Infrastructure

/// Configure the Vapor application
public func configure(_ app: Application) throws {
    // Initialize configurators
    let databaseConfigurator = DatabaseConfigurator(app: app)
    let middlewareConfigurator = MiddlewareConfigurator(app: app)
    let contentConfigurator = ContentConfigurator(app: app)
    let serverConfigurator = ServerConfigurator(app: app)
    let routeConfigurator = RouteConfigurator(app: app)

    // Configure GitHub integration
    configureGitHub(app)

    // Apply configurations in order
    try databaseConfigurator.configure()
    middlewareConfigurator.configure()
    contentConfigurator.configure()

    // Register services with DI container
    try app.diContainer.registerServices()

    // Configure routes and server
    try routeConfigurator.configure()
    serverConfigurator.configure()
}

/// Configure GitHub OAuth and access token
private func configureGitHub(_ app: Application) {
    // Load GitHub OAuth configuration if available
    if let oauthConfig = try? GitHubOAuthConfig.fromEnvironment(app) {
        app.githubOAuth = oauthConfig
        app.logger.info("✅ GitHub OAuth configured with client ID: \(oauthConfig.clientId)")
    } else {
        app.logger.info("ℹ️ GitHub OAuth not configured (missing GITHUB_OAUTH_CLIENT_ID or GITHUB_OAUTH_CLIENT_SECRET)")
    }

    // Load default GitHub access token
    app.githubToken = GitHubTokenConfig.fromEnvironment()
    if app.githubToken.accessToken != nil {
        app.logger.info("✅ GitHub access token loaded from environment")
    } else {
        app.logger.warning("⚠️ No GitHub access token configured. Rate limit will be 60 requests/hour. Set GITHUB_ACCESS_TOKEN for higher limits.")
    }

    // Configure session for OAuth
    app.sessions.use(.memory)
}