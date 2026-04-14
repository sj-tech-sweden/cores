-- Add api_key_hash column to api_keys for compatibility with newer code
-- Idempotent: safe to run multiple times.

BEGIN;

-- Add the column if missing
ALTER TABLE IF EXISTS api_keys
  ADD COLUMN IF NOT EXISTS api_key_hash VARCHAR(255);

-- Backfill from existing key_hash column where present
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='api_keys' AND column_name='key_hash') THEN
    UPDATE api_keys
    SET api_key_hash = key_hash
    WHERE api_key_hash IS NULL AND key_hash IS NOT NULL;
  END IF;
END;
$$;

-- Create a non-unique index on api_key_hash if it doesn't exist
DO $$
BEGIN
  IF to_regclass('public.api_keys') IS NOT NULL
     AND NOT EXISTS (
       SELECT 1 FROM pg_class c JOIN pg_namespace n ON c.relnamespace = n.oid
       WHERE n.nspname = 'public' AND c.relkind = 'i' AND c.relname = 'idx_api_keys_api_key_hash'
     ) THEN
    EXECUTE 'CREATE INDEX idx_api_keys_api_key_hash ON api_keys(api_key_hash)';
  END IF;
END;
$$;

COMMIT;
