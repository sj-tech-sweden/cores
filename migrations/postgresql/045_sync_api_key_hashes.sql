-- Ensure api_keys.key_hash is populated from api_key_hash (and vice versa)
-- This makes inserts tolerant when code writes the hash to one of the columns.

BEGIN;

-- Add api_key_hash if missing (defensive)
ALTER TABLE IF EXISTS api_keys
  ADD COLUMN IF NOT EXISTS api_key_hash VARCHAR(255);

-- Create a function to sync hashes on insert/update
CREATE OR REPLACE FUNCTION sync_api_key_hashes()
RETURNS TRIGGER AS $$
BEGIN
  -- If key_hash is missing but api_key_hash provided, copy it over
  IF (NEW.key_hash IS NULL OR NEW.key_hash = '')
     AND (NEW.api_key_hash IS NOT NULL AND NEW.api_key_hash <> '') THEN
    NEW.key_hash := NEW.api_key_hash;
  END IF;

  -- If api_key_hash is missing but key_hash provided, copy it over
  IF (NEW.api_key_hash IS NULL OR NEW.api_key_hash = '')
     AND (NEW.key_hash IS NOT NULL AND NEW.key_hash <> '') THEN
    NEW.api_key_hash := NEW.key_hash;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Install trigger (idempotent)
DO $$
BEGIN
  IF to_regclass('public.api_keys') IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_trigger
      WHERE tgname = 'trg_sync_api_key_hashes'
        AND tgrelid = 'public.api_keys'::regclass
    ) THEN
      CREATE TRIGGER trg_sync_api_key_hashes
      BEFORE INSERT OR UPDATE ON api_keys
      FOR EACH ROW
      EXECUTE FUNCTION sync_api_key_hashes();
    END IF;
  END IF;
END;
$$;

COMMIT;
