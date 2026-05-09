-- ============================================================================
-- BANSCHICK TOOLSET — Database Initialization
-- ============================================================================
-- This script runs ONCE when the PostgreSQL container is first created.
--
-- CURRENT STATUS:
--   Neither QuantPipe nor StudyBuddy use this local PostgreSQL instance.
--   - QuantPipe uses Parquet files on disk + DuckDB for queries.
--   - StudyBuddy uses Supabase (external hosted Postgres + pgvector).
--
--   This instance exists for future apps. When a new app needs a local
--   database, add a block below following the template pattern.
--
-- See: Master Build Plan, Section 6.3
-- ============================================================================

-- Enable useful extensions for future apps
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── Template for Future Apps ──────────────────────────────────────────────
-- Copy this block and replace "newapp" with the application name:
--
-- CREATE DATABASE newapp_db;
-- CREATE USER newapp_user WITH PASSWORD 'CHANGE_ME_from_env';
-- GRANT ALL PRIVILEGES ON DATABASE newapp_db TO newapp_user;
--
-- \c newapp_db
-- CREATE EXTENSION IF NOT EXISTS pgcrypto;   -- if app needs encryption
-- GRANT ALL ON SCHEMA public TO newapp_user;
-- ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO newapp_user;
-- ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO newapp_user;
