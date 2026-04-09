-- Migration 036: Align app_settings column names with the Go model and add
-- a UNIQUE constraint on (scope, key) to enable ON CONFLICT (scope, key)
-- upserts in UpdateAPILimit and SetSetting.
--
-- In the current bootstrap schema, app_settings uses canonical key/value
-- columns and may also expose legacy k/v compatibility columns.  The Go
-- AppSetting model uses gorm:"column:key" and gorm:"column:value", so this
-- migration keeps older databases aligned by ensuring key/value exist and
-- are backfilled from k/v when present. The k/v columns are preserved as
-- compatibility columns so that later migrations referencing them still work.
BEGIN;

-- Step 1: Ensure key exists and backfill it from legacy column k if present.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'app_settings' AND column_name = 'key'
    ) THEN
        ALTER TABLE app_settings ADD COLUMN key TEXT;
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'app_settings' AND column_name = 'k'
    ) THEN
        UPDATE app_settings
        SET key = k
        WHERE key IS NULL AND k IS NOT NULL;
    END IF;
END;
$$;

-- Step 2: Ensure value exists and backfill it from legacy column v if present.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'app_settings' AND column_name = 'value'
    ) THEN
        ALTER TABLE app_settings ADD COLUMN value TEXT;
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'app_settings' AND column_name = 'v'
    ) THEN
        UPDATE app_settings
        SET value = v
        WHERE value IS NULL AND v IS NOT NULL;
    END IF;
END;
$$;

-- Step 3: Drop legacy unique constraint (was on (scope, k); now obsolete).
ALTER TABLE app_settings DROP CONSTRAINT IF EXISTS unique_scope_key;

-- Step 4: Drop legacy single-column index on k (if present under old name).
DROP INDEX IF EXISTS idx_setting_key;

-- Step 5: Add the unique constraint on (scope, key) that ON CONFLICT requires,
-- only if no unique index covering exactly those two columns already exists
-- (the bootstrap schema already creates UNIQUE(scope, key) inline, so this
-- step is a no-op on fresh databases).
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_index i
        JOIN pg_class c ON c.oid = i.indrelid
        WHERE c.relname = 'app_settings'
          AND i.indisunique
          AND i.indnkeyatts = 2
          AND EXISTS (
              SELECT 1 FROM pg_attribute a
              WHERE a.attrelid = c.oid AND a.attnum = ANY(i.indkey) AND a.attname = 'scope'
          )
          AND EXISTS (
              SELECT 1 FROM pg_attribute a
              WHERE a.attrelid = c.oid AND a.attnum = ANY(i.indkey) AND a.attname = 'key'
          )
    ) THEN
        ALTER TABLE app_settings
            ADD CONSTRAINT uq_app_settings_scope_key UNIQUE (scope, key);
    END IF;
END;
$$;

-- Step 6: Recreate the single-column lookup index on the key column.
CREATE INDEX IF NOT EXISTS idx_app_setting_key ON app_settings (key);

COMMIT;
