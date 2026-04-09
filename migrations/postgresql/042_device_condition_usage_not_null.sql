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
--   Step 1 – Set column DEFAULTs and add NOT VALID CHECK constraints first
--            (ACCESS EXCLUSIVE for a brief metadata-only operation; no table scan).
--            DEFAULTs are committed before the backfill so any concurrent inserts
--            that arrive after this point will already receive non-NULL values,
--            preventing a race where new NULLs could be inserted between the
--            backfill and VALIDATE steps.
--   Step 2 – Backfill existing NULLs in a single combined UPDATE.
--   Step 3 – VALIDATE the constraints in a separate transaction so the full table
--            scan runs under ShareUpdateExclusiveLock, allowing concurrent reads
--            and writes throughout.
--   Step 4 – Convert to NOT NULL (PostgreSQL reuses the validated constraint,
--            so the lock is brief and metadata-only) and drop the helper
--            constraints.
--
-- All steps are idempotent: a failed partial run can be retried without error.

-- Step 1: set DEFAULTs and add NOT VALID constraints (no table scan, committed
--         before the backfill so concurrent inserts already get non-NULL values).
BEGIN;

ALTER TABLE devices
    ALTER COLUMN condition_rating SET DEFAULT 5.0,
    ALTER COLUMN usage_hours SET DEFAULT 0.00;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint c
        JOIN pg_class t ON t.oid = c.conrelid
        JOIN pg_namespace n ON n.oid = t.relnamespace
        WHERE c.conname = 'devices_condition_rating_not_null'
          AND n.nspname = 'public'
          AND t.relname = 'devices'
    ) THEN
        ALTER TABLE devices
            ADD CONSTRAINT devices_condition_rating_not_null
                CHECK (condition_rating IS NOT NULL) NOT VALID;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint c
        JOIN pg_class t ON t.oid = c.conrelid
        JOIN pg_namespace n ON n.oid = t.relnamespace
        WHERE c.conname = 'devices_usage_hours_not_null'
          AND n.nspname = 'public'
          AND t.relname = 'devices'
    ) THEN
        ALTER TABLE devices
            ADD CONSTRAINT devices_usage_hours_not_null
                CHECK (usage_hours IS NOT NULL) NOT VALID;
    END IF;
END $$;

COMMIT;

-- Step 2: backfill existing NULLs in a single combined pass.
BEGIN;

UPDATE devices
SET
    condition_rating = COALESCE(condition_rating, 5.0),
    usage_hours = COALESCE(usage_hours, 0.00)
WHERE condition_rating IS NULL OR usage_hours IS NULL;

COMMIT;

-- Step 3: validate constraints (ShareUpdateExclusiveLock — reads/writes allowed).
--         Only validates each constraint when it exists and has not yet been
--         validated (convalidated = false), so this step is safe to rerun.
BEGIN;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_constraint c
        JOIN pg_class t ON t.oid = c.conrelid
        JOIN pg_namespace n ON n.oid = t.relnamespace
        WHERE c.conname = 'devices_condition_rating_not_null'
          AND n.nspname = 'public'
          AND t.relname = 'devices'
          AND c.convalidated = false
    ) THEN
        ALTER TABLE devices
            VALIDATE CONSTRAINT devices_condition_rating_not_null;
    END IF;
END $$;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_constraint c
        JOIN pg_class t ON t.oid = c.conrelid
        JOIN pg_namespace n ON n.oid = t.relnamespace
        WHERE c.conname = 'devices_usage_hours_not_null'
          AND n.nspname = 'public'
          AND t.relname = 'devices'
          AND c.convalidated = false
    ) THEN
        ALTER TABLE devices
            VALIDATE CONSTRAINT devices_usage_hours_not_null;
    END IF;
END $$;

COMMIT;

-- Step 4: promote to NOT NULL (reuses validated constraint; brief lock) and
--         drop the now-redundant CHECK constraints.
BEGIN;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'devices'
          AND column_name = 'condition_rating'
          AND is_nullable = 'YES'
    ) THEN
        ALTER TABLE devices
            ALTER COLUMN condition_rating SET NOT NULL;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'devices'
          AND column_name = 'usage_hours'
          AND is_nullable = 'YES'
    ) THEN
        ALTER TABLE devices
            ALTER COLUMN usage_hours SET NOT NULL;
    END IF;
END $$;

ALTER TABLE devices
    DROP CONSTRAINT IF EXISTS devices_condition_rating_not_null,
    DROP CONSTRAINT IF EXISTS devices_usage_hours_not_null;

COMMIT;