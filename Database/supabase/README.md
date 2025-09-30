# Supabase Database Migrations

## Running Migrations

### Option 1: Supabase Dashboard (Recommended)

1. Go to your Supabase project: https://supabase.com/dashboard/project/cszcjthqneieleesijiq
2. Navigate to the SQL Editor
3. Copy the contents of the migration file
4. Paste and execute the SQL

### Option 2: Supabase CLI

```bash
# Install Supabase CLI if not already installed
brew install supabase/tap/supabase

# Login to Supabase
supabase login

# Link to your project
supabase link --project-ref cszcjthqneieleesijiq

# Run migrations
supabase db push
```

### Option 3: Direct SQL Connection

```bash
# Using psql (get connection string from Supabase dashboard)
psql "postgresql://postgres:[YOUR-PASSWORD]@db.cszcjthqneieleesijiq.supabase.co:5432/postgres" \
  -f migrations/003_create_mockup_uploads.sql
```

## Migration Files

### 003_create_mockup_uploads.sql
Creates the `mockup_uploads` table for storing uploaded mockup images and their AI analysis results.

**Tables Created:**
- `public.mockup_uploads` - Main table for mockup upload records

**Features:**
- Foreign key to `prd_requests` table
- Automatic timestamps (created_at, updated_at)
- Expiration tracking (expires_at)
- AI analysis results storage (JSONB)
- Row Level Security enabled
- Indexed for performance

## Storage Bucket Setup

You also need to create a storage bucket for mockup files:

1. Go to Storage in your Supabase dashboard
2. Create a new bucket named `prd-mockups`
3. Set it to **private** (files accessed via signed URLs)
4. Set max file size to ~10MB

Or use SQL:

```sql
-- Create storage bucket for mockups
INSERT INTO storage.buckets (id, name, public)
VALUES ('prd-mockups', 'prd-mockups', false);

-- Set up storage policies (adjust as needed)
CREATE POLICY "Authenticated users can upload mockups"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'prd-mockups');

CREATE POLICY "Authenticated users can view their mockups"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'prd-mockups');
```

## Verification

After running the migration, verify with:

```sql
-- Check table exists
SELECT * FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name = 'mockup_uploads';

-- Check indexes
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'mockup_uploads';

-- Check RLS is enabled
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
AND tablename = 'mockup_uploads';
```