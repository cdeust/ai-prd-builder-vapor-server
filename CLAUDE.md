# CLAUDE.md — AI PRD Builder Vapor Server Engineering Memory

> Engineering memory for AI assistants to enforce **SOLID**, **Clean Architecture**, and proper project structure in the Swift Vapor backend.

---

## 0) How to use this with Claude

You are the repository's Engineering Memory. Enforce the rules below. When asked for code or reviews:
- Apply SOLID and Clean Architecture strictly
- Preserve the Sources/ folder structure (Domain/Application/Infrastructure/Presentation)
- Refuse "quick hacks" that violate dependency rules; propose compliant alternatives
- Always output: (a) what changed, (b) why it follows the rules, (c) test impact
- If the user asks to break a rule, warn once and suggest a compliant path

---

## 1) SOLID Principles — Swift/Vapor Context

### S — Single Responsibility
**Principle:** A module/class/struct should have exactly one reason to change.
**Heuristics:** Name explains purpose in ≤ 5 words; public API ≤ 7 methods; one primary actor.
**Smells to flag:** "Utils", "Manager", "Helper" grab-bags; feature flags inside core types; mixed concerns (I/O + business).
**Swift-specific:** Avoid massive ViewControllers, bloated Services; use protocol extensions sparingly.
**Refactor moves:** Extract struct/class; introduce façade; move I/O to adapters.

### O — Open/Closed
**Principle:** Open to extension, closed to modification.
**Heuristics:** New behavior via new types or composition, not by editing stable code.
**Smells:** Switch/case on type scattered around; editing a core type every time a variant appears.
**Swift-specific:** Use protocol extensions, generics, and enum associated values effectively.
**Refactor:** Strategy pattern, protocol-oriented design, policy objects.

### L — Liskov Substitution
**Principle:** Subtypes must be usable anywhere their base type is expected.
**Heuristics:** No strengthened preconditions or weakened postconditions.
**Smells:** Protocol conformances throwing `fatalError()`; type-checking with `is` or `as?`.
**Swift-specific:** Avoid force-casts; prefer protocol composition over inheritance.
**Refactor:** Use composition; sealed protocols + capabilities; phantom types.

### I — Interface Segregation
**Principle:** Many focused protocols > one fat protocol.
**Heuristics:** Clients depend only on what they use; keep method groups cohesive.
**Smells:** "God" protocol with 15+ requirements; conformers providing empty implementations.
**Swift-specific:** Leverage protocol composition (`protocol Combined: ProtocolA, ProtocolB`).
**Refactor:** Split protocols; adapters per client; role-based ports.

### D — Dependency Inversion
**Principle:** High-level policy depends on abstractions, not concretes.
**Heuristics:** Domain/use-cases own the protocols ("ports"); infrastructure implements them ("adapters").
**Smells:** Domain importing Vapor, Fluent, or third-party SDKs directly.
**Swift-specific:** Define protocols in Domain; inject concrete implementations via initializers.
**Refactor:** Define ports in Domain; inject adapters at composition root (DIContainer).

---

## 2) Clean Architecture — Vapor Project Structure

### Current Architecture Layers

```
Sources/
├─ Domain/                    # Pure business rules (no Vapor/Fluent imports)
│  ├─ Entities/              # Core business objects
│  ├─ ValueObjects/          # Immutable value types
│  ├─ Ports/                 # Protocols for external dependencies
│  ├─ Repositories/          # Repository protocols (owned by domain)
│  └─ Errors/                # Domain-specific errors
├─ Application/              # Use cases and application services
│  ├─ UseCases/              # Business workflows
│  ├─ Services/              # Application-level orchestration
│  └─ Models/                # Application DTOs
├─ Infrastructure/           # Implementations of domain ports
│  ├─ AIProviders/           # AI provider adapters (Anthropic, OpenAI, etc.)
│  ├─ Repositories/          # Repository implementations (Supabase, MongoDB, etc.)
│  └─ Storage/               # Storage adapters
├─ Presentation/             # HTTP/WebSocket delivery layer
│  ├─ Controllers/           # Route handlers (thin, delegate to use cases)
│  ├─ DTOs/                  # Request/Response DTOs
│  └─ ...
├─ App/                      # Vapor configuration and DI setup
│  ├─ Configuration/         # Middleware, routes, database setup
│  ├─ Container/             # Dependency injection container
│  └─ Middleware/            # Custom middleware
└─ Run/                      # Application entry point
```

### Dependency Rules

**Golden Rule:** Source code dependencies point **inward**. Data flows both ways via **ports** (protocols) and **DTOs**.

1. **Domain** depends on **nothing** (pure Swift)
2. **Application** depends only on **Domain**
3. **Infrastructure** depends on **Domain** and **Application** (implements ports)
4. **Presentation** depends on **Application** (calls use cases)
5. **App** wires everything together (knows all layers)

### Ports & Adapters Naming

- **Ports (Domain/Ports/):** `AIProviderPort`, `PRDRepositoryProtocol`, `MockupStoragePort`
- **Adapters (Infrastructure/):** `AnthropicProvider`, `SupabasePRDRepository`, `SupabaseStorageClient`

### DTOs & Mappers

- Use Codable structs for DTOs
- Map at boundaries: HTTP↔DTO (Presentation), DTO↔Entity (Application), DB↔Entity (Infrastructure)
- Keep domain entities free from Codable when possible (use separate DTO types)

### Testing Strategy

- **Unit** (70–80%): Domain entities & application use cases with mocked ports
- **Contract** (10–15%): Verify adapter behavior against port contracts
- **Integration** (10–15%): Test infrastructure adapters with real dependencies
- **E2E** (thin): Critical API workflows via XCTest

### Review Checklist (must pass)

- [ ] Domain contains no Vapor, Fluent, or third-party framework imports
- [ ] Use cases depend only on Domain protocols (ports)
- [ ] New I/O behavior added as Infrastructure adapter
- [ ] DIContainer (composition root) wires all dependencies
- [ ] Controllers are thin and delegate to use cases
- [ ] Tests follow the pyramid; no database in unit tests
- [ ] Public APIs documented with docstrings

---

## 3) Vapor-Specific Conventions

### Controller Best Practices

**❌ Bad:** Business logic in controller
```swift
func create(_ req: Request) async throws -> PRDResponse {
    let data = try req.content.decode(CreatePRDRequest.self)
    // ❌ Business logic here
    let prd = PRDDocument(...)
    try await prd.save(on: req.db)
    return PRDResponse(prd)
}
```

**✅ Good:** Delegate to use case
```swift
func create(_ req: Request) async throws -> PRDResponse {
    let dto = try req.content.decode(CreatePRDRequestDTO.self)
    let useCase = try req.application.container.resolve(GeneratePRDUseCase.self)
    let result = try await useCase.execute(dto)
    return PRDResponse(from: result)
}
```

### Dependency Injection

Use `DIContainer` (App/Container/DIContainer.swift) for all dependency wiring:

```swift
// Register dependencies
container.register(AIProviderPort.self) { _ in
    AnthropicProvider(apiKey: Environment.get("ANTHROPIC_API_KEY")!)
}

// Resolve in controllers
let provider = try req.application.container.resolve(AIProviderPort.self)
```

### Error Handling

- Domain errors: `DomainError` enum in Domain/Errors/
- Map to HTTP errors in `DomainErrorMiddleware`
- Never expose internal errors to clients

---

## 4) Swift Best Practices

### Prefer Value Types

```swift
// ✅ Good: Immutable value type
struct MockupMetadata {
    let width: Int
    let height: Int
    let format: ImageFormat
}

// ❌ Avoid: Mutable reference type for simple data
class MockupMetadata {
    var width: Int
    var height: Int
}
```

### Protocol-Oriented Design

```swift
// Domain owns the protocol
protocol PRDRepositoryProtocol {
    func create(_ request: PRDRequest) async throws -> PRDDocument
    func findById(_ id: UUID) async throws -> PRDDocument?
}

// Infrastructure implements it
final class SupabasePRDRepository: PRDRepositoryProtocol {
    func create(_ request: PRDRequest) async throws -> PRDDocument { ... }
    func findById(_ id: UUID) async throws -> PRDDocument? { ... }
}
```

### Async/Await

- Use `async/await` for all I/O operations
- Avoid completion handlers in new code
- Use `AsyncSequence` for streaming operations

---

## 5) Thinking Modes

### Core Thinking Flags

- **--think**: Multi-file analysis with context awareness (4K tokens)
  - Activates deeper analysis across multiple files
  - Considers interdependencies and broader context
  - Ideal for feature implementation and moderate complexity tasks

- **--think-hard**: Deep architectural analysis (10K tokens)
  - Comprehensive system-wide analysis
  - Evaluates architectural patterns and design decisions
  - Explores multiple solution paths with trade-offs
  - Best for complex refactoring and system design

- **--ultrathink**: Critical system redesign (32K tokens)
  - Maximum depth analysis for critical decisions
  - Complete architectural exploration
  - Reserved for major system changes and critical problem-solving

### Auto-Activation Triggers

Automatically activate thinking modes when detecting:
- Multi-file dependencies → --think
- Architectural decisions → --think-hard
- System-wide changes → --ultrathink
- Complex debugging scenarios → --think-hard
- Security analysis → --ultrathink
- Performance optimization → --think-hard

---

## 6) Quick Prompts

- "Review this diff against Clean Architecture; list dependency rule violations"
- "Refactor this controller to delegate to a use case"
- "Add a port + adapter for [new provider] without touching Domain"
- "Extract this business logic from Infrastructure to Application layer"
- "Write unit tests for this use case with mocked ports"

---

## 7) Opinionated Stances

- **Do not** share Fluent models across layers; map explicitly to domain entities
- **Prefer composition** to inheritance for behavior changes
- **Keep controllers skinny**; if you need branching, that's a use-case concern
- **No "god" types named Utils/Helpers/Managers**
- **Time, randomness, I/O are injectable ports** to keep tests deterministic
- **Use property wrappers** (@Environment, @Dependency) sparingly; prefer explicit injection

---

> If any code conflicts with this file, prefer **CLAUDE.md** and open an ADR to explain exceptions.
