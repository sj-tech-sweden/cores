-- Backfill api_keys.key_prefix and set a safe default to avoid NULL inserts
-- Idempotent: safe to run multiple times.

BEGIN;

-- Ensure column exists (no-op if present)
ALTER TABLE IF EXISTS api_keys
  ADD COLUMN IF NOT EXISTS key_prefix VARCHAR(20);

-- Create or replace a function that derives key_prefix from the key hash columns
CREATE OR REPLACE FUNCTION generate_api_key_prefix()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.key_prefix IS NULL OR NEW.key_prefix = '' THEN
    NEW.key_prefix := 'kp_' || substr(
      md5(coalesce(NEW.api_key_hash, '') || '|' || coalesce(NEW.key_hash, '') || '|' || coalesce(NEW.name, '') || '|' || coalesce(NEW.id::text, '')),
      1, 12
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
  IF to_regclass('public.api_keys') IS NOT NULL THEN
    -- Backfill any NULL key_prefix values with a deterministic generated prefix
    UPDATE api_keys
    SET key_prefix = 'kp_' || substr(md5(coalesce(name,'') || coalesce(id::text,'')), 1, 12)
    WHERE key_prefix IS NULL OR key_prefix = '';

    -- Install trigger to auto-generate key_prefix on insert/update when not provided
    IF NOT EXISTS (
      SELECT 1 FROM pg_trigger
      WHERE tgname = 'trg_generate_api_key_prefix'
        AND tgrelid = 'public.api_keys'::regclass
    ) THEN
      CREATE TRIGGER trg_generate_api_key_prefix
      BEFORE INSERT OR UPDATE ON api_keys
      FOR EACH ROW
      EXECUTE FUNCTION generate_api_key_prefix();
    END IF;

    -- Ensure column is NOT NULL (should succeed because we backfilled NULLs)
    ALTER TABLE api_keys ALTER COLUMN key_prefix SET NOT NULL;
  END IF;
END $$;

COMMIT;
