-- Multi-Environment Schema Setup for Supabase
-- Creates separate schemas for development, testing, and production
-- Run this in your Supabase SQL Editor: https://supabase.com/dashboard/project/cszcjthqneieleesijiq/sql

BEGIN;

-- Create schemas for different environments
CREATE SCHEMA IF NOT EXISTS development;
CREATE SCHEMA IF NOT EXISTS testing;
CREATE SCHEMA IF NOT EXISTS production;

-- Grant usage on schemas
GRANT USAGE ON SCHEMA development TO anon, authenticated;
GRANT USAGE ON SCHEMA testing TO anon, authenticated;
GRANT USAGE ON SCHEMA production TO anon, authenticated;

-- Create shared function (only needs to be in public schema)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMIT;

-- Now create tables in each environment
-- You can run the environment-specific scripts based on your needs

-- For development environment, run: Database/environments/development.sql
-- For testing environment, run: Database/environments/testing.sql
-- For production environment, run: Database/environments/production.sql