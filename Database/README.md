# Database Setup Guide

This project uses Supabase with separate schemas for different environments.

## Environment Schemas

- **development**: For local development
- **testing**: For automated tests and CI/CD
- **production**: For production deployment

## Setup Instructions

### 1. Create Base Schemas

Run this script first in your Supabase SQL Editor to create the schemas:

```sql
-- Run: Database/supabase_schemas.sql
```

This creates the three schemas (development, testing, production) and the shared trigger function.

### 2. Create Environment Tables

Run the environment-specific scripts based on your needs:

#### Development Environment
```sql
-- Run: Database/environments/development.sql
```

#### Testing Environment
```sql
-- Run: Database/environments/testing.sql
```

#### Production Environment
```sql
-- Run: Database/environments/production.sql
```

### 3. Configure Your Application

The server automatically selects the appropriate schema based on the Vapor environment:

- `vapor run serve --env development` → uses `development` schema
- `vapor run serve --env testing` → uses `testing` schema
- `vapor run serve --env production` → uses `production` schema

Configuration files:
- `.env.development` - Development configuration
- `.env.testing` - Testing configuration
- `.env.production` - Production configuration

## Schema Structure

Each schema contains identical tables:

### prd_requests
- `id` (UUID, primary key)
- `title`, `description`, `priority`, `status`
- `requester_id`, `requester_name`, `requester_email`
- `mockup_sources` (JSONB array)
- `generation_options` (JSONB)
- `metadata` (JSONB)
- `created_at`, `updated_at`, `completed_at`
- `preferred_provider`

### prd_documents
- `id` (UUID, primary key)
- `request_id` (foreign key to prd_requests)
- `title`, `content`
- `sections` (JSONB array)
- `metadata` (JSONB)
- `generated_at`, `generated_by`, `confidence`, `version`
- `search_text` (generated column for full-text search)
- `tags` (array)

## Benefits of Multi-Schema Approach

1. **Data Isolation**: Development, testing, and production data are completely separate
2. **Safe Testing**: Run destructive tests in testing schema without affecting other environments
3. **Single Database**: All environments use the same Supabase project, simplifying management
4. **Cost Effective**: No need for multiple Supabase projects
5. **Easy Cleanup**: Drop and recreate schemas independently

## Maintenance

### Resetting Development Data
```sql
DROP SCHEMA development CASCADE;
-- Then re-run: Database/supabase_schemas.sql and Database/environments/development.sql
```

### Resetting Testing Data
```sql
TRUNCATE testing.prd_documents, testing.prd_requests CASCADE;
```

### Backup Production Data
```bash
# Use Supabase dashboard or pg_dump with schema filter
pg_dump -h your-host -d your-db -n production > production_backup.sql
```

## Migration from Public Schema

If you previously used the public schema (from `supabase_init.sql`), you can migrate data:

```sql
-- Migrate requests from public to development
INSERT INTO development.prd_requests
SELECT * FROM public.prd_requests;

-- Migrate documents from public to development
INSERT INTO development.prd_documents
SELECT * FROM public.prd_documents;

-- After verification, drop public tables
DROP TABLE public.prd_documents CASCADE;
DROP TABLE public.prd_requests CASCADE;
```