-- Migration 051: Normalize job_cables cable ID column name
-- If job_cables was created with lowercase cableid, rename it to the
-- camelCase quoted identifier "cableID" to match legacy application queries.

DO $$
BEGIN
    -- Rename column cableid -> "cableID" if present
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'job_cables' AND column_name = 'cableid'
    ) THEN
        ALTER TABLE job_cables RENAME COLUMN cableid TO "cableID";
    END IF;

    -- Drop existing primary key if present and recreate with the new column name
    IF EXISTS (
        SELECT 1 FROM pg_constraint c
        JOIN pg_class t ON c.conrelid = t.oid
        JOIN pg_namespace n ON t.relnamespace = n.oid
        WHERE c.contype = 'p' AND n.nspname = 'public' AND t.relname = 'job_cables'
    ) THEN
        ALTER TABLE job_cables DROP CONSTRAINT IF EXISTS job_cables_pkey;
        ALTER TABLE job_cables ADD CONSTRAINT job_cables_pkey PRIMARY KEY (jobid, "cableID");
    END IF;
END $$;
