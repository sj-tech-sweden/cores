-- Backfill api_keys.key_prefix and set a safe default to avoid NULL inserts
-- Idempotent: safe to run multiple times.

BEGIN;

-- Ensure column exists (no-op if present)
ALTER TABLE IF EXISTS api_keys
  ADD COLUMN IF NOT EXISTS key_prefix VARCHAR(20);

-- Backfill any NULL key_prefix values with a deterministic generated prefix
UPDATE api_keys
SET key_prefix = 'kp_' || substr(md5(coalesce(name,'') || coalesce(id::text,'')), 1, 12)
WHERE key_prefix IS NULL;

-- Set a harmless default so inserts that omit key_prefix won't fail
ALTER TABLE api_keys ALTER COLUMN key_prefix SET DEFAULT '';

-- Ensure column is NOT NULL (should succeed because we backfilled NULLs)
ALTER TABLE api_keys ALTER COLUMN key_prefix SET NOT NULL;

COMMIT;
