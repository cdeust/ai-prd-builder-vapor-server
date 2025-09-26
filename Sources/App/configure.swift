import Vapor

/// Configure the Vapor application
public func configure(_ app: Application) throws {
    // Initialize configurators
    let databaseConfigurator = DatabaseConfigurator(app: app)
    let middlewareConfigurator = MiddlewareConfigurator(app: app)
    let contentConfigurator = ContentConfigurator(app: app)
    let serverConfigurator = ServerConfigurator(app: app)
    let routeConfigurator = RouteConfigurator(app: app)

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