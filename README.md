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
│   │   ├── Ports/                 # Protocol Definitions
│   │   │   ├── PRDRepositoryProtocol.swift
│   │   │   ├── PRDDocumentRepositoryProtocol.swift
│   │   │   └── AIProviderPort.swift
│   │   ├── Services/              # Domain Services
│   │   │   └── PRDValidationService.swift
│   │   └── Errors/
│   │       └── DomainError.swift
│   │
│   ├── Application/               # Use Cases & Application Services
│   │   ├── Services/
│   │   │   ├── PRDApplicationService.swift  # Main application service
│   │   │   ├── PRDWorkflowService.swift     # Workflow orchestration
│   │   │   ├── PRDStatusService.swift       # Status management
│   │   │   ├── PRDExportService.swift       # Export functionality
│   │   │   ├── DocumentFormatter.swift      # Document formatting
│   │   │   └── ProgressCalculator.swift     # Progress calculation
│   │   └── Models/               # Application layer DTOs
│   │       ├── GeneratePRDCommand.swift
│   │       ├── PRDGenerationResponse.swift
│   │       ├── GenerationStatus.swift
│   │       └── ExportResult.swift
│   │
│   ├── Infrastructure/           # External Concerns & Implementations
│   │   ├── Repositories/
│   │   │   ├── Vapor/           # PostgreSQL/Fluent Implementation
│   │   │   │   ├── VaporPRDRepository.swift
│   │   │   │   ├── VaporPRDDocumentRepository.swift
│   │   │   │   ├── Models/
│   │   │   │   └── Migrations/
│   │   │   ├── Supabase/        # Supabase REST API Implementation
│   │   │   │   ├── SupabasePRDRepository.swift
│   │   │   │   ├── SupabasePRDDocumentRepository.swift
│   │   │   │   └── Models/
│   │   │   ├── MongoDB/         # MongoDB Implementation
│   │   │   │   ├── MongoDBPRDRepository.swift
│   │   │   │   ├── MongoDBPRDDocumentRepository.swift
│   │   │   │   └── Models/
│   │   │   ├── InMemoryPRDRepository.swift
│   │   │   └── InMemoryPRDDocumentRepository.swift
│   │   ├── AIProviders/         # AI Provider Implementations
│   │   │   └── AIOrchestratorProvider.swift  # ai-orchestrator integration
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
│   │   │   ├── PRDGenerationController.swift  # PRD generation endpoints
│   │   │   ├── PRDManagementController.swift  # PRD management endpoints
│   │   │   ├── ProviderController.swift       # AI provider endpoints
│   │   │   └── PRDWebSocketController.swift   # WebSocket handlers
│   │   ├── Controllers/Helpers/
│   │   │   └── PRDControllerDTOMapper.swift   # DTO mapping utilities
│   │   ├── Controllers/WebSocket/
│   │   │   └── WebSocketStateHandler.swift    # WebSocket state management
│   │   ├── DTOs/                # Request/Response DTOs
│   │   │   ├── GeneratePRDRequestDTO.swift
│   │   │   ├── PRDGenerationResponseDTO.swift
│   │   │   ├── AnalyzeRequirementsRequestDTO.swift
│   │   │   ├── GenerationStatusResponseDTO.swift
│   │   │   ├── InteractiveMessage.swift
│   │   │   ├── ErrorResponseDTO.swift
│   │   │   ├── PRDDocumentDTO.swift
│   │   │   └── ProviderHealthResponseDTO.swift
│   │
│   ├── App/                    # Application Bootstrap
│   │   ├── configure.swift    # Main configuration entry point
│   │   ├── Configuration/
│   │   │   ├── ServerConfigurator.swift   # Server setup
│   │   │   ├── DatabaseConfigurator.swift # Database configuration
│   │   │   ├── RouteConfigurator.swift    # Route registration
│   │   │   ├── MiddlewareConfigurator.swift # Middleware setup
│   │   │   └── ContentConfigurator.swift  # Content configuration
│   │   ├── Container/
│   │   │   ├── DIContainer.swift          # Dependency injection
│   │   │   ├── AIProviderFactory.swift    # AI provider factory
│   │   │   ├── DatabaseRepositoryFactory.swift # Repository factory
│   │   │   └── VaporExtensions.swift      # Vapor DI extensions
│   │   ├── Middleware/
│   │   │   ├── DomainErrorMiddleware.swift # Error handling
│   │   │   ├── RouteLoggingMiddleware.swift # Request logging
│   │   │   └── TimeoutMiddleware.swift    # Request timeouts
│   │   └── Models/
│   │       └── HealthResponse.swift       # Health check response
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

1. **Clean Architecture**: Separation of concerns with Domain, Application, Infrastructure, Presentation layers
2. **SOLID Principles**: Single Responsibility with focused controllers and services
3. **Repository Pattern**: Abstract data access with multiple implementations (PostgreSQL, Supabase, MongoDB)
4. **Factory Pattern**: Create AI providers and database repositories dynamically
5. **Strategy Pattern**: Select providers based on availability and configuration
6. **Adapter Pattern**: Adapt ai-orchestrator CLI system to web API
7. **Dependency Injection**: Wire dependencies through DIContainer
8. **DTO Pattern**: Separate domain models from API models for boundary protection

## API Endpoints

### PRD Generation (PRDGenerationController)
- `POST /api/v1/prd/generate` - Generate PRD with automatic analysis
- `POST /api/v1/prd/generate/interactive` - Generate PRD with interactive clarifications
- `POST /api/v1/prd/generate/provider/:providerName` - Generate PRD with specific provider
- `POST /api/v1/prd/analyze` - Analyze requirements without generating

### PRD Management (PRDManagementController)
- `GET /api/v1/prd/:requestId/status` - Get generation status
- `GET /api/v1/prd/requests` - List all PRD requests (paginated)
- `GET /api/v1/prd/documents/:documentId/export` - Export PRD document (markdown, html, pdf, docx, json)

### AI Provider Management (ProviderController)
- `GET /api/v1/prd/providers` - List available AI providers
- `GET /api/v1/prd/providers/status` - Get provider health status

### WebSocket Real-time (PRDWebSocketController)
- `WS /api/v1/prd/ws/:requestId` - Status updates for a PRD generation
- `WS /api/v1/prd/ws/interactive/:requestId` - Interactive generation with clarifications

### Health
- `GET /health` - Server health check

See complete API documentation at `/Public/docs/api-documentation.md`

## Environment Variables

```env
# Database Configuration
DATABASE_TYPE=postgresql              # postgresql, supabase, or mongodb
DATABASE_URL=postgres://vapor:password@localhost:5432/ai_prd_builder
DATABASE_HOST=localhost               # PostgreSQL host
DATABASE_PORT=5432                    # PostgreSQL port
DATABASE_USERNAME=vapor               # PostgreSQL username
DATABASE_PASSWORD=password            # PostgreSQL password
DATABASE_NAME=ai_prd_builder          # PostgreSQL database name

# Supabase Configuration (if DATABASE_TYPE=supabase)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key

# MongoDB Configuration (if DATABASE_TYPE=mongodb)
MONGODB_CONNECTION_STRING=mongodb://localhost:27017
MONGODB_DATABASE=ai_prd_builder

# Skip Database (for testing)
SKIP_DATABASE=false                   # Set to true to skip database setup

# AI Provider Keys (ai-orchestrator system)
ANTHROPIC_API_KEY=sk-ant-api03-...    # Primary fallback provider (recommended)
OPENAI_API_KEY=sk-...                 # Optional fallback
GEMINI_API_KEY=...                    # Optional fallback

# Privacy & Provider Configuration
MAX_PRIVACY_LEVEL=onDevice            # onDevice, privateCloud, or external
PREFERRED_PROVIDER=apple              # apple, anthropic, openai, or gemini
ENABLE_CLARIFICATIONS=true            # Enable interactive clarification prompts

# Server Configuration
PORT=8080
APP_VERSION=1.0.0
DEBUG_MODE=false                      # Enable debug logging

# Optional: Storage & Notifications
S3_BUCKET=prd-storage
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
```