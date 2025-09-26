# AI PRD Builder - Vapor Server

A production-ready Vapor Swift server that exposes the complete **ai-orchestrator** system through REST API endpoints and WebSocket connections. This server provides web access to the entire Apple Intelligence-powered PRD generation system built in the Swift CLI project.

## Architecture Overview

This Vapor server acts as a **bridge** between web clients and the powerful ai-orchestrator Swift CLI system, providing:

- **🍎 Apple Intelligence Integration**: On-device Foundation Models for privacy-first PRD generation
- **🔄 Multi-Provider AI Support**: Fallback chain to Anthropic Claude, OpenAI GPT, Google Gemini
- **🎯 Complete Swift CLI Integration**: Direct access to all ai-orchestrator capabilities
- **🏛️ Clean Architecture**: Domain-driven design with SOLID principles
- **📊 Flexible Database Support**: PostgreSQL, Supabase, or MongoDB
- **⚡ Real-time Features**: WebSocket support for interactive clarifications

### System Components

```
┌─────────────────────────────────────────────────────────────┐
│                    Vapor Server (Web API)                    │
├─────────────────────────────────────────────────────────────┤
│  Presentation Layer: REST Endpoints + WebSocket            │
│  Application Layer: Use Cases + Services                   │
│  Infrastructure Layer: AI Orchestrator Integration         │
│  Domain Layer: Business Logic + Entities                   │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│              ai-orchestrator Swift CLI System               │
├─────────────────────────────────────────────────────────────┤
│  🍎 Apple Intelligence (on-device Foundation Models)       │
│  🧠 Thinking Framework (advanced reasoning)                │
│  📝 PRD Generator (complete generation system)             │
│  🎯 AI Bridge (provider orchestration)                     │
│  💡 Implementation Genius (code analysis)                  │
└─────────────────────────────────────────────────────────────┘
```

## Quick Start

### Prerequisites

- **macOS 13+** with Apple Silicon (for Apple Intelligence)
- **Xcode 15+** with Swift 5.9+
- **Database**: PostgreSQL, Supabase account, or MongoDB
- **AI API Keys**: Anthropic Claude (recommended) for fallback

### 1. Clone and Setup

```bash
cd vapor-server
cp .env.example .env
# Edit .env with your configuration
```

### 2. Configure Database

Choose your preferred database:

#### Option A: PostgreSQL (Recommended for Development)
```bash
# macOS with Homebrew
brew install postgresql
brew services start postgresql
createdb ai_prd_builder

# Update .env
DATABASE_TYPE=postgresql
DATABASE_URL=postgres://vapor:password@localhost:5432/ai_prd_builder
```

#### Option B: Supabase (Recommended for Production)
```bash
# Create project at https://supabase.com
# Update .env
DATABASE_TYPE=supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

#### Option C: MongoDB (Recommended for Document-Heavy Workloads)
```bash
# macOS with Homebrew
brew install mongodb-community
brew services start mongodb-community

# Update .env
DATABASE_TYPE=mongodb
MONGODB_CONNECTION_STRING=mongodb://localhost:27017
```

### 3. Configure AI Providers

The server uses the ai-orchestrator system which provides:
- **Apple Intelligence** (automatic, privacy-first)
- **Anthropic Claude** (fallback, high-quality)
- **OpenAI GPT** (optional, compatible)
- **Google Gemini** (optional, fast)

```bash
# Add to .env for fallback capability
ANTHROPIC_API_KEY=sk-ant-api03-your-key-here
```

### 4. Build and Run

```bash
swift build
swift run
```

The server starts at `http://localhost:8080`

## Project Structure

```
vapor-server/
├── Package.swift
├── Sources/
│   ├── Domain/                    # Core Business Logic (No Dependencies)
│   │   ├── Entities/
│   │   │   ├── PRDRequest.swift
│   │   │   ├── PRDDocument.swift
│   │   │   └── Provider.swift
│   │   ├── ValueObjects/
│   │   │   ├── MockupSource.swift
│   │   │   ├── Confidence.swift
│   │   │   └── Priority.swift
│   │   ├── Repositories/          # Protocol Definitions
│   │   │   ├── PRDRepositoryProtocol.swift
│   │   │   └── CacheRepositoryProtocol.swift
│   │   ├── Services/              # Domain Services
│   │   │   └── PRDValidationService.swift
│   │   └── Errors/
│   │       └── DomainError.swift
│   │
│   ├── Application/               # Use Cases & Application Services
│   │   ├── UseCases/
│   │   │   ├── GeneratePRDUseCase.swift
│   │   │   ├── AnalyzeRequirementsUseCase.swift
│   │   │   └── GetPRDUseCase.swift
│   │   ├── Ports/                # Interfaces for External Services
│   │   │   ├── AIProviderPort.swift
│   │   │   ├── NotificationPort.swift
│   │   │   └── StoragePort.swift
│   │   ├── Services/
│   │   │   ├── PRDApplicationService.swift
│   │   │   └── ProviderSelectionService.swift
│   │   └── DTOs/                 # Data Transfer Objects
│   │       ├── GeneratePRDCommand.swift
│   │       └── PRDResult.swift
│   │
│   ├── Infrastructure/           # External Concerns & Implementations
│   │   ├── Repositories/
│   │   │   ├── PostgresPRDRepository.swift
│   │   │   └── RedisCacheRepository.swift
│   │   ├── Providers/           # AI Provider Implementations
│   │   │   ├── AnthropicProvider.swift
│   │   │   ├── OpenAIProvider.swift
│   │   │   ├── GeminiProvider.swift
│   │   │   └── AppleIntelligenceProvider.swift
│   │   ├── Services/
│   │   │   ├── S3StorageService.swift
│   │   │   └── EmailNotificationService.swift
│   │   ├── Configuration/
│   │   │   ├── DatabaseConfig.swift
│   │   │   ├── ProvidersConfig.swift
│   │   │   └── AppConfig.swift
│   │   └── Persistence/
│   │       └── Migrations/
│   │
│   ├── Presentation/            # Web Layer
│   │   ├── Controllers/
│   │   │   ├── PRDController.swift
│   │   │   ├── HealthController.swift
│   │   │   └── ProviderController.swift
│   │   ├── Middleware/
│   │   │   ├── AuthenticationMiddleware.swift
│   │   │   ├── RateLimitMiddleware.swift
│   │   │   └── LoggingMiddleware.swift
│   │   ├── Models/              # Request/Response Models
│   │   │   ├── Requests/
│   │   │   │   ├── GeneratePRDRequest.swift
│   │   │   │   └── AnalyzeRequest.swift
│   │   │   └── Responses/
│   │   │       ├── PRDResponse.swift
│   │   │       └── ErrorResponse.swift
│   │   ├── Validators/
│   │   │   └── RequestValidator.swift
│   │   └── Mappers/            # DTO to Model Mappers
│   │       └── PRDMapper.swift
│   │
│   ├── App/                    # Application Bootstrap
│   │   ├── configure.swift    # DI Container Setup
│   │   ├── routes.swift       # Route Registration
│   │   ├── boot.swift         # App Initialization
│   │   └── DIContainer.swift  # Dependency Injection Container
│   │
│   └── Run/
│       └── main.swift
│
├── Tests/
│   ├── DomainTests/
│   ├── ApplicationTests/
│   ├── InfrastructureTests/
│   └── PresentationTests/
│
└── Resources/
    ├── Config/
    └── Views/
```

## Dependency Flow

```
Presentation → Application → Domain
     ↓              ↓           ↑
Infrastructure ←────────────────┘
```

## Key Design Patterns

1. **Repository Pattern**: Abstract data access
2. **Use Case Pattern**: Encapsulate business logic
3. **Factory Pattern**: Create AI providers
4. **Strategy Pattern**: Select providers dynamically
5. **Adapter Pattern**: Adapt external APIs to our ports
6. **Dependency Injection**: Wire dependencies
7. **Chain of Responsibility**: Provider fallback chain

## API Endpoints

- `POST /api/v1/prd/generate` - Generate PRD
- `POST /api/v1/prd/analyze` - Analyze requirements
- `GET /api/v1/prd/{id}` - Get PRD by ID
- `GET /api/v1/providers` - List available providers
- `GET /health` - Health check
- `GET /metrics` - Prometheus metrics

## Environment Variables

```env
# Database
DATABASE_URL=postgresql://user:pass@localhost:5432/prd_db
REDIS_URL=redis://localhost:6379

# AI Providers
ANTHROPIC_API_KEY=sk-...
OPENAI_API_KEY=sk-...
GEMINI_API_KEY=...

# Storage
S3_BUCKET=prd-storage
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...

# App Config
PORT=8080
ENVIRONMENT=development
LOG_LEVEL=info
RATE_LIMIT=100
```