# Import Rules - AI PRD Builder Vapor Server

## Quick Reference

| Layer            | Can Import                                    | Cannot Import                          |
|------------------|-----------------------------------------------|----------------------------------------|
| **Domain**       | Foundation, Fluent, Vapor (models only)      | PRDGenerator, Orchestration, Any library business logic |
| **Application**  | Domain, Library (all), Foundation            | Vapor, Fluent, Infrastructure           |
| **Infrastructure**| Everything                                   | Presentation                            |
| **Presentation** | Domain, Application, Vapor, Foundation        | Library directly, Infrastructure       |

## Detailed Rules by Layer

### Domain Layer

**Purpose**: Persistence models only (NOT business entities)

**Allowed Imports**:
```swift
✅ import Foundation
✅ import Fluent          // Database ORM
✅ import Vapor           // Only for Model conformance
```

**Forbidden Imports**:
```swift
❌ import PRDGenerator
❌ import Orchestration
❌ import ImplementationAnalysis
❌ import ThinkingCore
❌ import CommonModels      // Unless truly shared types
❌ import DomainCore        // Library's domain, not ours
```

**Why**: Domain should be pure persistence concerns. Business logic lives in the library.

**Example**:
```swift
// ✅ CORRECT
import Foundation
import Fluent
import Vapor

final class PRDDocument: Model {
    @ID var id: UUID?
    @Field var title: String
    // Persistence model only
}
```

---

### Application Layer

**Purpose**: Use cases that orchestrate library + persistence

**Allowed Imports**:
```swift
✅ import Foundation
✅ import PRDGenerator           // Call library business logic
✅ import Orchestration           // Use library orchestrators
✅ import ImplementationAnalysis  // Use library features
✅ import ThinkingCore            // Use library reasoning
✅ import CommonModels            // Shared types
✅ import DomainCore              // Library domain types
✅ (All library modules)          // Application USES the library
```

**Forbidden Imports**:
```swift
❌ import Vapor                   // Use cases should be HTTP-agnostic
❌ import Fluent                  // Repositories handle DB
❌ import Infrastructure          // Don't depend on concrete implementations
❌ import Presentation            // Layering violation
```

**Why**: Use cases coordinate library calls with persistence. They're allowed to know about the library because they USE it.

**Example**:
```swift
// ✅ CORRECT
import Foundation
import PRDGenerator
import Orchestration

final class GeneratePRDUseCase {
    private let orchestrator: PRDOrchestrator  // From library
    private let repository: PRDRepositoryProtocol  // From domain

    func execute(command: GeneratePRDCommand) async throws -> UUID {
        // Call library (does the work)
        let result = try await orchestrator.generatePRD(...)

        // Persist (our responsibility)
        let doc = PRDDocument(from: result, userId: command.userId)
        try await repository.save(doc)

        return doc.id!
    }
}
```

```swift
// ❌ INCORRECT
import Vapor  // Use cases shouldn't know about HTTP!

final class GeneratePRDUseCase {
    func execute(req: Request) async throws -> Response {  // NO!
        // Use cases should not handle HTTP concerns
    }
}
```

---

### Infrastructure Layer

**Purpose**: Implement adapters for external services

**Allowed Imports**:
```swift
✅ import Foundation
✅ import Vapor
✅ import Fluent
✅ import PRDGenerator
✅ import Orchestration
✅ import ImplementationAnalysis
✅ (All library modules)
✅ (All external SDKs)
✅ (Everything except Presentation)
```

**Forbidden Imports**:
```swift
❌ import Presentation            // Backwards dependency
```

**Why**: Infrastructure adapts external services to our ports. It's the "dirty" layer that knows about everything.

**Example**:
```swift
// ✅ CORRECT
import Foundation
import Fluent
import PRDGenerator
import Orchestration

final class SupabasePRDRepository: PRDRepositoryProtocol {
    private let db: Database

    func save(_ document: PRDDocument) async throws {
        try await document.save(on: db)
    }
}

final class NativePRDGeneratorProvider: AIProviderPort {
    private let orchestrator: PRDOrchestrator  // From library

    func generatePRD(command: GeneratePRDCommand) async throws -> PRDGenerationResult {
        // Wrap library in our port interface
        let result = try await orchestrator.generatePRD(...)
        return PRDGenerationResult(from: result)
    }
}
```

---

### Presentation Layer

**Purpose**: HTTP/WebSocket endpoints (controllers)

**Allowed Imports**:
```swift
✅ import Foundation
✅ import Vapor                   // HTTP framework
✅ import Domain (DTOs)           // Response models
✅ import Application             // Use cases
```

**Forbidden Imports**:
```swift
❌ import PRDGenerator            // Call through use cases, not directly
❌ import Orchestration           // Call through use cases
❌ import ImplementationAnalysis  // Call through use cases
❌ import Infrastructure          // Depend on abstractions (use cases)
❌ import Fluent                  // Don't query DB directly
```

**Why**: Controllers should be thin HTTP adapters. Business logic happens in Application layer.

**Example**:
```swift
// ✅ CORRECT
import Foundation
import Vapor

final class PRDController: RouteCollection {
    private let generateUseCase: GeneratePRDUseCase

    func create(_ req: Request) async throws -> PRDResponse {
        // 1. Parse HTTP
        let dto = try req.content.decode(CreatePRDRequestDTO.self)

        // 2. Validate auth
        let user = try req.auth.require(User.self)

        // 3. Delegate to use case
        let command = GeneratePRDCommand(from: dto, userId: user.id)
        let id = try await generateUseCase.execute(command)

        // 4. Return HTTP response
        return PRDResponse(id: id, status: .processing)
    }
}
```

```swift
// ❌ INCORRECT
import PRDGenerator
import Orchestration

final class PRDController: RouteCollection {
    func create(_ req: Request) async throws -> PRDResponse {
        let dto = try req.content.decode(CreatePRDRequestDTO.self)

        // ❌ Don't call library directly from controller!
        let orchestrator = PRDOrchestrator(...)
        let result = try await orchestrator.generatePRD(...)

        // ❌ Don't persist directly in controller!
        try await PRDDocument(...).save(on: req.db)

        return PRDResponse(...)
    }
}
```

---

## Library Import Philosophy

### Why Application Layer Can Import Library

**The library IS the business logic.** The Application layer's job is to:
1. Call the library (business logic)
2. Persist results (database)
3. Coordinate the two

**This is correct and intentional:**
```swift
// Application/UseCases/GeneratePRDUseCase.swift
import PRDGenerator    // ✅ YES!
import Orchestration   // ✅ YES!

final class GeneratePRDUseCase {
    // The use case USES the library - this is its purpose
    private let orchestrator: PRDOrchestrator
}
```

### Why Domain Layer Cannot Import Library

**Domain models are for persistence, not business logic:**
```swift
// Domain/Entities/PRDDocument.swift
❌ import PRDGenerator  // NO! Domain should be pure

final class PRDDocument: Model {
    // This is a DATABASE model, not a business entity
    // It STORES the library's PRDocument, it doesn't CONTAIN business logic
}
```

**The library's PRDocument and Vapor's PRDDocument are different:**
- `PRDGenerator.PRDocument` = Business entity (lives in library)
- `Domain.PRDDocument` = Persistence model (lives in Vapor DB)
- Mapping happens in Application/Infrastructure layers

---

## Common Violations and Fixes

### Violation #1: Domain Importing Business Logic

**Problem**:
```swift
// Domain/Ports/AIProviderPort.swift
❌ import PRDGenerator

public protocol AIProviderPort {
    func generatePRD(
        from: GeneratePRDCommand,         // Type from library
        context: ContextRequestPort?      // Type from library
    ) async throws -> PRDGenerationResult // Type from library
}
```

**Fix**: Move this "port" to Application layer or remove it entirely (just use library types directly in use cases)

```swift
// Application/UseCases/GeneratePRDUseCase.swift
✅ import PRDGenerator

final class GeneratePRDUseCase {
    private let orchestrator: PRDOrchestrator  // Use library type directly

    func execute(...) async throws -> UUID {
        let result = try await orchestrator.generatePRD(...)
        // ...
    }
}
```

---

### Violation #2: Controller Calling Library Directly

**Problem**:
```swift
// Presentation/Controllers/PRDController.swift
❌ import PRDGenerator

final class PRDController {
    func create(_ req: Request) async throws -> PRDResponse {
        let orchestrator = PRDOrchestrator(...)
        let result = try await orchestrator.generatePRD(...)
        // ...
    }
}
```

**Fix**: Introduce use case

```swift
// Presentation/Controllers/PRDController.swift
✅ import Vapor

final class PRDController {
    private let generateUseCase: GeneratePRDUseCase

    func create(_ req: Request) async throws -> PRDResponse {
        let dto = try req.content.decode(CreatePRDRequestDTO.self)
        let user = try req.auth.require(User.self)

        let command = GeneratePRDCommand(from: dto, userId: user.id)
        let id = try await generateUseCase.execute(command)

        return PRDResponse(id: id)
    }
}
```

---

### Violation #3: Use Case Importing Vapor

**Problem**:
```swift
// Application/UseCases/GeneratePRDUseCase.swift
❌ import Vapor

final class GeneratePRDUseCase {
    func execute(req: Request) async throws -> Response {
        // Use cases shouldn't know about HTTP!
    }
}
```

**Fix**: Use domain types, not HTTP types

```swift
// Application/UseCases/GeneratePRDUseCase.swift
✅ import Foundation

final class GeneratePRDUseCase {
    func execute(command: GeneratePRDCommand) async throws -> UUID {
        // Pure business coordination, no HTTP concerns
    }
}
```

---

## Enforcement

### Manual Review Checklist

When reviewing PRs, check:

```bash
# Domain should have ZERO library imports
grep -r "import PRDGenerator" Sources/Domain/
grep -r "import Orchestration" Sources/Domain/
grep -r "import ImplementationAnalysis" Sources/Domain/

# Should return no results
```

### Automated Checks (Future)

Consider adding Swift Package Manager target restrictions:

```swift
// Package.swift
.target(
    name: "Domain",
    dependencies: [
        .product(name: "Fluent", package: "fluent"),
        .product(name: "Vapor", package: "vapor"),
        // Explicitly NO library dependencies
    ]
),
.target(
    name: "Application",
    dependencies: [
        "Domain",
        .product(name: "PRDGenerator", package: "ai-prd-builder"),
        .product(name: "Orchestration", package: "ai-prd-builder"),
        // Application CAN depend on library
    ]
),
```

---

## Quick Decision Tree

**"Can I import X in layer Y?"**

```
Is Y the Domain layer?
├─ Yes → Is X from the library (PRDGenerator, Orchestration, etc.)?
│       ├─ Yes → ❌ NO! Domain should be pure
│       └─ No → Is X Foundation/Fluent/Vapor?
│               ├─ Yes → ✅ OK
│               └─ No → ❌ NO
└─ No → Is Y the Application layer?
        ├─ Yes → Is X from the library?
        │       ├─ Yes → ✅ OK! (Application USES library)
        │       └─ No → Is X from Vapor/Fluent?
        │               ├─ Yes → ❌ NO! (Keep use cases HTTP-agnostic)
        │               └─ No → ✅ Probably OK
        └─ No → Is Y the Presentation layer?
                ├─ Yes → Is X from the library?
                │       ├─ Yes → ❌ NO! (Call through use cases)
                │       └─ No → Is X from Application/Domain?
                │               ├─ Yes → ✅ OK
                │               └─ No → ❌ NO
                └─ No → Is Y Infrastructure?
                        └─ Yes → ✅ Everything allowed (except Presentation)
```

---

## Summary

### The Golden Rules

1. **Domain = Persistence Only** → Zero library imports
2. **Application = Library User** → All library imports OK
3. **Infrastructure = Adapter Layer** → Everything OK
4. **Presentation = HTTP Layer** → Calls through Application

### Remember

**The library owns the business logic.** Vapor is a gateway for web clients. This means:
- ✅ Application layer calling library = CORRECT
- ✅ Use cases are thin coordinators = CORRECT
- ✅ Most logic in library, not Vapor = CORRECT
- ❌ Domain importing library = WRONG

When in doubt: **"Is this layer's job to USE the library or BE pure?"**

---

**Document Version**: 1.0
**Last Updated**: 2025-10-03
**Status**: Enforced
