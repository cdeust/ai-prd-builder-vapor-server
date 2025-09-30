-- Migration: Create mockup_uploads table
-- Description: Stores uploaded mockup images for PRD requests
-- Schema: public

CREATE TABLE IF NOT EXISTS public.mockup_uploads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    prd_request_id UUID NOT NULL REFERENCES public.prd_requests(id) ON DELETE CASCADE,
    storage_path TEXT NOT NULL,
    file_name TEXT NOT NULL,
    file_size BIGINT NOT NULL,
    mime_type TEXT NOT NULL,
    uploaded_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT (NOW() + INTERVAL '7 days'),
    is_processed BOOLEAN NOT NULL DEFAULT FALSE,
    analysis_result JSONB,
    analysis_confidence DOUBLE PRECISION,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Add indexes for performance
CREATE INDEX idx_mockup_uploads_prd_request_id ON public.mockup_uploads(prd_request_id);
CREATE INDEX idx_mockup_uploads_uploaded_at ON public.mockup_uploads(uploaded_at);
CREATE INDEX idx_mockup_uploads_expires_at ON public.mockup_uploads(expires_at);
CREATE INDEX idx_mockup_uploads_is_processed ON public.mockup_uploads(is_processed);

-- Add updated_at trigger
CREATE OR REPLACE FUNCTION update_mockup_uploads_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_mockup_uploads_updated_at
    BEFORE UPDATE ON public.mockup_uploads
    FOR EACH ROW
    EXECUTE FUNCTION update_mockup_uploads_updated_at();

-- Enable Row Level Security
ALTER TABLE public.mockup_uploads ENABLE ROW LEVEL SECURITY;

-- Create policies for authenticated users
CREATE POLICY "Users can view their own mockup uploads"
    ON public.mockup_uploads
    FOR SELECT
    USING (true);  -- Adjust based on your auth requirements

CREATE POLICY "Users can insert their own mockup uploads"
    ON public.mockup_uploads
    FOR INSERT
    WITH CHECK (true);  -- Adjust based on your auth requirements

CREATE POLICY "Users can update their own mockup uploads"
    ON public.mockup_uploads
    FOR UPDATE
    USING (true);  -- Adjust based on your auth requirements

CREATE POLICY "Users can delete their own mockup uploads"
    ON public.mockup_uploads
    FOR DELETE
    USING (true);  -- Adjust based on your auth requirements

-- Add comments for documentation
COMMENT ON TABLE public.mockup_uploads IS 'Stores uploaded mockup images and their AI analysis results';
COMMENT ON COLUMN public.mockup_uploads.storage_path IS 'Path to the file in Supabase Storage';
COMMENT ON COLUMN public.mockup_uploads.expires_at IS 'When the mockup should be cleaned up (default 7 days)';
COMMENT ON COLUMN public.mockup_uploads.analysis_result IS 'JSON result from AI mockup analysis';
COMMENT ON COLUMN public.mockup_uploads.analysis_confidence IS 'Confidence score of the AI analysis (0-1)';

-- Policy 1: Allow uploads to prd-mockups bucket
  CREATE POLICY "Allow authenticated uploads to prd-mockups"
  ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'prd-mockups'
  );

  -- Policy 2: Allow public reads from prd-mockups bucket
  CREATE POLICY "Allow public reads from prd-mockups"
  ON storage.objects
  FOR SELECT
  USING (bucket_id = 'prd-mockups');

  -- Policy 3: Allow updates to prd-mockups bucket
  CREATE POLICY "Allow authenticated updates to prd-mockups"
  ON storage.objects
  FOR UPDATE
  USING (bucket_id = 'prd-mockups');

  -- Policy 4: Allow deletions from prd-mockups bucket
  CREATE POLICY "Allow authenticated deletions from prd-mockups"
  ON storage.objects
  FOR DELETE
  USING (bucket_id = 'prd-mockups');
  
    -- Add storage_bucket column to mockup_uploads table
  ALTER TABLE mockup_uploads
  ADD COLUMN IF NOT EXISTS storage_bucket VARCHAR(255) NOT NULL DEFAULT 'prd-mockups';

  -- Update existing rows to have the default bucket name
  UPDATE mockup_uploads
  SET storage_bucket = 'prd-mockups'
  WHERE storage_bucket IS NULL OR storage_bucket = '';
