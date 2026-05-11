-- Migration 052: Add denormalized columns to support decoupling (idempotent)
BEGIN;

ALTER TABLE IF EXISTS jobs
  ADD COLUMN IF NOT EXISTS cable_id TEXT;

ALTER TABLE IF EXISTS jobs
  ADD COLUMN IF NOT EXISTS cable_snapshot JSONB;

DO $$
BEGIN
    IF to_regclass('public.jobs') IS NOT NULL
       AND EXISTS (
           SELECT 1 FROM information_schema.columns
           WHERE table_schema = 'public' AND table_name = 'jobs' AND column_name = 'cable_id'
       )
    THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS idx_jobs_cable_id ON jobs (cable_id)';
    END IF;
END $$;

COMMIT;

-- Down (manual):
-- ALTER TABLE jobs DROP COLUMN IF EXISTS cable_snapshot;
-- ALTER TABLE jobs DROP COLUMN IF EXISTS cable_id;
