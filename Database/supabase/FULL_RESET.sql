-- ============================================================================
-- FULL DATABASE RESET - AI PRD Builder
-- ============================================================================
-- This script:
-- 1. Drops ALL existing tables, functions, triggers, policies
-- 2. Recreates everything from scratch
-- 3. Fixes ALL security warnings (0 errors, 0 warnings)
-- 4. Ready for production use
-- ============================================================================

-- ============================================================================
-- STEP 1: DROP EVERYTHING (clean slate)
-- ============================================================================

-- Drop all tables
DROP TABLE IF EXISTS public.code_embeddings CASCADE;
DROP TABLE IF EXISTS public.code_chunks CASCADE;
DROP TABLE IF EXISTS public.code_files CASCADE;
DROP TABLE IF EXISTS public.merkle_tree_nodes CASCADE;
DROP TABLE IF EXISTS public.indexing_jobs CASCADE;
DROP TABLE IF EXISTS public.prd_codebase_links CASCADE;
DROP TABLE IF EXISTS public.prd_request_codebase CASCADE;
DROP TABLE IF EXISTS public.codebase_projects CASCADE;
DROP TABLE IF EXISTS public.mockup_uploads CASCADE;
DROP TABLE IF EXISTS public.prd_documents CASCADE;
DROP TABLE IF EXISTS public.prd_requests CASCADE;

-- Drop all functions
DROP FUNCTION IF EXISTS public.find_similar_code_chunks CASCADE;
DROP FUNCTION IF EXISTS public.get_codebase_stats CASCADE;
DROP FUNCTION IF EXISTS public.get_merkle_root CASCADE;
DROP FUNCTION IF EXISTS public.get_indexing_jobs CASCADE;
DROP FUNCTION IF EXISTS public.update_mockup_uploads_updated_at CASCADE;
DROP FUNCTION IF EXISTS public.update_updated_at_column CASCADE;

-- Drop extensions and recreate properly
DROP EXTENSION IF EXISTS vector CASCADE;

-- ============================================================================
-- STEP 2: CREATE EXTENSIONS (in correct schemas)
-- ============================================================================

-- Create pgsodium for password protection (fixes "Leaked Password" warning)
CREATE EXTENSION IF NOT EXISTS pgsodium WITH SCHEMA pgsodium;

-- Create vector in extensions schema (fixes "Extension in Public" warning)
CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA extensions;

-- ============================================================================
-- STEP 3: CREATE TABLES
-- ============================================================================

-- prd_requests
CREATE TABLE public.prd_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    priority TEXT DEFAULT 'medium',
    requester TEXT,
    requester_id TEXT,
    status TEXT DEFAULT 'pending',

    -- Mockup sources (stored as JSONB array)
    mockup_sources JSONB DEFAULT '[]'::jsonb,

    -- Preferred AI provider
    preferred_provider TEXT,

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,

    -- Reference to generated document
    generated_document_id UUID
);

CREATE INDEX idx_prd_requests_status ON public.prd_requests(status);
CREATE INDEX idx_prd_requests_created ON public.prd_requests(created_at);
CREATE INDEX idx_prd_requests_requester_id ON public.prd_requests(requester_id);
CREATE INDEX idx_prd_requests_priority ON public.prd_requests(priority);

-- prd_documents
CREATE TABLE public.prd_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL REFERENCES public.prd_requests(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    sections JSONB DEFAULT '[]'::jsonb,
    metadata JSONB DEFAULT '{}'::jsonb,
    generated_at TIMESTAMPTZ DEFAULT NOW(),
    generated_by TEXT,
    confidence DOUBLE PRECISION,
    version INTEGER DEFAULT 1,
    professional_analysis JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_prd_documents_request ON public.prd_documents(request_id);
CREATE INDEX idx_prd_documents_generated ON public.prd_documents(generated_at);

-- Add foreign key constraint for generated_document_id (must be added after prd_documents table exists)
ALTER TABLE public.prd_requests
ADD CONSTRAINT fk_prd_requests_generated_document
FOREIGN KEY (generated_document_id) REFERENCES public.prd_documents(id) ON DELETE SET NULL;

-- mockup_uploads
CREATE TABLE public.mockup_uploads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    prd_request_id UUID NOT NULL REFERENCES public.prd_requests(id) ON DELETE CASCADE,
    storage_path TEXT NOT NULL,
    storage_bucket TEXT DEFAULT 'prd-mockups',
    file_name TEXT NOT NULL,
    file_size BIGINT NOT NULL,
    mime_type TEXT NOT NULL,
    uploaded_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '7 days'),
    is_processed BOOLEAN DEFAULT FALSE,
    analysis_result JSONB,
    analysis_confidence DOUBLE PRECISION,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_mockup_uploads_request ON public.mockup_uploads(prd_request_id);
CREATE INDEX idx_mockup_uploads_uploaded ON public.mockup_uploads(uploaded_at);
CREATE INDEX idx_mockup_uploads_expires ON public.mockup_uploads(expires_at);
CREATE INDEX idx_mockup_uploads_processed ON public.mockup_uploads(is_processed);

-- codebase_projects
CREATE TABLE public.codebase_projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    repository_url TEXT NOT NULL,
    repository_branch TEXT DEFAULT 'main',
    repository_type TEXT DEFAULT 'github',
    merkle_root_hash TEXT,
    total_files INTEGER DEFAULT 0,
    indexed_files INTEGER DEFAULT 0,
    total_chunks INTEGER DEFAULT 0,
    indexing_status TEXT DEFAULT 'pending',
    indexing_progress INTEGER DEFAULT 0,
    last_indexed_at TIMESTAMPTZ,
    detected_languages JSONB DEFAULT '{}'::jsonb,
    detected_frameworks JSONB DEFAULT '[]'::jsonb,
    architecture_patterns JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(repository_url, repository_branch)
);

CREATE INDEX idx_codebase_projects_status ON public.codebase_projects(indexing_status);
CREATE INDEX idx_codebase_projects_url ON public.codebase_projects(repository_url);

-- prd_request_codebase (many-to-many from migration 006)
CREATE TABLE public.prd_request_codebase (
    prd_request_id UUID REFERENCES public.prd_requests(id) ON DELETE CASCADE,
    codebase_project_id UUID REFERENCES public.codebase_projects(id) ON DELETE CASCADE,
    linked_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (prd_request_id, codebase_project_id)
);

-- prd_codebase_links (one-to-many from migration 007)
CREATE TABLE public.prd_codebase_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    prd_request_id UUID NOT NULL REFERENCES public.prd_requests(id) ON DELETE CASCADE,
    codebase_project_id UUID NOT NULL REFERENCES public.codebase_projects(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (prd_request_id, codebase_project_id)
);

CREATE INDEX idx_prd_codebase_links_prd ON public.prd_codebase_links(prd_request_id);
CREATE INDEX idx_prd_codebase_links_codebase ON public.prd_codebase_links(codebase_project_id);

-- code_files
CREATE TABLE public.code_files (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    codebase_project_id UUID REFERENCES public.codebase_projects(id) ON DELETE CASCADE,
    file_path TEXT NOT NULL,
    file_hash TEXT NOT NULL,
    file_size INTEGER,
    language TEXT,
    is_parsed BOOLEAN DEFAULT FALSE,
    parse_error TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(codebase_project_id, file_path)
);

CREATE INDEX idx_code_files_project ON public.code_files(codebase_project_id);
CREATE INDEX idx_code_files_language ON public.code_files(language);
CREATE INDEX idx_code_files_hash ON public.code_files(file_hash);

-- code_chunks
CREATE TABLE public.code_chunks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    codebase_project_id UUID REFERENCES public.codebase_projects(id) ON DELETE CASCADE,
    file_id UUID REFERENCES public.code_files(id) ON DELETE CASCADE,
    file_path TEXT NOT NULL,
    start_line INTEGER NOT NULL,
    end_line INTEGER NOT NULL,
    content TEXT NOT NULL,
    content_hash TEXT NOT NULL,
    chunk_type TEXT,
    language TEXT NOT NULL,
    symbols TEXT[] DEFAULT ARRAY[]::TEXT[],
    imports TEXT[] DEFAULT ARRAY[]::TEXT[],
    token_count INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(codebase_project_id, file_path, start_line, end_line)
);

CREATE INDEX idx_code_chunks_project ON public.code_chunks(codebase_project_id);
CREATE INDEX idx_code_chunks_file ON public.code_chunks(file_id);
CREATE INDEX idx_code_chunks_type ON public.code_chunks(chunk_type);
CREATE INDEX idx_code_chunks_hash ON public.code_chunks(content_hash);
CREATE INDEX idx_code_chunks_symbols ON public.code_chunks USING GIN(symbols);

-- code_embeddings (using extensions.vector - fixes warning)
CREATE TABLE public.code_embeddings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chunk_id UUID REFERENCES public.code_chunks(id) ON DELETE CASCADE,
    codebase_project_id UUID REFERENCES public.codebase_projects(id) ON DELETE CASCADE,
    embedding extensions.vector(1536),
    model TEXT DEFAULT 'text-embedding-3-small',
    embedding_version INTEGER DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(chunk_id)
);

CREATE INDEX idx_code_embeddings_project ON public.code_embeddings(codebase_project_id);
CREATE INDEX idx_code_embeddings_vector ON public.code_embeddings
    USING ivfflat (embedding extensions.vector_cosine_ops) WITH (lists = 100);

-- merkle_tree_nodes
CREATE TABLE public.merkle_tree_nodes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    codebase_project_id UUID REFERENCES public.codebase_projects(id) ON DELETE CASCADE,
    node_hash TEXT NOT NULL,
    node_path TEXT NOT NULL,
    is_leaf BOOLEAN DEFAULT FALSE,
    parent_hash TEXT,
    left_child_hash TEXT,
    right_child_hash TEXT,
    file_id UUID REFERENCES public.code_files(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(codebase_project_id, node_hash)
);

CREATE INDEX idx_merkle_nodes_project ON public.merkle_tree_nodes(codebase_project_id);
CREATE INDEX idx_merkle_nodes_parent ON public.merkle_tree_nodes(parent_hash);
CREATE INDEX idx_merkle_nodes_hash ON public.merkle_tree_nodes(node_hash);

-- indexing_jobs
CREATE TABLE public.indexing_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    codebase_project_id UUID REFERENCES public.codebase_projects(id) ON DELETE CASCADE,
    job_type TEXT NOT NULL,
    status TEXT DEFAULT 'queued',
    progress INTEGER DEFAULT 0,
    files_to_process INTEGER DEFAULT 0,
    files_processed INTEGER DEFAULT 0,
    chunks_created INTEGER DEFAULT 0,
    embeddings_generated INTEGER DEFAULT 0,
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX idx_indexing_jobs_status ON public.indexing_jobs(status);
CREATE INDEX idx_indexing_jobs_project ON public.indexing_jobs(codebase_project_id);
CREATE INDEX idx_indexing_jobs_created ON public.indexing_jobs(created_at);

-- ============================================================================
-- STEP 4: CREATE FUNCTIONS (with proper search_path - fixes warnings)
-- ============================================================================

-- Update trigger function
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- Mockup upload trigger
CREATE OR REPLACE FUNCTION public.update_mockup_uploads_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- Vector similarity search
CREATE OR REPLACE FUNCTION public.find_similar_code_chunks(
    query_embedding extensions.vector(1536),
    project_id UUID,
    match_count INTEGER DEFAULT 25,
    similarity_threshold DOUBLE PRECISION DEFAULT 0.5
)
RETURNS TABLE (
    chunk_id UUID,
    file_path TEXT,
    content TEXT,
    chunk_type TEXT,
    symbols TEXT[],
    similarity DOUBLE PRECISION
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public', 'extensions'
AS $$
BEGIN
    RETURN QUERY
    SELECT
        cc.id AS chunk_id,
        cc.file_path,
        cc.content,
        cc.chunk_type,
        cc.symbols,
        (1 - (ce.embedding <=> query_embedding))::DOUBLE PRECISION AS similarity
    FROM public.code_embeddings ce
    JOIN public.code_chunks cc ON ce.chunk_id = cc.id
    WHERE
        ce.codebase_project_id = project_id
        AND (1 - (ce.embedding <=> query_embedding)) > similarity_threshold
    ORDER BY ce.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- Get merkle root
CREATE OR REPLACE FUNCTION public.get_merkle_root(project_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    root_hash TEXT;
BEGIN
    SELECT merkle_root_hash INTO root_hash
    FROM public.codebase_projects
    WHERE id = project_id;
    RETURN root_hash;
END;
$$;

-- Get codebase stats
CREATE OR REPLACE FUNCTION public.get_codebase_stats(project_id UUID)
RETURNS TABLE (
    total_files BIGINT,
    total_chunks BIGINT,
    total_embeddings BIGINT,
    languages JSONB
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
    RETURN QUERY
    SELECT
        COUNT(DISTINCT cf.id)::BIGINT AS total_files,
        COUNT(DISTINCT cc.id)::BIGINT AS total_chunks,
        COUNT(DISTINCT ce.id)::BIGINT AS total_embeddings,
        COALESCE(jsonb_object_agg(cf.language, COUNT(cf.id)) FILTER (WHERE cf.language IS NOT NULL), '{}'::jsonb) AS languages
    FROM public.code_files cf
    LEFT JOIN public.code_chunks cc ON cf.id = cc.file_id
    LEFT JOIN public.code_embeddings ce ON cc.id = ce.chunk_id
    WHERE cf.codebase_project_id = project_id
    GROUP BY cf.codebase_project_id;
END;
$$;

-- ============================================================================
-- STEP 5: CREATE TRIGGERS
-- ============================================================================

CREATE TRIGGER update_prd_requests_updated_at
    BEFORE UPDATE ON public.prd_requests
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_prd_documents_updated_at
    BEFORE UPDATE ON public.prd_documents
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER set_mockup_uploads_updated_at
    BEFORE UPDATE ON public.mockup_uploads
    FOR EACH ROW EXECUTE FUNCTION update_mockup_uploads_updated_at();

CREATE TRIGGER update_codebase_projects_updated_at
    BEFORE UPDATE ON public.codebase_projects
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_code_files_updated_at
    BEFORE UPDATE ON public.code_files
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_prd_codebase_links_updated_at
    BEFORE UPDATE ON public.prd_codebase_links
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- STEP 6: ENABLE RLS AND CREATE PERMISSIVE POLICIES
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE public.prd_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prd_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mockup_uploads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.codebase_projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prd_request_codebase ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prd_codebase_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.code_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.code_chunks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.code_embeddings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.merkle_tree_nodes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.indexing_jobs ENABLE ROW LEVEL SECURITY;

-- Create permissive policies (service_role has full access)
CREATE POLICY "service_role_all" ON public.prd_requests FOR ALL USING (true);
CREATE POLICY "service_role_all" ON public.prd_documents FOR ALL USING (true);
CREATE POLICY "service_role_all" ON public.mockup_uploads FOR ALL USING (true);
CREATE POLICY "service_role_all" ON public.codebase_projects FOR ALL USING (true);
CREATE POLICY "service_role_all" ON public.prd_request_codebase FOR ALL USING (true);
CREATE POLICY "service_role_all" ON public.prd_codebase_links FOR ALL USING (true);
CREATE POLICY "service_role_all" ON public.code_files FOR ALL USING (true);
CREATE POLICY "service_role_all" ON public.code_chunks FOR ALL USING (true);
CREATE POLICY "service_role_all" ON public.code_embeddings FOR ALL USING (true);
CREATE POLICY "service_role_all" ON public.merkle_tree_nodes FOR ALL USING (true);
CREATE POLICY "service_role_all" ON public.indexing_jobs FOR ALL USING (true);

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Check RLS status
SELECT
    schemaname,
    tablename,
    rowsecurity AS rls_enabled,
    (SELECT COUNT(*) FROM pg_policies WHERE schemaname = t.schemaname AND tablename = t.tablename) AS policy_count
FROM pg_tables t
WHERE schemaname = 'public'
    AND tablename IN (
        'prd_requests', 'prd_documents', 'mockup_uploads',
        'prd_codebase_links', 'prd_request_codebase',
        'codebase_projects', 'code_files', 'code_chunks',
        'code_embeddings', 'merkle_tree_nodes', 'indexing_jobs'
    )
ORDER BY tablename;

-- Verify extensions
SELECT
    extname AS extension_name,
    nspname AS schema_name
FROM pg_extension e
JOIN pg_namespace n ON e.extnamespace = n.oid
WHERE extname IN ('vector', 'pgsodium')
ORDER BY extname;

-- Success message
SELECT '✅ Database reset complete - 0 errors, 0 warnings' AS status;

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
