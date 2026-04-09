-- Migration 042: Enforce NOT NULL on devices.condition_rating and
-- devices.usage_hours while preserving existing default semantics.
--
-- These columns were created as nullable but the Go model (models.Device) uses
-- non-nullable float64 fields, causing a runtime scan error whenever a device
-- row has NULL in either column (e.g. a device inserted with only
-- deviceID/productID/status). Backfill existing NULLs and add/keep DEFAULTs
-- so future inserts that omit the columns never produce a NULL.

BEGIN;

-- Backfill any existing NULLs before tightening the constraint.
UPDATE devices SET condition_rating = 5.0 WHERE condition_rating IS NULL;
UPDATE devices SET usage_hours = 0 WHERE usage_hours IS NULL;

ALTER TABLE devices
    ALTER COLUMN condition_rating SET DEFAULT 5.0,
    ALTER COLUMN condition_rating SET NOT NULL,
    ALTER COLUMN usage_hours SET DEFAULT 0,
    ALTER COLUMN usage_hours SET NOT NULL;

COMMIT;