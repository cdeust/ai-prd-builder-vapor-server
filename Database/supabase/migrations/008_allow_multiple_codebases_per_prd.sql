-- Migration: Allow Multiple Codebases Per PRD
-- Description: Remove unique constraint to allow linking multiple codebases to a single PRD
-- Author: System
-- Date: 2025-01-15

-- Drop the unique constraint that limits one codebase per PRD
ALTER TABLE prd_codebase_links
    DROP CONSTRAINT IF EXISTS unique_prd_codebase;

-- Add a composite unique constraint instead to prevent duplicate links
-- (same PRD + same codebase combination)
ALTER TABLE prd_codebase_links
    ADD CONSTRAINT unique_prd_codebase_pair
    UNIQUE (prd_request_id, codebase_project_id);

-- Comments
COMMENT ON CONSTRAINT unique_prd_codebase_pair ON prd_codebase_links IS
    'Prevents duplicate links between same PRD and codebase, but allows multiple codebases per PRD';
