-- Testing Environment Schema
-- Creates tables in the testing schema for automated tests and CI/CD
-- Run this after supabase_schemas.sql

BEGIN;

-- Drop existing tables in testing schema
DROP TABLE IF EXISTS testing.prd_documents CASCADE;
DROP TABLE IF EXISTS testing.prd_requests CASCADE;

-- Create prd_requests table in testing schema
CREATE TABLE testing.prd_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    priority TEXT NOT NULL DEFAULT 'medium',
    status TEXT NOT NULL DEFAULT 'pending',

    -- Requester information
    requester_id TEXT NOT NULL,
    requester_name TEXT,
    requester_email TEXT,

    -- Mockup sources (stored as JSONB array)
    mockup_sources JSONB DEFAULT '[]'::jsonb,

    -- Generation options (stored as JSONB)
    generation_options JSONB DEFAULT '{}'::jsonb,

    -- Request metadata (stored as JSONB)
    metadata JSONB DEFAULT '{}'::jsonb,

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,

    -- Preferred AI provider
    preferred_provider TEXT,

    -- Constraints
    CONSTRAINT valid_priority CHECK (priority IN ('low', 'medium', 'high', 'critical')),
    CONSTRAINT valid_status CHECK (status IN ('pending', 'processing', 'completed', 'failed'))
);

-- Create prd_documents table in testing schema
CREATE TABLE testing.prd_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL REFERENCES testing.prd_requests(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    content TEXT NOT NULL,

    -- Sections (stored as JSONB array)
    sections JSONB DEFAULT '[]'::jsonb,

    -- Document metadata (stored as JSONB)
    metadata JSONB DEFAULT '{}'::jsonb,

    -- Generation information
    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    generated_by TEXT NOT NULL,
    confidence DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    version INTEGER NOT NULL DEFAULT 1,

    -- Search optimization
    search_text TEXT GENERATED ALWAYS AS (
        title || ' ' || content
    ) STORED,

    -- Tags for categorization
    tags TEXT[] DEFAULT '{}',

    -- Constraints
    CONSTRAINT valid_confidence CHECK (confidence >= 0 AND confidence <= 1),
    CONSTRAINT valid_version CHECK (version > 0),
    CONSTRAINT unique_request_document UNIQUE (request_id)
);

-- Create indexes for performance
CREATE INDEX idx_test_prd_requests_requester ON testing.prd_requests(requester_id);
CREATE INDEX idx_test_prd_requests_status ON testing.prd_requests(status);
CREATE INDEX idx_test_prd_requests_created_at ON testing.prd_requests(created_at DESC);
CREATE INDEX idx_test_prd_requests_priority ON testing.prd_requests(priority);

CREATE INDEX idx_test_prd_documents_request_id ON testing.prd_documents(request_id);
CREATE INDEX idx_test_prd_documents_generated_at ON testing.prd_documents(generated_at DESC);
CREATE INDEX idx_test_prd_documents_generated_by ON testing.prd_documents(generated_by);
CREATE INDEX idx_test_prd_documents_tags ON testing.prd_documents USING GIN(tags);
CREATE INDEX idx_test_prd_documents_search_text ON testing.prd_documents USING GIN(to_tsvector('english', search_text));

-- Create trigger to update updated_at
DROP TRIGGER IF EXISTS update_prd_requests_updated_at ON testing.prd_requests;
CREATE TRIGGER update_prd_requests_updated_at
    BEFORE UPDATE ON testing.prd_requests
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Enable Row Level Security
ALTER TABLE testing.prd_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE testing.prd_documents ENABLE ROW LEVEL SECURITY;

-- Create RLS policies (permissive for testing)
DROP POLICY IF EXISTS "Allow all operations on test prd_requests" ON testing.prd_requests;
CREATE POLICY "Allow all operations on test prd_requests"
    ON testing.prd_requests
    FOR ALL
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all operations on test prd_documents" ON testing.prd_documents;
CREATE POLICY "Allow all operations on test prd_documents"
    ON testing.prd_documents
    FOR ALL
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);

-- Grant permissions
GRANT ALL ON testing.prd_requests TO anon, authenticated;
GRANT ALL ON testing.prd_documents TO anon, authenticated;

COMMIT;

-- Verification
SELECT 'Testing schema created successfully' as status;