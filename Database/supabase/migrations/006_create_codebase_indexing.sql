-- Migration 006: Codebase Indexing and Vector Storage
-- Purpose: Store codebase metadata, code chunks, embeddings, and Merkle trees for incremental indexing

-- Enable vector extension for embeddings
CREATE EXTENSION IF NOT EXISTS vector;

-- ============================================================================
-- Table: codebase_projects
-- Purpose: Track indexed codebases (one per PRD request or shared across requests)
-- ============================================================================
CREATE TABLE codebase_projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Source information
    repository_url TEXT NOT NULL,
    repository_branch TEXT DEFAULT 'main',
    repository_type TEXT DEFAULT 'github',  -- github, gitlab, bitbucket

    -- Indexing metadata
    merkle_root_hash TEXT,  -- Root hash of current Merkle tree
    total_files INTEGER DEFAULT 0,
    indexed_files INTEGER DEFAULT 0,
    total_chunks INTEGER DEFAULT 0,

    -- Status tracking
    indexing_status TEXT DEFAULT 'pending',  -- pending, indexing, completed, failed
    indexing_progress INTEGER DEFAULT 0,  -- 0-100
    last_indexed_at TIMESTAMPTZ,

    -- Tech stack detection (JSON)
    detected_languages JSONB DEFAULT '{}',  -- {"Swift": 45, "TypeScript": 30}
    detected_frameworks JSONB DEFAULT '[]',  -- ["Vapor", "React"]
    architecture_patterns JSONB DEFAULT '[]',  -- [{"name": "Clean Architecture", "confidence": 0.85}]

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Unique constraint: one project per repo+branch
    UNIQUE(repository_url, repository_branch)
);

-- Index for quick lookups
CREATE INDEX idx_codebase_projects_status ON codebase_projects(indexing_status);
CREATE INDEX idx_codebase_projects_url ON codebase_projects(repository_url);

-- ============================================================================
-- Table: prd_request_codebase
-- Purpose: Link PRD requests to codebase projects (many-to-one)
-- ============================================================================
CREATE TABLE prd_request_codebase (
    prd_request_id UUID REFERENCES prd_requests(id) ON DELETE CASCADE,
    codebase_project_id UUID REFERENCES codebase_projects(id) ON DELETE CASCADE,
    linked_at TIMESTAMPTZ DEFAULT NOW(),

    PRIMARY KEY (prd_request_id, codebase_project_id)
);

-- ============================================================================
-- Table: code_files
-- Purpose: Store file metadata from repository tree
-- ============================================================================
CREATE TABLE code_files (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    codebase_project_id UUID REFERENCES codebase_projects(id) ON DELETE CASCADE,

    -- File information
    file_path TEXT NOT NULL,
    file_hash TEXT NOT NULL,  -- SHA-256 hash of file content
    file_size INTEGER,
    language TEXT,  -- swift, typescript, kotlin, python, etc.

    -- Parse status
    is_parsed BOOLEAN DEFAULT FALSE,
    parse_error TEXT,

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(codebase_project_id, file_path)
);

-- Indexes for efficient queries
CREATE INDEX idx_code_files_project ON code_files(codebase_project_id);
CREATE INDEX idx_code_files_language ON code_files(language);
CREATE INDEX idx_code_files_hash ON code_files(file_hash);

-- ============================================================================
-- Table: code_chunks
-- Purpose: Store parsed code chunks (functions, classes, modules)
-- ============================================================================
CREATE TABLE code_chunks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    codebase_project_id UUID REFERENCES codebase_projects(id) ON DELETE CASCADE,
    file_id UUID REFERENCES code_files(id) ON DELETE CASCADE,

    -- Chunk location
    file_path TEXT NOT NULL,
    start_line INTEGER NOT NULL,
    end_line INTEGER NOT NULL,

    -- Chunk content
    content TEXT NOT NULL,
    content_hash TEXT NOT NULL,  -- SHA-256 for deduplication

    -- Chunk metadata
    chunk_type TEXT,  -- function, class, struct, enum, module, interface, comment
    language TEXT NOT NULL,

    -- Extracted symbols (for better retrieval)
    symbols TEXT[] DEFAULT ARRAY[]::TEXT[],  -- [FunctionName, ClassName]
    imports TEXT[] DEFAULT ARRAY[]::TEXT[],  -- Dependencies

    -- Token count (for embedding)
    token_count INTEGER,

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(codebase_project_id, file_path, start_line, end_line)
);

-- Indexes for efficient retrieval
CREATE INDEX idx_code_chunks_project ON code_chunks(codebase_project_id);
CREATE INDEX idx_code_chunks_file ON code_chunks(file_id);
CREATE INDEX idx_code_chunks_type ON code_chunks(chunk_type);
CREATE INDEX idx_code_chunks_hash ON code_chunks(content_hash);
CREATE INDEX idx_code_chunks_symbols ON code_chunks USING GIN(symbols);

-- ============================================================================
-- Table: code_embeddings
-- Purpose: Store vector embeddings for semantic search
-- ============================================================================
CREATE TABLE code_embeddings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chunk_id UUID REFERENCES code_chunks(id) ON DELETE CASCADE,
    codebase_project_id UUID REFERENCES codebase_projects(id) ON DELETE CASCADE,

    -- Vector embedding (1536 dimensions for OpenAI text-embedding-3-small)
    embedding vector(1536),

    -- Embedding metadata
    model TEXT DEFAULT 'text-embedding-3-small',
    embedding_version INTEGER DEFAULT 1,

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(chunk_id)
);

-- Vector similarity search index (IVFFlat for fast approximate search)
CREATE INDEX idx_code_embeddings_vector
ON code_embeddings
USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);

-- Regular index for project filtering
CREATE INDEX idx_code_embeddings_project ON code_embeddings(codebase_project_id);

-- ============================================================================
-- Table: merkle_tree_nodes
-- Purpose: Store Merkle tree structure for incremental indexing
-- ============================================================================
CREATE TABLE merkle_tree_nodes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    codebase_project_id UUID REFERENCES codebase_projects(id) ON DELETE CASCADE,

    -- Node information
    node_hash TEXT NOT NULL,
    node_path TEXT NOT NULL,  -- File path or intermediate node identifier
    is_leaf BOOLEAN DEFAULT FALSE,

    -- Tree structure
    parent_hash TEXT,
    left_child_hash TEXT,
    right_child_hash TEXT,

    -- Leaf-specific data
    file_id UUID REFERENCES code_files(id) ON DELETE SET NULL,

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(codebase_project_id, node_hash)
);

-- Index for tree traversal
CREATE INDEX idx_merkle_nodes_project ON merkle_tree_nodes(codebase_project_id);
CREATE INDEX idx_merkle_nodes_parent ON merkle_tree_nodes(parent_hash);
CREATE INDEX idx_merkle_nodes_hash ON merkle_tree_nodes(node_hash);

-- ============================================================================
-- Table: indexing_jobs
-- Purpose: Track background indexing jobs for async processing
-- ============================================================================
CREATE TABLE indexing_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    codebase_project_id UUID REFERENCES codebase_projects(id) ON DELETE CASCADE,

    -- Job information
    job_type TEXT NOT NULL,  -- initial_index, incremental_update, re_index
    status TEXT DEFAULT 'queued',  -- queued, running, completed, failed
    progress INTEGER DEFAULT 0,  -- 0-100

    -- Job details
    files_to_process INTEGER DEFAULT 0,
    files_processed INTEGER DEFAULT 0,
    chunks_created INTEGER DEFAULT 0,
    embeddings_generated INTEGER DEFAULT 0,

    -- Error tracking
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,

    -- Timing
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),

    -- Job metadata (JSON)
    metadata JSONB DEFAULT '{}'
);

-- Indexes for job queue processing
CREATE INDEX idx_indexing_jobs_status ON indexing_jobs(status);
CREATE INDEX idx_indexing_jobs_project ON indexing_jobs(codebase_project_id);
CREATE INDEX idx_indexing_jobs_created ON indexing_jobs(created_at);

-- ============================================================================
-- Table: github_credentials (for OAuth)
-- Purpose: Securely store GitHub OAuth tokens (encrypted)
-- ============================================================================
CREATE TABLE github_credentials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,  -- Link to user (not defined in this schema)

    -- Encrypted tokens (AES-256)
    access_token BYTEA NOT NULL,
    refresh_token BYTEA NOT NULL,

    -- Token metadata
    expires_at TIMESTAMPTZ NOT NULL,
    scopes TEXT[] DEFAULT ARRAY['repo']::TEXT[],

    -- GitHub App installation
    installation_id TEXT,

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(user_id)
);

CREATE INDEX idx_github_credentials_user ON github_credentials(user_id);
CREATE INDEX idx_github_credentials_expires ON github_credentials(expires_at);

-- ============================================================================
-- Table: github_auth_events
-- Purpose: Audit log for GitHub authentication events
-- ============================================================================
CREATE TABLE github_auth_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,

    -- Event information
    event_type TEXT NOT NULL,  -- authorized, refreshed, revoked, failed
    event_details JSONB DEFAULT '{}',

    -- Request metadata
    ip_address INET,
    user_agent TEXT,

    -- Timestamp
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_github_auth_events_user ON github_auth_events(user_id);
CREATE INDEX idx_github_auth_events_type ON github_auth_events(event_type);
CREATE INDEX idx_github_auth_events_created ON github_auth_events(created_at);

-- ============================================================================
-- Functions: Vector Similarity Search
-- ============================================================================

-- Function to find similar code chunks using cosine similarity
CREATE OR REPLACE FUNCTION find_similar_code_chunks(
    query_embedding vector(1536),
    project_id UUID,
    match_count INTEGER DEFAULT 25,
    similarity_threshold FLOAT DEFAULT 0.5
)
RETURNS TABLE (
    chunk_id UUID,
    file_path TEXT,
    content TEXT,
    chunk_type TEXT,
    symbols TEXT[],
    similarity FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        cc.id AS chunk_id,
        cc.file_path,
        cc.content,
        cc.chunk_type,
        cc.symbols,
        1 - (ce.embedding <=> query_embedding) AS similarity
    FROM code_embeddings ce
    JOIN code_chunks cc ON ce.chunk_id = cc.id
    WHERE
        ce.codebase_project_id = project_id
        AND 1 - (ce.embedding <=> query_embedding) > similarity_threshold
    ORDER BY ce.embedding <=> query_embedding
    LIMIT match_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Functions: Merkle Tree Management
-- ============================================================================

-- Function to get the root hash of a project's Merkle tree
CREATE OR REPLACE FUNCTION get_merkle_root(project_id UUID)
RETURNS TEXT AS $$
DECLARE
    root_hash TEXT;
BEGIN
    SELECT merkle_root_hash INTO root_hash
    FROM codebase_projects
    WHERE id = project_id;

    RETURN root_hash;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Triggers: Update timestamps
-- ============================================================================

-- Trigger function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to tables
CREATE TRIGGER update_codebase_projects_updated_at
    BEFORE UPDATE ON codebase_projects
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_code_files_updated_at
    BEFORE UPDATE ON code_files
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_github_credentials_updated_at
    BEFORE UPDATE ON github_credentials
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- Row Level Security (RLS) Policies
-- ============================================================================

-- Enable RLS on sensitive tables
ALTER TABLE github_credentials ENABLE ROW LEVEL SECURITY;
ALTER TABLE github_auth_events ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only access their own credentials
CREATE POLICY github_credentials_isolation ON github_credentials
    FOR ALL
    USING (user_id = current_setting('app.current_user_id')::UUID);

-- Policy: Users can only access their own auth events
CREATE POLICY github_auth_events_isolation ON github_auth_events
    FOR ALL
    USING (user_id = current_setting('app.current_user_id')::UUID);

-- ============================================================================
-- Indexes for Performance
-- ============================================================================

-- Composite index for frequent queries
CREATE INDEX idx_code_chunks_project_type ON code_chunks(codebase_project_id, chunk_type);
CREATE INDEX idx_code_files_project_parsed ON code_files(codebase_project_id, is_parsed);

-- ============================================================================
-- Comments for Documentation
-- ============================================================================

COMMENT ON TABLE codebase_projects IS 'Tracks indexed codebases with Merkle tree roots and metadata';
COMMENT ON TABLE code_chunks IS 'Stores parsed code chunks with metadata for semantic search';
COMMENT ON TABLE code_embeddings IS 'Vector embeddings for code chunks (1536-dim)';
COMMENT ON TABLE merkle_tree_nodes IS 'Merkle tree structure for incremental change detection';
COMMENT ON TABLE indexing_jobs IS 'Background job queue for async codebase indexing';
COMMENT ON COLUMN code_embeddings.embedding IS 'Vector embedding (1536 dimensions, OpenAI text-embedding-3-small)';
COMMENT ON FUNCTION find_similar_code_chunks IS 'Semantic search for code chunks using cosine similarity';

-- ============================================================================
-- Sample Queries (for testing)
-- ============================================================================

-- Find similar code chunks
-- SELECT * FROM find_similar_code_chunks(
--     '[0.1, 0.2, ...]'::vector(1536),
--     '550e8400-e29b-41d4-a716-446655440000'::UUID,
--     10,
--     0.7
-- );

-- Get indexing progress
-- SELECT
--     repository_url,
--     indexing_status,
--     indexing_progress,
--     indexed_files || '/' || total_files AS files_progress,
--     total_chunks
-- FROM codebase_projects
-- WHERE id = '550e8400-e29b-41d4-a716-446655440000';

-- Get pending indexing jobs
-- SELECT * FROM indexing_jobs
-- WHERE status IN ('queued', 'running')
-- ORDER BY created_at ASC;
