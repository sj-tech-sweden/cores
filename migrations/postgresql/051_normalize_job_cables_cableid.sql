-- Migration 051: Normalize job_cables cable ID column name
-- Ensures the cable identifier column is lowercase (cableid) to avoid the
-- case-sensitivity pitfalls of quoted identifiers in Postgres.
-- If the column was previously renamed to the quoted "cableID", rename it back.

DO $$
DECLARE
    v_pk_name TEXT;
BEGIN
    -- Rename quoted "cableID" back to unquoted lowercase cableid if present.
    -- Using lowercase avoids quoting requirements in all future queries.
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'job_cables' AND column_name = 'cableID'
    ) THEN
        ALTER TABLE job_cables RENAME COLUMN "cableID" TO cableid;
    END IF;

    -- Drop existing primary key (whatever it is named) and recreate it with
    -- the normalised lowercase column name.
    SELECT c.conname INTO v_pk_name
    FROM pg_constraint c
    JOIN pg_class t ON c.conrelid = t.oid
    JOIN pg_namespace n ON t.relnamespace = n.oid
    WHERE c.contype = 'p' AND n.nspname = 'public' AND t.relname = 'job_cables';

    IF v_pk_name IS NOT NULL THEN
        EXECUTE format('ALTER TABLE job_cables DROP CONSTRAINT %I', v_pk_name);
        ALTER TABLE job_cables ADD CONSTRAINT job_cables_pkey PRIMARY KEY (jobid, cableid);
    END IF;
END $$;
