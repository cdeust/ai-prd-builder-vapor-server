-- Migration: Create PRD-Codebase Links Table
-- Description: Links PRD requests to codebase projects for context-aware generation
-- Author: System
-- Date: 2025-01-15

-- Create prd_codebase_links table
CREATE TABLE IF NOT EXISTS prd_codebase_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    prd_request_id UUID NOT NULL,
    codebase_project_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Foreign keys
    CONSTRAINT fk_prd_request FOREIGN KEY (prd_request_id)
        REFERENCES prd_requests(id) ON DELETE CASCADE,
    CONSTRAINT fk_codebase_project FOREIGN KEY (codebase_project_id)
        REFERENCES codebase_projects(id) ON DELETE CASCADE,

    -- Ensure one codebase per PRD request
    CONSTRAINT unique_prd_codebase UNIQUE (prd_request_id)
);

-- Create index for faster lookups
CREATE INDEX idx_prd_codebase_links_prd_id ON prd_codebase_links(prd_request_id);
CREATE INDEX idx_prd_codebase_links_codebase_id ON prd_codebase_links(codebase_project_id);

-- Add updated_at trigger
CREATE TRIGGER update_prd_codebase_links_updated_at
    BEFORE UPDATE ON prd_codebase_links
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Grant permissions (adjust schema/role as needed)
GRANT SELECT, INSERT, UPDATE, DELETE ON prd_codebase_links TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON prd_codebase_links TO service_role;

-- Comments
COMMENT ON TABLE prd_codebase_links IS 'Links PRD requests to codebase projects for context-aware generation';
COMMENT ON COLUMN prd_codebase_links.prd_request_id IS 'Foreign key to prd_requests table';
COMMENT ON COLUMN prd_codebase_links.codebase_project_id IS 'Foreign key to codebase_projects table';
