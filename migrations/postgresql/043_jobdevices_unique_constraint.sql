-- Add a unique constraint on (deviceID, jobID) to the jobdevices table.
-- This is required so that the INSERT ... ON CONFLICT (deviceID, jobID) DO UPDATE
-- query used during outtake scanning works correctly in PostgreSQL.
--
-- Note: 000_combined_init.sql already defines PRIMARY KEY (jobid, deviceid) on
-- job_devices, which enforces uniqueness on the pair but in (jobid, deviceid) order.
-- PostgreSQL's ON CONFLICT clause requires an index whose column order exactly matches
-- the conflict target, so a separate index/constraint on (deviceid, jobid) is needed
-- for ON CONFLICT (deviceid, jobid) to work as expected. This migration creates that
-- constraint and is safe to re-run (idempotent guard below).
--
-- Both steps run inside a single transaction with an explicit table lock so
-- that no concurrent INSERT/UPDATE can create a new duplicate row between the
-- DELETE and the constraint addition. The lock blocks writes briefly; on a
-- small table this is negligible. If the table is large and write availability
-- is critical, run during a maintenance window.
--
-- The idempotency guard skips constraint creation if any of the following
-- already covers (deviceid, jobid) in that column order:
--   • a named UNIQUE constraint
--   • a non-partial UNIQUE index
--   • a primary key (handles future schema changes where PK order may change)
BEGIN;

-- Lock the table for the duration of this migration to prevent concurrent
-- writes from inserting a new duplicate row between the DELETE and the
-- constraint addition. SHARE ROW EXCLUSIVE blocks INSERT, UPDATE, and DELETE
-- from other sessions while this transaction is open.
LOCK TABLE job_devices IN SHARE ROW EXCLUSIVE MODE;

-- Step 1: Remove any duplicate (deviceID, jobID) pairs that would violate the
-- constraint, keeping the row with the newest pack_ts and using ctid only as a
-- deterministic tie-breaker when pack_ts values are equal or NULL.
DELETE FROM job_devices
WHERE ctid IN (
  SELECT ctid
  FROM (
    SELECT ctid,
           ROW_NUMBER() OVER (
             PARTITION BY deviceID, jobID
             ORDER BY (pack_ts IS NULL), pack_ts DESC, ctid DESC
           ) AS rn
    FROM job_devices
  ) ranked
  WHERE rn > 1
);

-- Step 2: Add the unique constraint (idempotent: skip if any unique constraint,
-- unique index, or primary key already covers exactly (deviceID, jobID) in that
-- column order on job_devices, regardless of name).
DO $$
BEGIN
    IF NOT EXISTS (
    -- Check for a named UNIQUE constraint on exactly (deviceID, jobID) in its
    -- defined column order.
    SELECT 1
    FROM   pg_constraint c
    WHERE  c.contype  IN ('u', 'p')
      AND  c.conrelid = 'job_devices'::regclass
      AND  (
          SELECT array_agg(a.attname::text ORDER BY ck.ord)
          FROM   unnest(c.conkey::smallint[]) WITH ORDINALITY AS ck(attnum, ord)
          JOIN   pg_attribute a
            ON   a.attrelid = c.conrelid
           AND   a.attnum   = ck.attnum
        ) = ARRAY['deviceid', 'jobid']
    UNION ALL
    -- Check for a standalone non-partial UNIQUE index on exactly
    -- (deviceID, jobID) in its defined column order.
    SELECT 1
    FROM   pg_index i
    WHERE  i.indrelid    = 'job_devices'::regclass
      AND  i.indisunique = true
      AND  i.indpred IS NULL
      AND  (
        SELECT array_agg(a.attname::text ORDER BY ik.ord)
        FROM   unnest(i.indkey::smallint[]) WITH ORDINALITY AS ik(attnum, ord)
        JOIN   pg_attribute a
          ON   a.attrelid = i.indrelid
         AND   a.attnum   = ik.attnum
        WHERE  ik.attnum > 0
      ) = ARRAY['deviceid', 'jobid']
  ) THEN
    ALTER TABLE job_devices
      ADD CONSTRAINT uq_job_devices_device_job UNIQUE (deviceid, jobid);
  END IF;
END;
$$;

COMMIT;
