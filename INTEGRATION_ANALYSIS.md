# AI PRD Builder - Codebase Integration Analysis

**Date**: October 2, 2025
**Analysis Depth**: System-wide (Library → Server → Frontend)
**Status**: 🔴 **CRITICAL GAPS IDENTIFIED**

---

## Executive Summary

The codebase indexing and semantic search functionality has been **designed but not fully integrated** across the stack. While the database schema (Migration 006) and API endpoints exist, **critical implementation gaps** prevent end-to-end functionality.

**Key Finding**: **0% of codebase features are available to frontend users.**

---

## 📊 Integration Status Matrix

| Component | Schema | Library | Server API | Repository | Frontend | Status |
|-----------|--------|---------|------------|------------|----------|--------|
| **Codebase CRUD** | ✅ | ✅ | ✅ | ❌ | ❌ | 20% |
| **GitHub Indexing** | ✅ | ✅ | ✅ | ❌ | ❌ | 20% |
| **Code Chunking** | ✅ | ❌ | ❌ | ❌ | ❌ | 0% |
| **Vector Embeddings** | ✅ | ✅ (port) | ❌ | ❌ | ❌ | 0% |
| **Semantic Search** | ✅ | ✅ | ✅ | ❌ | ❌ | 20% |
| **Merkle Trees** | ✅ | ✅ | ❌ | ❌ | ❌ | 10% |
| **Background Jobs** | ✅ | ❌ | ❌ | ❌ | ❌ | 0% |
| **PRD Linking** | ✅ | ✅ | ⚠️ | ❌ | ❌ | 10% |
| **Tech Stack Detection** | ✅ | ❌ | ❌ | ❌ | ❌ | 0% |
| **GitHub OAuth** | ✅ | ❌ | ❌ | ❌ | ❌ | 0% |

**Legend**: ✅ Complete | ⚠️ Partial/Placeholder | ❌ Missing

---

## 🔍 Detailed Gap Analysis

### 1. **Database Layer** ✅ (100% Ready)

**Status**: Migration 006 is **production-ready** with:
- ✅ 10 tables (codebase_projects, code_files, code_chunks, code_embeddings, merkle_tree_nodes, indexing_jobs, prd_request_codebase, github_credentials, github_auth_events)
- ✅ Vector similarity search function (`find_similar_code_chunks`)
- ✅ Merkle tree management functions
- ✅ IVFFlat index for fast vector search (1536 dimensions)
- ✅ Row-level security (RLS) for credentials
- ✅ Comprehensive indexes and triggers

**Schema Capabilities NOT Used**:
- Code chunk parsing and storage
- Architecture pattern detection
- Tech stack detection (detected_languages, detected_frameworks)
- Background job queue (indexing_jobs table)
- GitHub OAuth token encryption
- Merkle tree incremental updates

---

### 2. **Library Layer** (ImplementationAnalysis) ⚠️ (60% Complete)

**Implemented**:
- ✅ `CodebaseProject`, `CodeFile`, `Codebase` domain models
- ✅ `MerkleTree` with build/verification logic
- ✅ `GitHubTreeParser` (AsyncHTTPClient integration) ✨ **Just Fixed**
- ✅ Use cases: `CreateCodebaseUseCase`, `GetCodebaseUseCase`, `ListCodebasesUseCase`, `AddFileToCodebaseUseCase`, `SearchCodebaseUseCase`, `LinkCodebaseToPRDUseCase`
- ✅ Protocols: `CodebaseRepositoryProtocol`, `EmbeddingGeneratorPort`, `PRDCodebaseLink`

**Missing**:
- ❌ Code parsing (functions, classes, modules extraction)
- ❌ Token counting for chunks
- ❌ Symbol extraction (function names, class names)
- ❌ Import/dependency tracking
- ❌ Architecture pattern detection logic
- ❌ Language detection utilities
- ❌ Background job processing
- ❌ Incremental indexing via Merkle tree comparison

---

### 3. **Server Layer** (Vapor) ⚠️ (30% Complete)

#### **API Endpoints** ✅ (Defined but Non-Functional)

**CodebaseController** exposes:
```
POST   /api/v1/codebases                    # Create codebase
GET    /api/v1/codebases                    # List codebases
GET    /api/v1/codebases/:id                # Get codebase
DELETE /api/v1/codebases/:id                # Delete codebase

POST   /api/v1/codebases/:id/files          # Add file
GET    /api/v1/codebases/:id/files          # List files

POST   /api/v1/codebases/:id/search         # Semantic search
POST   /api/v1/codebases/:id/link-prd       # Link to PRD
DELETE /api/v1/codebases/:id/link-prd/:prdId  # Unlink

POST   /api/v1/codebases/index-github       # Index GitHub repo ⭐
GET    /api/v1/codebases/:id/indexing-status # Get status
```

**Status**: ✅ Routes registered | ❌ **All return empty/placeholder data**

#### **Repository Implementation** ❌ (0% Implemented)

`SupabaseCodebaseRepository.swift`:
- **25 TODO stubs** - Every method returns empty data or throws "not implemented"
- No actual Supabase queries
- No database interaction
- Placeholder logger calls only

**Critical Missing Methods**:
```swift
// ALL THESE RETURN EMPTY/PLACEHOLDER DATA:
saveProject()           // ❌ Returns unmodified input
findProjectById()       // ❌ Returns nil
createCodebase()        // ❌ Returns unmodified input
getCodebase()           // ❌ Returns nil
saveFiles()             // ❌ Returns unmodified input
saveChunks()            // ❌ Returns unmodified input
saveEmbeddings()        // ❌ Returns unmodified input
searchByEmbedding()     // ❌ Returns []
saveMerkleTree()        // ❌ No-op
```

#### **Missing Infrastructure**

1. **Embedding Generator** ❌
   - No OpenAI embedding service
   - Placeholder returns `[0.0, 0.0, ...]` (1536 zeros)
   - No `text-embedding-3-small` integration

2. **Background Job Queue** ❌
   - No job processor
   - No queue infrastructure (Redis/Postgres)
   - No async indexing support
   - Controller creates jobs but nothing processes them

3. **Code Parser** ❌
   - No Swift/TypeScript/Kotlin parsers
   - No AST analysis
   - No chunk extraction

4. **GitHub OAuth** ❌
   - Schema exists, no implementation
   - No OAuth flow
   - No token encryption

---

### 4. **Frontend Layer** ❌ (0% Implemented)

**Findings**:
- ❌ **ZERO codebase-related components**
- ❌ No `CodebaseRepository` interface
- ❌ No use cases: `IndexGitHubUseCase`, `SearchCodebaseUseCase`, etc.
- ❌ No UI for:
  - GitHub repo indexing
  - Codebase search
  - PRD-codebase linking
  - Indexing progress display
  - Code snippet preview

**Existing Frontend Structure** (for PRD features only):
```
src/
├── domain/
│   ├── entities/          # PRDRequest, PRDDocument, MockupAnalysis
│   ├── repositories/      # IPRDRepository, IMockupRepository
│   └── valueObjects/
├── application/
│   └── useCases/          # GeneratePRDUseCase, UploadMockupUseCase
├── infrastructure/
│   ├── api/               # ApiClient
│   ├── repositories/      # PRDApiRepository, MockupApiRepository
│   └── websocket/         # WebSocket clients
└── presentation/
    └── components/        # PRDConfigurationForm, ChatInterface
```

**Required Frontend Additions**:
```
src/
├── domain/
│   ├── entities/
│   │   ├── Codebase.ts            # ❌ Missing
│   │   ├── CodeFile.ts            # ❌ Missing
│   │   └── SearchResult.ts        # ❌ Missing
│   └── repositories/
│       └── ICodebaseRepository.ts  # ❌ Missing
├── application/
│   └── useCases/
│       ├── IndexGitHubUseCase.ts   # ❌ Missing
│       ├── SearchCodebaseUseCase.ts # ❌ Missing
│       └── LinkCodebaseToPRDUseCase.ts # ❌ Missing
├── infrastructure/
│   └── repositories/
│       └── CodebaseApiRepository.ts # ❌ Missing
└── presentation/
    └── components/
        ├── GitHubIndexingForm.tsx   # ❌ Missing
        ├── CodebaseSearch.tsx        # ❌ Missing
        ├── IndexingProgressBar.tsx   # ❌ Missing
        └── CodeSnippetPreview.tsx    # ❌ Missing
```

---

## 🎯 Integration Roadmap

### **Phase 1: Core Infrastructure** (Foundation)

**Priority**: 🔴 **CRITICAL** - Blocks all features

#### 1.1 OpenAI Embedding Service
```swift
// Sources/Infrastructure/AIProviders/OpenAIEmbeddingService.swift
final class OpenAIEmbeddingService: EmbeddingGeneratorPort {
    func generateEmbedding(text: String) async throws -> [Float]
    func generateEmbeddings(texts: [String]) async throws -> [[Float]]
}
```

**Tasks**:
- [ ] Create `OpenAIEmbeddingService` adapter
- [ ] Integrate `text-embedding-3-small` model
- [ ] Add retry logic and rate limiting
- [ ] Register in DIContainer
- [ ] Remove `PlaceholderEmbeddingGenerator`

**Impact**: Enables semantic search, code similarity, chunk indexing

---

#### 1.2 Supabase Repository Implementation
```swift
// Implement 25 TODO methods in SupabaseCodebaseRepository.swift
```

**Critical Methods** (Priority Order):
1. [ ] `saveProject()` - Store codebase metadata
2. [ ] `findProjectById()` - Retrieve projects
3. [ ] `saveFiles()` - Batch file storage
4. [ ] `saveChunks()` - Store parsed code chunks
5. [ ] `saveEmbeddings()` - Store vectors
6. [ ] `searchByEmbedding()` - Vector similarity search
7. [ ] `saveMerkleTree()` - Store Merkle nodes
8. [ ] `findProjectByRepository()` - Deduplication
9. [ ] `linkPRDToCodebase()` - PRD associations
10. [ ] `getCodebaseForPRD()` - Retrieve linked codebases

**Tasks**:
- [ ] Implement Supabase CRUD operations
- [ ] Add vector similarity queries
- [ ] Implement Merkle tree storage/retrieval
- [ ] Add transaction support for batch operations
- [ ] Write integration tests

**Impact**: Makes ALL endpoints functional

---

#### 1.3 Code Parser Service
```swift
// Sources/Infrastructure/Parsers/
├── CodeParser.swift              # Protocol
├── SwiftCodeParser.swift         # Swift AST parsing
├── TypeScriptCodeParser.swift    # TS/JS parsing
└── UniversalCodeParser.swift     # Regex-based fallback
```

**Tasks**:
- [ ] Implement function/class extraction
- [ ] Symbol extraction (function names, class names)
- [ ] Import/dependency tracking
- [ ] Token counting (tiktoken-compatible)
- [ ] Support: Swift, TypeScript, Kotlin, Python
- [ ] Integration with `AddFileToCodebaseUseCase`

**Impact**: Enables chunking, embeddings, semantic search

---

### **Phase 2: Async Indexing** (Scalability)

**Priority**: 🟠 **HIGH** - Prevents UI blocking, enables large repos

#### 2.1 Background Job Infrastructure
```swift
// Sources/Infrastructure/Jobs/
├── JobQueue.swift              # Job queue protocol
├── PostgresJobQueue.swift      # Postgres-backed queue
├── IndexingJobProcessor.swift  # Worker process
└── JobModels.swift             # IndexingJob, JobStatus
```

**Tasks**:
- [ ] Create job queue using `indexing_jobs` table
- [ ] Implement worker process (polling or LISTEN/NOTIFY)
- [ ] Add job retry logic (exponential backoff)
- [ ] Progress tracking and status updates
- [ ] Error handling and logging
- [ ] Graceful shutdown support

**Impact**: Enables async indexing, prevents timeouts on large repos

---

#### 2.2 Incremental Indexing via Merkle Trees
```swift
// Sources/Application/Services/IncrementalIndexingService.swift
func detectChanges(oldRoot: String, newRoot: String) -> [String] // Changed file paths
func updateIndex(projectId: UUID, changedFiles: [String]) async throws
```

**Tasks**:
- [ ] Implement Merkle tree comparison
- [ ] Detect changed/added/removed files
- [ ] Update only changed chunks
- [ ] Invalidate old embeddings
- [ ] Verify tree integrity

**Impact**: Fast re-indexing (minutes vs. hours for large codebases)

---

### **Phase 3: Frontend Integration** (User-Facing)

**Priority**: 🟡 **MEDIUM** - Makes features accessible

#### 3.1 Domain Layer (TypeScript)
```typescript
// src/domain/entities/
export interface Codebase { id: string; name: string; ... }
export interface CodeFile { id: string; path: string; ... }
export interface SearchResult { file: CodeFile; similarity: number; ... }

// src/domain/repositories/
export interface ICodebaseRepository {
  indexGitHub(url: string, branch?: string, token?: string): Promise<Codebase>
  search(codebaseId: string, query: string, limit?: number): Promise<SearchResult[]>
  linkToPRD(codebaseId: string, prdId: string): Promise<void>
  getIndexingStatus(codebaseId: string): Promise<IndexingStatus>
}
```

**Tasks**:
- [ ] Create domain models
- [ ] Define repository interface
- [ ] Add validation rules

---

#### 3.2 Infrastructure Layer
```typescript
// src/infrastructure/repositories/CodebaseApiRepository.ts
export class CodebaseApiRepository implements ICodebaseRepository {
  constructor(private apiClient: ApiClient) {}

  async indexGitHub(url: string, branch?: string, token?: string): Promise<Codebase> {
    return this.apiClient.post('/api/v1/codebases/index-github', { ... })
  }

  async search(...): Promise<SearchResult[]> { ... }
}
```

**Tasks**:
- [ ] Implement API repository
- [ ] Add error handling
- [ ] WebSocket support for progress updates
- [ ] Polling fallback for status

---

#### 3.3 Application Layer
```typescript
// src/application/useCases/
export class IndexGitHubUseCase {
  execute(input: IndexGitHubInput): Promise<IndexGitHubOutput>
}

export class SearchCodebaseUseCase {
  execute(query: string, codebaseId: string): Promise<SearchResult[]>
}

export class LinkCodebaseToPRDUseCase {
  execute(codebaseId: string, prdId: string): Promise<void>
}
```

**Tasks**:
- [ ] Create use cases
- [ ] Add input validation
- [ ] Progress tracking logic

---

#### 3.4 Presentation Layer
```tsx
// src/presentation/components/
<GitHubIndexingForm
  onSubmit={handleIndexGitHub}
  onProgress={handleProgress}
/>

<CodebaseSearch
  codebaseId={id}
  onResultSelect={handleResultClick}
/>

<IndexingProgressBar
  status={status}
  progress={progress}
  filesProcessed={filesProcessed}
  totalFiles={totalFiles}
/>

<CodeSnippetPreview
  file={file}
  content={content}
  language={language}
  highlights={highlights}
/>
```

**Tasks**:
- [ ] Build GitHub indexing form (URL input, branch, token)
- [ ] Semantic search component with autocomplete
- [ ] Real-time progress display (WebSocket or polling)
- [ ] Code snippet viewer with syntax highlighting
- [ ] PRD linking UI (associate codebase with PRD request)

---

### **Phase 4: Advanced Features** (Nice-to-Have)

**Priority**: 🟢 **LOW** - Future enhancements

#### 4.1 Tech Stack Detection
```swift
// Sources/Application/Services/TechStackDetector.swift
func detectLanguages(files: [CodeFile]) -> [String: Int]
func detectFrameworks(files: [CodeFile]) -> [String]
func detectArchitecturePatterns(chunks: [CodeChunk]) -> [ArchitecturePattern]
```

**Tasks**:
- [ ] Language percentage calculation
- [ ] Framework detection (Vapor, React, SwiftUI, etc.)
- [ ] Architecture pattern recognition (Clean Architecture, MVVM, MVC)
- [ ] Update `codebase_projects` schema fields

---

#### 4.2 GitHub OAuth Integration
```swift
// Sources/Presentation/Controllers/GitHubOAuthController.swift
POST   /api/v1/auth/github/authorize
GET    /api/v1/auth/github/callback
POST   /api/v1/auth/github/refresh
DELETE /api/v1/auth/github/revoke
```

**Tasks**:
- [ ] GitHub OAuth flow (App installation or user auth)
- [ ] Token encryption (AES-256)
- [ ] Token refresh logic
- [ ] RLS enforcement
- [ ] Audit logging (`github_auth_events`)

---

#### 4.3 Smart Code Recommendations
```swift
// When generating PRD, suggest relevant code
func suggestImplementationPatterns(prdId: UUID, codebaseId: UUID) -> [CodePattern]
func findSimilarImplementations(requirement: String, codebaseId: UUID) -> [CodeSnippet]
```

**Tasks**:
- [ ] AI-powered code pattern extraction
- [ ] Similarity matching between PRD requirements and existing code
- [ ] Integration with PRD generation pipeline

---

## 📈 Effort Estimation

| Phase | Component | Effort | Priority |
|-------|-----------|--------|----------|
| **Phase 1.1** | OpenAI Embedding Service | 2-3 days | 🔴 Critical |
| **Phase 1.2** | Supabase Repository (25 methods) | 5-7 days | 🔴 Critical |
| **Phase 1.3** | Code Parser Service | 4-5 days | 🔴 Critical |
| **Phase 2.1** | Background Job Infrastructure | 3-4 days | 🟠 High |
| **Phase 2.2** | Incremental Indexing | 2-3 days | 🟠 High |
| **Phase 3.1** | Frontend Domain Layer | 1 day | 🟡 Medium |
| **Phase 3.2** | Frontend Infrastructure | 2 days | 🟡 Medium |
| **Phase 3.3** | Frontend Application Layer | 1-2 days | 🟡 Medium |
| **Phase 3.4** | Frontend Presentation Layer | 4-5 days | 🟡 Medium |
| **Phase 4.1** | Tech Stack Detection | 2-3 days | 🟢 Low |
| **Phase 4.2** | GitHub OAuth | 3-4 days | 🟢 Low |
| **Phase 4.3** | Smart Recommendations | 5-7 days | 🟢 Low |

**Total Estimated Effort**: **35-50 developer-days** (7-10 weeks for 1 developer)

---

## 🚦 Recommended Action Plan

### **Immediate (Week 1-2)**
1. ✅ Fix GitHubTreeParser (AsyncHTTPClient) - **DONE**
2. Implement OpenAI Embedding Service (Phase 1.1)
3. Start Supabase Repository implementation (Phase 1.2) - Begin with CRUD operations

### **Short-term (Week 3-4)**
4. Complete Supabase Repository (Phase 1.2)
5. Implement Code Parser (Phase 1.3)
6. Basic end-to-end test: Index small repo → Search → Verify results

### **Mid-term (Week 5-6)**
7. Background Job Infrastructure (Phase 2.1)
8. Frontend Domain + Infrastructure (Phase 3.1 + 3.2)

### **Long-term (Week 7-10)**
9. Incremental Indexing (Phase 2.2)
10. Frontend Application + Presentation (Phase 3.3 + 3.4)
11. User testing and refinement

### **Future Enhancements (Week 11+)**
12. Tech Stack Detection (Phase 4.1)
13. GitHub OAuth (Phase 4.2)
14. Smart Recommendations (Phase 4.3)

---

## 🔗 Cross-References

**Related Files**:
- Database Schema: `/Database/supabase/migrations/006_create_codebase_indexing.sql`
- Library Use Cases: `/Projects/ai-prd-builder/swift/Sources/ImplementationAnalysis/UseCases/`
- Server Controller: `Sources/Presentation/Controllers/CodebaseController.swift`
- Server Repository: `Sources/Infrastructure/Repositories/SupabaseCodebaseRepository.swift`
- Frontend Structure: `/Projects/ai-prd-builder-web/src/`

**Architecture Documentation**:
- Server CLAUDE.md: Clean Architecture, SOLID principles enforcement
- Library Domain Models: CodebaseProject, CodeFile, Codebase, MerkleTree

---

## 🎓 Key Learnings

1. **Database schema is excellent** - Comprehensive, scalable, production-ready
2. **GitHubTreeParser now works** - AsyncHTTPClient integration complete ✅
3. **Missing implementation layer** - 25 TODO stubs in repository block all functionality
4. **No frontend integration** - Zero UI components for codebase features
5. **Background jobs crucial** - Required for large repo indexing (avoid timeouts)
6. **Embeddings are bottleneck** - Placeholder service must be replaced with real OpenAI integration

---

## ✅ Next Steps

1. **Review this analysis** with stakeholders
2. **Prioritize phases** based on business value
3. **Allocate resources** (backend dev + frontend dev recommended)
4. **Start with Phase 1.1** (OpenAI Embedding Service) - Enables quick wins
5. **Track progress** using TODO markers in code

---

**Analysis Complete** ✨

For questions or clarifications, refer to this document or the linked source files.
