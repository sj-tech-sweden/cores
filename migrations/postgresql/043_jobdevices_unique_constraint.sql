-- Add a unique constraint on (deviceid, jobid) to the `job_devices` table.
-- This is required so that the INSERT ... ON CONFLICT (deviceid, jobid) DO UPDATE
-- query used during outtake scanning works correctly in PostgreSQL.
--
-- Note: 000_combined_init.sql already defines PRIMARY KEY (jobid, deviceid) on
-- job_devices, which enforces uniqueness on the pair but in (jobid, deviceid) order.
-- PostgreSQL's ON CONFLICT clause requires an index whose column order exactly matches
-- the conflict target, so a separate index/constraint on (deviceid, jobid) is needed
-- for ON CONFLICT (deviceid, jobid) to work as expected.
--
-- Implementation approach:
--   A single transaction acquires ACCESS EXCLUSIVE, removes duplicates, and builds
--   the unique index (non-CONCURRENTLY) before releasing the lock.  Holding the lock
--   throughout closes the window that CONCURRENTLY would leave open: between Phase 1
--   COMMIT and the CONCURRENTLY build finishing, writers could re-introduce duplicates
--   and cause the index build to fail.  For a table this small the extra lock duration
--   is negligible.
--
--   Session timeouts are set before the transaction to fail fast rather than hang:
--     – lock_timeout = 5 s  (abort if the ACCESS EXCLUSIVE lock cannot be acquired)
--     – statement_timeout = 120 s  (abort if the full transaction takes too long)
--
--   Phase 1 (inside BEGIN/COMMIT):
--     – LOCK IN ACCESS EXCLUSIVE MODE  (blocks readers/writers)
--     – DELETE duplicate rows
--     – CREATE UNIQUE INDEX (non-CONCURRENTLY; lock is already held)
--   Phase 2 (DO $$, after Phase 1's explicit BEGIN/COMMIT block):
--     – Promote the index to a named UNIQUE constraint (brief catalog lock)
--       Skip if any unique/pk constraint already covers (deviceid, jobid) in order.
--
-- All phases are idempotent: re-running this file after a partial failure is safe.

-- Set session-scoped timeouts so this migration fails fast instead of hanging.
-- lock_timeout: abort if the ACCESS EXCLUSIVE lock cannot be acquired within 5 s.
-- statement_timeout: abort if the full transaction takes longer than 2 minutes.
-- Both settings are scoped to this psql session and reset automatically on exit.
SET lock_timeout = '5s';
SET statement_timeout = '120s';

-- ─── Phase 1: Remove duplicates and build the unique index ───────────────────────
BEGIN;

-- Hold ACCESS EXCLUSIVE for the full duration of duplicate removal and index creation
-- so no concurrent writer can re-introduce a duplicate before the index is in place.
LOCK TABLE public.job_devices IN ACCESS EXCLUSIVE MODE;

DELETE FROM public.job_devices
WHERE ctid IN (
  SELECT ctid
  FROM (
    SELECT ctid,
           ROW_NUMBER() OVER (
             PARTITION BY deviceid, jobid
             ORDER BY (pack_ts IS NULL), pack_ts DESC, ctid DESC
           ) AS rn
    FROM public.job_devices
  ) ranked
  WHERE rn > 1
);

-- Create the unique index inside the same transaction (non-CONCURRENTLY is fine;
-- the lock is held so no writers are present and there is no race window).
CREATE UNIQUE INDEX IF NOT EXISTS idx_job_devices_deviceid_jobid
    ON public.job_devices(deviceid, jobid);

COMMIT;

-- ─── Phase 2: Promote the index to a named UNIQUE constraint (idempotent) ────────
-- ADD CONSTRAINT USING INDEX takes only a brief catalog lock; the expensive
-- index build was already done in Phase 1.
-- Skip if any unique constraint or primary key already covers (deviceid, jobid)
-- in that exact column order, OR if our named constraint already exists.
DO $$
DECLARE
    v_covered   boolean;
    v_idx_ready boolean;
BEGIN
    -- Check for an existing constraint (unique or pk) on (deviceid, jobid)
    SELECT EXISTS (
        SELECT 1
        FROM   pg_constraint c
        WHERE  c.contype  IN ('u', 'p')
          AND  c.conrelid = 'public.job_devices'::regclass
          AND  (
              SELECT array_agg(a.attname::text ORDER BY ck.ord)
              FROM   unnest(c.conkey::smallint[]) WITH ORDINALITY AS ck(attnum, ord)
              JOIN   pg_attribute a
                ON   a.attrelid = c.conrelid
               AND   a.attnum   = ck.attnum
          ) = ARRAY['deviceid', 'jobid']
    ) INTO v_covered;

    IF v_covered THEN
        RETURN;  -- Already covered; nothing to do
    END IF;

    -- Check that the index from Phase 1 is present and valid
    SELECT EXISTS (
        SELECT 1
        FROM   pg_class ic
        JOIN   pg_index i ON i.indexrelid = ic.oid
        WHERE  ic.relname    = 'idx_job_devices_deviceid_jobid'
          AND  i.indrelid    = 'public.job_devices'::regclass
          AND  i.indisunique = true
          AND  i.indisvalid  = true
    ) INTO v_idx_ready;

    IF v_idx_ready THEN
        ALTER TABLE public.job_devices
            ADD CONSTRAINT uq_job_devices_deviceid_jobid
            UNIQUE USING INDEX idx_job_devices_deviceid_jobid;
    END IF;
END;
$$;

