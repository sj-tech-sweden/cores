-- Migration 042: Enforce NOT NULL on devices.condition_rating and
-- devices.usage_hours while preserving existing default semantics.
--
-- These columns were created as nullable but the Go model (models.Device) uses
-- non-nullable float64 fields, causing a runtime scan error whenever a device
-- row has NULL in either column (e.g. a device inserted with only
-- deviceID/productID/status). Backfill existing NULLs and add/keep DEFAULTs
-- so future inserts that omit the columns never produce a NULL.
--
-- Low-lock approach to minimise impact on active deployments:
--   Step 1 – Backfill NULLs, set DEFAULTs, and add NOT VALID CHECK constraints
--            (ACCESS EXCLUSIVE for a brief metadata-only operation; no table scan).
--   Step 2 – VALIDATE the constraints in a separate transaction so the full table
--            scan runs under ShareUpdateExclusiveLock, allowing concurrent reads
--            and writes throughout.
--   Step 3 – Convert to NOT NULL (PostgreSQL reuses the validated constraint,
--            so the lock is brief and metadata-only) and drop the helper
--            constraints.

-- Step 1: backfill, set defaults, add NOT VALID constraints (no table scan).
BEGIN;

UPDATE devices SET condition_rating = 5.0 WHERE condition_rating IS NULL;
UPDATE devices SET usage_hours = 0 WHERE usage_hours IS NULL;

ALTER TABLE devices
    ALTER COLUMN condition_rating SET DEFAULT 5.0,
    ALTER COLUMN usage_hours SET DEFAULT 0,
    ADD CONSTRAINT devices_condition_rating_not_null
        CHECK (condition_rating IS NOT NULL) NOT VALID,
    ADD CONSTRAINT devices_usage_hours_not_null
        CHECK (usage_hours IS NOT NULL) NOT VALID;

COMMIT;

-- Step 2: validate constraints (ShareUpdateExclusiveLock — reads/writes allowed).
BEGIN;

ALTER TABLE devices
    VALIDATE CONSTRAINT devices_condition_rating_not_null,
    VALIDATE CONSTRAINT devices_usage_hours_not_null;

COMMIT;

-- Step 3: promote to NOT NULL (reuses validated constraint; brief lock) and
--         drop the now-redundant CHECK constraints.
BEGIN;

ALTER TABLE devices
    ALTER COLUMN condition_rating SET NOT NULL,
    ALTER COLUMN usage_hours SET NOT NULL,
    DROP CONSTRAINT devices_condition_rating_not_null,
    DROP CONSTRAINT devices_usage_hours_not_null;

COMMIT;