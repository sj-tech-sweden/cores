-- Migration 055: Final idempotent drop of cross-service FK constraints.
-- Ensures no FK from RentalCore tables to WarehouseCore tables (cables) remains,
-- regardless of which migration path was followed. Safe to re-run.
--
-- Note: migration 053 contains the same DROP CONSTRAINT statements.
-- Both are intentionally idempotent (DROP IF EXISTS). Migration 055 acts as the
-- authoritative final state for environments that may have applied 050 after the
-- cross-service FK was already removed, or that skipped the staged 053 migration.

BEGIN;

ALTER TABLE job_cables DROP CONSTRAINT IF EXISTS job_cables_cableid_fkey;
ALTER TABLE job_cables DROP CONSTRAINT IF EXISTS "job_cables_cableID_fkey";

COMMIT;

-- Rollback: restore the FK only if both services still share the same database.
-- ALTER TABLE job_cables ADD CONSTRAINT job_cables_cableid_fkey
--   FOREIGN KEY ("cableID") REFERENCES cables(cableid) ON DELETE CASCADE;
