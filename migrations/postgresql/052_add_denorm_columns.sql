-- Migration 052: Add denormalized columns to support decoupling (idempotent)
BEGIN;

ALTER TABLE IF EXISTS jobs
  ADD COLUMN IF NOT EXISTS cable_id TEXT;

ALTER TABLE IF EXISTS jobs
  ADD COLUMN IF NOT EXISTS cable_snapshot JSONB;

CREATE INDEX IF NOT EXISTS idx_jobs_cable_id ON jobs (cable_id);

COMMIT;

-- Down (manual):
-- ALTER TABLE jobs DROP COLUMN IF EXISTS cable_snapshot;
-- ALTER TABLE jobs DROP COLUMN IF EXISTS cable_id;
