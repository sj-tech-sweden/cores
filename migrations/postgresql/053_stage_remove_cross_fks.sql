-- Migration 053: Remove cross-service FK constraints from job_cables to cables.
-- cables is owned by WarehouseCore; job_cables is owned by RentalCore.
-- These constraints must be dropped before the two services can use separate databases.
-- This migration is idempotent (DROP CONSTRAINT IF EXISTS).

BEGIN;

-- Drop FK that may exist in legacy environments where migration 050 was applied
-- before the cross-service FK was removed (original column name before rename)
ALTER TABLE job_cables DROP CONSTRAINT IF EXISTS job_cables_cableid_fkey;

-- Drop FK in case the column was renamed to cableID by migration 051 before this runs
ALTER TABLE job_cables DROP CONSTRAINT IF EXISTS "job_cables_cableID_fkey";

COMMIT;
