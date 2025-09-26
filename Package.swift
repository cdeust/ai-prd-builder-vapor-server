// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "PRDGeneratorAPI",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "Run", targets: ["Run"]),
        .library(name: "App", targets: ["App"]),
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Application", targets: ["Application"]),
        .library(name: "Infrastructure", targets: ["Infrastructure"]),
        .library(name: "Presentation", targets: ["Presentation"])
    ],
    dependencies: [
        // Vapor Framework
        .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.8.0"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.8.0"),
        .package(url: "https://github.com/vapor/redis.git", from: "4.10.0"),
        .package(url: "https://github.com/vapor/jwt.git", from: "4.2.0"),

        // Metrics & Monitoring
        .package(url: "https://github.com/swift-server/swift-prometheus.git", from: "1.0.0"),

        // HTTP Client for AI providers
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.19.0"),

        // MongoDB Swift Driver
        .package(url: "https://github.com/mongodb/mongo-swift-driver.git", from: "1.3.1"),

        // AI Provider SDKs (when available)
        // .package(url: "https://github.com/anthropics/anthropic-sdk-swift.git", from: "1.0.0"),

        // Internal PRD Generator Package - Full ai-orchestrator system
        .package(path: "../ai-prd-builder/swift"),

        // Testing
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.5.0"), // For testing
    ],
    targets: [
        // MARK: - Domain Layer (Core Business Logic - No Dependencies)
        .target(
            name: "Domain",
            dependencies: []
        ),

        // MARK: - Application Layer (Use Cases)
        .target(
            name: "Application",
            dependencies: [
                "Domain"
            ]
        ),

        // MARK: - Infrastructure Layer (External Services)
        .target(
            name: "Infrastructure",
            dependencies: [
                "Domain",
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "MongoSwift", package: "mongo-swift-driver"),
                .product(name: "Redis", package: "redis"),
                // Complete ai-orchestrator system integration
                .product(name: "PRDGenerator", package: "swift"),
                .product(name: "CommonModels", package: "swift"),
                .product(name: "DomainCore", package: "swift"),
                .product(name: "Orchestration", package: "swift"),
                .product(name: "AIProvidersCore", package: "swift"),
                .product(name: "AIProviderImplementations", package: "swift"),
                .product(name: "ThinkingCore", package: "swift"),
                .product(name: "ImplementationAnalysis", package: "swift"),
                .product(name: "SessionManagement", package: "swift")
            ]
        ),

        // MARK: - Presentation Layer (Web/API)
        .target(
            name: "Presentation",
            dependencies: [
                "Domain",
                "Application",
                "Infrastructure",
                .product(name: "Vapor", package: "vapor"),
                .product(name: "JWT", package: "jwt"),
                .product(name: "SwiftPrometheus", package: "swift-prometheus")
            ]
        ),

        // MARK: - App (Bootstrap & DI Container)
        .target(
            name: "App",
            dependencies: [
                "Domain",
                "Application",
                "Infrastructure",
                "Presentation",
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver")
            ]
        ),

        // MARK: - Run (Executable)
        .executableTarget(
            name: "Run",
            dependencies: [
                "App",
                .product(name: "Vapor", package: "vapor")
            ]
        ),

        // MARK: - Tests
        .testTarget(
            name: "DomainTests",
            dependencies: ["Domain"]
        ),
        .testTarget(
            name: "ApplicationTests",
            dependencies: ["Application", "Domain"]
        ),
        .testTarget(
            name: "InfrastructureTests",
            dependencies: [
                "Infrastructure",
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver")
            ]
        ),
        .testTarget(
            name: "PresentationTests",
            dependencies: [
                "Presentation",
                .product(name: "XCTVapor", package: "vapor")
            ]
        ),
        .testTarget(
            name: "AppTests",
            dependencies: [
                "App",
                .product(name: "XCTVapor", package: "vapor")
            ]
        )
    ]
)
