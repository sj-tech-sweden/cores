-- Migration 055: Final drop of cross-service FK constraints (explicit)
BEGIN;

-- Example: ALTER TABLE devices DROP CONSTRAINT IF EXISTS devices_cable_id_fkey;
-- Replace with actual constraint names or use the staged discovery output.

COMMIT;

-- Rollback requires original constraint DDL (keep backup before applying).
