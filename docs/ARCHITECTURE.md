# Architecture Documentation - AI PRD Builder System

## System Overview

The AI PRD Builder is a **multi-platform system** consisting of:

1. **Swift Library** (`ai-prd-builder/swift`) - Core business logic, shared across all platforms
2. **Vapor Backend** (`ai-prd-builder-vapor-server`) - HTTP/WebSocket gateway for web clients
3. **Web Frontend** (`ai-prd-builder-web`) - Browser-based UI
4. **Mobile Apps** (iOS/Android) - Native mobile clients (future)
5. **Desktop Apps** (macOS/Windows) - Native desktop clients (future)

## Critical Architectural Decision

### The Library Owns Orchestration Logic

**Decision**: The Swift library (`ai-prd-builder/swift`) contains ALL business logic, orchestration, and workflow coordination. The Vapor backend is intentionally a **thin pass-through layer**.

**Rationale**:
- The same library will be embedded in iOS, Android, macOS, Windows, and Web clients
- Business logic must be consistent across all platforms
- Mobile/desktop apps will call the library directly (no backend involved)
- Backend exists ONLY to serve web clients that cannot embed Swift code
- Orchestration living in the library ensures identical behavior everywhere

**Architecture Pattern**: **Shared Library with Platform-Specific Adapters**

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│                    ai-prd-builder/swift                         │
│                   (SHARED LIBRARY)                              │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐   │
│  │  Orchestration (owns all workflow logic)               │   │
│  │  - PRDOrchestrator                                     │   │
│  │  - AnalysisOrchestrator                                │   │
│  │  - ImplementationAnalyzer                              │   │
│  └────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐   │
│  │  Domain Logic                                           │   │
│  │  - PRDGenerator (business rules)                       │   │
│  │  - ImplementationAnalysis (codebase analysis)          │   │
│  │  - ThinkingCore (reasoning engine)                     │   │
│  └────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐   │
│  │  Utilities                                              │   │
│  │  - Parsers, Formatters, Validators                     │   │
│  └────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                            ↑
                            │ embedded or called via API
                            ↓
┌─────────────┬──────────────┬──────────────┬──────────────┬─────┐
│             │              │              │              │     │
│   iOS App   │  Android App │  macOS App   │ Windows App  │ Web │
│   (direct)  │   (direct)   │   (direct)   │  (direct)    │(API)│
│             │              │              │              │     │
└─────────────┴──────────────┴──────────────┴──────────────┴─────┘
                                                              ↑
                                                              │
                                                      calls Vapor
                                                              ↓
                                            ┌──────────────────────┐
                                            │  Vapor Backend       │
                                            │  (PASS-THROUGH)      │
                                            │                      │
                                            │  - HTTP endpoints    │
                                            │  - Auth/Sessions     │
                                            │  - Database persist  │
                                            │  - Calls library →   │
                                            └──────────────────────┘
```

## Vapor Backend Role

### What Vapor Backend IS

**A Platform-Specific Adapter** - Provides HTTP/WebSocket interface to the shared library for web clients

**Responsibilities**:
1. **HTTP API Gateway** - Expose library functions as REST endpoints
2. **Authentication** - User sessions, OAuth, API keys
3. **Persistence** - Store PRDs, codebases, uploads in Supabase/Postgres
4. **File Storage** - Handle mockup uploads, codebase imports
5. **WebSocket** - Real-time updates for long-running operations
6. **Multi-tenancy** - Isolate user data
7. **Rate Limiting** - Protect shared resources
8. **Logging/Monitoring** - Observability for web traffic

### What Vapor Backend IS NOT

**NOT a Business Logic Layer** - Does NOT contain:
- ❌ PRD generation algorithms
- ❌ Requirements analysis logic
- ❌ Codebase analysis logic
- ❌ AI orchestration
- ❌ Professional analysis calculations
- ❌ Workflow coordination

All of these live in the **Swift library** and are identical across all platforms.

## Clean Architecture in This Context

### Traditional Clean Architecture (Single Application)

```
Presentation → Application → Domain ← Infrastructure
```

### Our Multi-Platform Architecture (Shared Library)

```
Platform Adapter (Vapor/iOS/Android/macOS/Windows)
    ↓ thin layer
    ↓
Shared Library (Domain + Application + Orchestration)
    ↓ depends on abstractions
    ↓
Platform-Specific Infrastructure (AI providers, storage, etc.)
```

**Key Insight**: The "Application" layer lives in the **shared library**, NOT in each platform adapter.

## Vapor Backend Layers

### Layer 1: Domain (Persistence Models Only)

**Purpose**: Define data models that need to persist in Vapor's database

```swift
// Domain/Entities/PRDDocument.swift
struct PRDDocument: Model {
    @ID var id: UUID?
    @Field var userId: UUID
    @Field var title: String
    @Field var content: String  // JSON from library's PRDocument
    @Field var status: PRDStatus
    @Timestamp(on: .create) var createdAt: Date?
}
```

**Rules**:
- These are **persistence models**, NOT business entities
- Map from library's business models (e.g., `PRDGenerator.PRDocument`)
- Only fields needed for database queries/relations
- No business logic

### Layer 2: Application (Thin Use Cases)

**Purpose**: Coordinate library calls with persistence

```swift
// Application/UseCases/GeneratePRDUseCase.swift
final class GeneratePRDUseCase {
    private let orchestrator: PRDOrchestrator  // From library
    private let repository: PRDRepositoryProtocol  // Vapor persistence

    func execute(command: GeneratePRDCommand) async throws -> UUID {
        // 1. Call library (does all the work)
        let prdResult = try await orchestrator.generatePRD(
            request: command.toPRDRequest()
        )

        // 2. Persist result
        let document = PRDDocument(from: prdResult, userId: command.userId)
        try await repository.save(document)

        // 3. Return ID
        return document.id!
    }
}
```

**Rules**:
- Orchestrate library calls + persistence
- NO business logic (library does that)
- Map between HTTP DTOs ↔ Library types ↔ Database models
- Transaction boundaries

### Layer 3: Infrastructure (Adapters)

**Purpose**: Implement platform-specific concerns

```swift
// Infrastructure/Repositories/SupabasePRDRepository.swift
final class SupabasePRDRepository: PRDRepositoryProtocol {
    func save(_ document: PRDDocument) async throws {
        // Supabase-specific persistence
    }
}

// Infrastructure/AIProviders/NativePRDGeneratorProvider.swift
final class NativePRDGeneratorProvider: AIProviderPort {
    private let libraryOrchestrator: PRDOrchestrator

    func generatePRD(...) async throws -> PRDGenerationResult {
        // Thin wrapper - just calls library
        let result = try await libraryOrchestrator.generatePRD(...)
        return PRDGenerationResult(from: result)
    }
}
```

**Rules**:
- Implement persistence (Supabase, MongoDB, etc.)
- Wrap library orchestrators in Vapor's port interfaces
- Handle Vapor-specific concerns (Fluent, async context, etc.)

### Layer 4: Presentation (Controllers)

**Purpose**: HTTP/WebSocket endpoints

```swift
// Presentation/Controllers/PRDController.swift
final class PRDController: RouteCollection {
    func create(_ req: Request) async throws -> PRDResponse {
        // 1. Parse HTTP request
        let dto = try req.content.decode(CreatePRDRequestDTO.self)

        // 2. Validate auth
        let user = try req.auth.require(User.self)

        // 3. Call use case
        let command = GeneratePRDCommand(from: dto, userId: user.id)
        let prdId = try await generatePRDUseCase.execute(command)

        // 4. Return HTTP response
        return PRDResponse(id: prdId, status: .processing)
    }
}
```

**Rules**:
- Parse HTTP requests → DTOs
- Delegate to use cases
- Map responses to HTTP format
- Handle errors → HTTP status codes

## Dependency Rules

### ✅ ALLOWED Dependencies

```
Vapor Domain → NOTHING (pure persistence models)

Vapor Application → Vapor Domain
Vapor Application → Swift Library (Orchestration, PRDGenerator, etc.)

Vapor Infrastructure → Vapor Domain
Vapor Infrastructure → Vapor Application
Vapor Infrastructure → Swift Library

Vapor Presentation → Vapor Application
Vapor Presentation → Vapor Domain (DTOs only)
```

### ❌ FORBIDDEN Dependencies

```
❌ Vapor Domain → Swift Library
   (Domain should not depend on external business logic)

❌ Vapor Presentation → Swift Library
   (Controllers should go through use cases)

❌ Vapor Infrastructure → Vapor Presentation
   (Backwards dependency)
```

## Import Rules

### Vapor Domain Layer

```swift
// ✅ ALLOWED
import Foundation
import Fluent
import Vapor

// ❌ FORBIDDEN
import PRDGenerator        // Business logic
import Orchestration       // Orchestration
import ImplementationAnalysis  // Feature modules
import CommonModels       // Only if truly shared types
```

### Vapor Application Layer

```swift
// ✅ ALLOWED
import Foundation
import PRDGenerator        // OK - use cases call library
import Orchestration       // OK - use cases orchestrate
import ImplementationAnalysis  // OK - use cases use features

// ❌ FORBIDDEN
import Vapor              // Use cases should be HTTP-agnostic
import Fluent             // Repositories handle persistence
```

### Vapor Infrastructure Layer

```swift
// ✅ ALLOWED - Everything
import Foundation
import Vapor
import Fluent
import PRDGenerator
import Orchestration
import ImplementationAnalysis
import CommonModels
// etc.
```

### Vapor Presentation Layer

```swift
// ✅ ALLOWED
import Foundation
import Vapor

// ❌ FORBIDDEN
import PRDGenerator        // Should call through use cases
import Orchestration       // Should call through use cases
```

## File Organization

### Recommended Structure

```
ai-prd-builder-vapor-server/
├── Sources/
│   ├── Domain/
│   │   ├── Entities/           # Persistence models only
│   │   │   ├── PRDDocument.swift
│   │   │   ├── CodebaseProject.swift
│   │   │   └── MockupUpload.swift
│   │   ├── ValueObjects/       # Shared value types
│   │   └── Errors/
│   │
│   ├── Application/
│   │   ├── UseCases/
│   │   │   ├── PRD/
│   │   │   │   ├── GeneratePRDUseCase.swift
│   │   │   │   ├── UpdatePRDUseCase.swift
│   │   │   │   └── ExportPRDUseCase.swift
│   │   │   ├── Codebase/
│   │   │   │   ├── IndexCodebaseUseCase.swift
│   │   │   │   └── LinkCodebaseUseCase.swift
│   │   │   └── Mockup/
│   │   │       └── UploadMockupUseCase.swift
│   │   ├── DTOs/               # Data transfer objects
│   │   └── Ports/              # Repository interfaces
│   │       ├── PRDRepositoryProtocol.swift
│   │       └── CodebaseRepositoryProtocol.swift
│   │
│   ├── Infrastructure/
│   │   ├── Repositories/
│   │   │   ├── Supabase/
│   │   │   │   ├── SupabasePRDRepository.swift
│   │   │   │   └── SupabaseCodebaseRepository.swift
│   │   │   └── MongoDB/
│   │   ├── AIProviders/        # Wrappers around library
│   │   │   ├── NativePRDGeneratorProvider.swift
│   │   │   ├── AnthropicProvider.swift
│   │   │   └── OpenAIProvider.swift
│   │   ├── Storage/
│   │   │   └── SupabaseStorageClient.swift
│   │   └── GitHub/
│   │       └── GitHubOAuthService.swift
│   │
│   ├── Presentation/
│   │   ├── Controllers/
│   │   │   ├── PRDController.swift
│   │   │   ├── CodebaseController.swift
│   │   │   └── MockupController.swift
│   │   ├── DTOs/               # HTTP-specific DTOs
│   │   ├── Middleware/
│   │   └── WebSocket/
│   │
│   └── App/
│       ├── Configuration/
│       ├── Container/          # DI setup
│       └── configure.swift
│
└── Package.swift
    dependencies: [
        .package(path: "../ai-prd-builder/swift")  # The library
    ]
```

## Data Flow Examples

### Example 1: Generate PRD (Web Client)

```
1. Web Client (React)
   ↓ POST /api/prds

2. Vapor - PRDController
   ↓ Parse HTTP, validate auth

3. Vapor - GeneratePRDUseCase
   ↓ Call library

4. Swift Library - PRDOrchestrator.generatePRD()
   ↓ Orchestrates:
      - Requirements analysis (ThinkingCore)
      - Professional analysis (ChallengePredictor, ConflictAnalyzer)
      - AI generation (PRDGenerator)
      - Formatting (DocumentAssembler)
   ↓ Returns PRDocument

5. Vapor - GeneratePRDUseCase
   ↓ Persist

6. Vapor - SupabasePRDRepository.save()
   ↓ Store in database

7. Vapor - PRDController
   ↓ Return HTTP 201 with ID

8. Web Client
   ✓ Receive PRD ID
```

### Example 2: Generate PRD (iOS Native)

```
1. iOS App (SwiftUI)
   ↓ Direct function call

2. Swift Library - PRDOrchestrator.generatePRD()
   ↓ Orchestrates (same as web):
      - Requirements analysis
      - Professional analysis
      - AI generation
      - Formatting
   ↓ Returns PRDocument

3. iOS App
   ↓ Persist locally (Core Data / SQLite)

4. iOS App
   ✓ Display PRD in UI
```

**Note**: iOS app gets IDENTICAL business logic without HTTP overhead.

## Type Mapping Strategy

### Library Types → Vapor Persistence Types

The library defines business entities (e.g., `PRDocument`). Vapor defines persistence models (e.g., `PRDDocument`).

**Mapping approach**:

```swift
// Library type (from ai-prd-builder/swift)
public struct PRDocument {
    public let title: String
    public let sections: [PRDSection]
    public let metadata: PRDMetadata
    public let professionalAnalysis: ProfessionalAnalysis?
}

// Vapor persistence type
final class PRDDocument: Model {
    @ID var id: UUID?
    @Field var userId: UUID
    @Field var title: String
    @Field var sectionsJSON: String  // Serialized
    @Field var metadataJSON: String
    @Field var analysisJSON: String?
    @Field var status: PRDStatus
    @Timestamp(on: .create) var createdAt: Date?

    // Mapping helpers
    convenience init(from prDocument: PRDocument, userId: UUID) {
        self.init()
        self.userId = userId
        self.title = prDocument.title
        self.sectionsJSON = try! JSONEncoder().encode(prDocument.sections)
        self.metadataJSON = try! JSONEncoder().encode(prDocument.metadata)
        self.analysisJSON = prDocument.professionalAnalysis.map {
            try! JSONEncoder().encode($0)
        }
        self.status = .completed
    }

    func toPRDocument() throws -> PRDocument {
        PRDocument(
            title: title,
            sections: try JSONDecoder().decode([PRDSection].self, from: sectionsJSON.data(using: .utf8)!),
            metadata: try JSONDecoder().decode(PRDMetadata.self, from: metadataJSON.data(using: .utf8)!),
            professionalAnalysis: try analysisJSON.flatMap {
                try JSONDecoder().decode(ProfessionalAnalysis.self, from: $0.data(using: .utf8)!)
            }
        )
    }
}
```

**Rules**:
- Library types are the "source of truth" for business data structure
- Vapor types optimize for database queries (flattened, indexed fields)
- Mapping happens in Use Cases or Repository layer
- Never modify library types to fit Vapor's needs

## Testing Strategy

### Library Testing (ai-prd-builder/swift)

**Responsibility**: Test ALL business logic

```swift
// Test pure logic
class PRDGeneratorTests: XCTestCase {
    func testGeneratesSections_withValidInput() {
        let generator = PRDGenerator()
        let result = generator.generateSections(request: validRequest)
        XCTAssertEqual(result.sections.count, 7)
    }
}

// Test orchestration
class PRDOrchestratorTests: XCTestCase {
    func testOrchestrates_fullPRDGeneration() async throws {
        let mockAI = MockAIProvider()
        let orchestrator = PRDOrchestrator(aiProvider: mockAI)
        let result = try await orchestrator.generatePRD(request: validRequest)
        XCTAssertNotNil(result.professionalAnalysis)
    }
}
```

**Coverage Target**: 80%+ (all business logic)

### Vapor Testing

**Responsibility**: Test HTTP layer, persistence, auth

```swift
// Test use cases (with mocked library)
class GeneratePRDUseCaseTests: XCTestCase {
    func testExecute_callsLibraryAndPersists() async throws {
        let mockOrchestrator = MockPRDOrchestrator()
        let mockRepository = MockPRDRepository()
        let useCase = GeneratePRDUseCase(
            orchestrator: mockOrchestrator,
            repository: mockRepository
        )

        let id = try await useCase.execute(command: validCommand)

        XCTAssertTrue(mockOrchestrator.generatePRDCalled)
        XCTAssertTrue(mockRepository.saveCalled)
    }
}

// Test controllers (with mocked use cases)
class PRDControllerTests: XCTestCase {
    func testCreate_returnsCreatedResponse() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        try configure(app)

        try app.test(.POST, "/api/prds", beforeRequest: { req in
            try req.content.encode(CreatePRDRequestDTO(title: "Test"))
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .created)
        })
    }
}

// Test repositories (integration)
class SupabasePRDRepositoryTests: XCTestCase {
    func testSave_persistsToDatabase() async throws {
        let db = // test database connection
        let repository = SupabasePRDRepository(db: db)

        let document = PRDDocument(id: UUID(), userId: testUserId, title: "Test")
        try await repository.save(document)

        let fetched = try await repository.findById(document.id!)
        XCTAssertEqual(fetched?.title, "Test")
    }
}
```

**Coverage Target**: 70%+ (focus on integration points)

## Deployment Architecture

### Production Setup

```
┌────────────────────────────────────────────────────────────┐
│                        Users                               │
└───────────────┬───────────────┬────────────────────────────┘
                │               │
        ┌───────▼────┐   ┌──────▼──────┐
        │ Web Client │   │  iOS Client │
        │  (React)   │   │   (Native)  │
        └───────┬────┘   └──────┬──────┘
                │               │
                │               │ Direct library calls
        ┌───────▼────────────────────────────┐
        │     Vapor Backend (Load Balanced)  │
        │  ┌──────┐  ┌──────┐  ┌──────┐    │
        │  │ Srv1 │  │ Srv2 │  │ Srv3 │    │
        │  └──┬───┘  └──┬───┘  └──┬───┘    │
        │     └─────────┼─────────┘         │
        └───────────────┼───────────────────┘
                        │
        ┌───────────────▼───────────────────┐
        │          Supabase                 │
        │  ┌──────────┐  ┌──────────────┐  │
        │  │ Postgres │  │ File Storage │  │
        │  └──────────┘  └──────────────┘  │
        └───────────────────────────────────┘
```

**Scaling considerations**:
- Web clients → Vapor backend (HTTP/WebSocket)
- iOS/Android/Desktop clients → Embedded library (no backend)
- Backend scales horizontally (stateless)
- Heavy computation happens in library (same code everywhere)

## Migration Path from Current State

### Current Problem

The current Vapor server has violated boundaries:
```swift
// ❌ Domain/Ports/AIProviderPort.swift
import PRDGenerator  // Domain importing business logic!

public protocol AIProviderPort {
    func generatePRD(
        from command: GeneratePRDCommand,  // Type from library
        contextRequestPort: ContextRequestPort?  // Type from library
    ) async throws -> PRDGenerationResult  // Type from library
}
```

### Step 1: Accept the Reality

**The library owns orchestration** - this is correct for multi-platform support.

**The Vapor backend is a pass-through** - this is also correct.

### Step 2: Fix the Boundary Violations

Move library imports OUT of Domain, INTO Application/Infrastructure:

```swift
// ✅ Domain/Ports/PRDRepositoryProtocol.swift
// No library imports!
public protocol PRDRepositoryProtocol {
    func save(_ document: PRDDocument) async throws
    func findById(_ id: UUID) async throws -> PRDDocument?
}

// ✅ Application/UseCases/GeneratePRDUseCase.swift
import PRDGenerator  // OK - Application can import library
import Orchestration

final class GeneratePRDUseCase {
    private let orchestrator: PRDOrchestrator  // From library
    private let repository: PRDRepositoryProtocol  // From Vapor domain

    func execute(command: GeneratePRDCommand) async throws -> UUID {
        // Call library (does orchestration)
        let result = try await orchestrator.generatePRD(...)

        // Persist (Vapor's responsibility)
        let doc = PRDDocument(from: result, userId: command.userId)
        try await repository.save(doc)

        return doc.id!
    }
}
```

### Step 3: Embrace the Pass-Through Pattern

**Don't fight it** - the backend is intentionally thin:

```swift
// This is OK! Vapor is just glue code
class GeneratePRDUseCase {
    func execute(...) async throws -> UUID {
        // 1. Call library (90% of the work)
        let result = try await orchestrator.generatePRD(...)

        // 2. Persist (10% of the work)
        try await repository.save(PRDDocument(from: result))

        return result.id
    }
}
```

The use case is thin because **the library does the real work**.

## Anti-Patterns to Avoid

### ❌ Anti-Pattern #1: Duplicating Orchestration

```swift
// ❌ BAD - Reimplementing library logic in Vapor
class GeneratePRDUseCase {
    func execute(...) async throws -> UUID {
        // Don't do this - let the library handle it!
        let requirements = try await analyzeRequirements(...)
        let analysis = try await runProfessionalAnalysis(...)
        let sections = try await generateSections(...)
        let formatted = try await formatDocument(...)
        // ...
    }
}
```

### ❌ Anti-Pattern #2: Library Importing Vapor Types

```swift
// ❌ BAD - Library should never know about Vapor
// In ai-prd-builder/swift/Sources/Orchestration/PRDOrchestrator.swift
import Vapor  // NO!

public class PRDOrchestrator {
    func generatePRD(req: Request) async throws -> PRDocument {  // NO!
        // ...
    }
}
```

### ❌ Anti-Pattern #3: Business Logic in Controllers

```swift
// ❌ BAD - Controllers should be thin
class PRDController {
    func create(_ req: Request) async throws -> PRDResponse {
        let dto = try req.content.decode(CreatePRDRequestDTO.self)

        // ❌ Don't put business logic here!
        if dto.title.isEmpty {
            throw Abort(.badRequest, reason: "Title required")
        }

        let orchestrator = PRDOrchestrator(...)
        let result = try await orchestrator.generatePRD(...)

        // ❌ Don't persist directly in controller!
        try await PRDDocument(...).save(on: req.db)

        return PRDResponse(...)
    }
}

// ✅ GOOD - Delegate to use case
class PRDController {
    func create(_ req: Request) async throws -> PRDResponse {
        let dto = try req.content.decode(CreatePRDRequestDTO.self)
        let user = try req.auth.require(User.self)

        let command = GeneratePRDCommand(from: dto, userId: user.id)
        let id = try await generatePRDUseCase.execute(command)

        return PRDResponse(id: id, status: .processing)
    }
}
```

## Summary

### Key Principles

1. **Library Owns Business Logic** - All platforms use the same business rules
2. **Backend is a Gateway** - Vapor exists to serve web clients over HTTP
3. **Domain is Persistence-Focused** - Vapor's domain models are for database storage
4. **Application Orchestrates Library + Persistence** - Use cases call library, then persist
5. **Infrastructure Wraps External Services** - Repositories, storage, auth

### Success Criteria

- ✅ Domain layer has ZERO imports of PRDGenerator/Orchestration/ImplementationAnalysis
- ✅ Application layer freely uses library (this is correct!)
- ✅ Controllers delegate to use cases (never call library directly)
- ✅ Same library code runs in iOS/Android/Web/Desktop
- ✅ PRD generation logic identical across all platforms

### This Architecture Enables

1. **Code Reuse** - Write business logic once, run everywhere
2. **Platform Parity** - Web, iOS, Android get identical features
3. **Offline Support** - Mobile apps work without backend
4. **Easy Testing** - Library can be tested independently
5. **Flexible Deployment** - Backend scales separately from library logic

---

**Document Version**: 1.0
**Last Updated**: 2025-10-03
**Author**: AI PRD Builder Team
**Status**: Approved Architecture
