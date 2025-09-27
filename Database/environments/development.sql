-- Development Environment Schema
-- Creates tables in the development schema for local/dev testing
-- Run this after supabase_schemas.sql

BEGIN;

-- Drop existing tables in development schema
DROP TABLE IF EXISTS development.prd_documents CASCADE;
DROP TABLE IF EXISTS development.prd_requests CASCADE;

-- Create prd_requests table in development schema
CREATE TABLE development.prd_requests (
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

-- Create prd_documents table in development schema
CREATE TABLE development.prd_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL REFERENCES development.prd_requests(id) ON DELETE CASCADE,
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
CREATE INDEX idx_dev_prd_requests_requester ON development.prd_requests(requester_id);
CREATE INDEX idx_dev_prd_requests_status ON development.prd_requests(status);
CREATE INDEX idx_dev_prd_requests_created_at ON development.prd_requests(created_at DESC);
CREATE INDEX idx_dev_prd_requests_priority ON development.prd_requests(priority);

CREATE INDEX idx_dev_prd_documents_request_id ON development.prd_documents(request_id);
CREATE INDEX idx_dev_prd_documents_generated_at ON development.prd_documents(generated_at DESC);
CREATE INDEX idx_dev_prd_documents_generated_by ON development.prd_documents(generated_by);
CREATE INDEX idx_dev_prd_documents_tags ON development.prd_documents USING GIN(tags);
CREATE INDEX idx_dev_prd_documents_search_text ON development.prd_documents USING GIN(to_tsvector('english', search_text));

-- Create trigger to update updated_at
DROP TRIGGER IF EXISTS update_prd_requests_updated_at ON development.prd_requests;
CREATE TRIGGER update_prd_requests_updated_at
    BEFORE UPDATE ON development.prd_requests
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Enable Row Level Security
ALTER TABLE development.prd_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE development.prd_documents ENABLE ROW LEVEL SECURITY;

-- Create RLS policies (permissive for development)
DROP POLICY IF EXISTS "Allow all operations on dev prd_requests" ON development.prd_requests;
CREATE POLICY "Allow all operations on dev prd_requests"
    ON development.prd_requests
    FOR ALL
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all operations on dev prd_documents" ON development.prd_documents;
CREATE POLICY "Allow all operations on dev prd_documents"
    ON development.prd_documents
    FOR ALL
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);

-- Grant permissions
GRANT ALL ON development.prd_requests TO anon, authenticated;
GRANT ALL ON development.prd_documents TO anon, authenticated;

COMMIT;

-- Verification
SELECT 'Development schema created successfully' as status;