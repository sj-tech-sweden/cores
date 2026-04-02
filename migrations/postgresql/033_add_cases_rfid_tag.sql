-- Add RFID column for cases (idempotent)
-- This migration adds an optional `rfid_tag` column used by WarehouseCore.

ALTER TABLE cases
    ADD COLUMN IF NOT EXISTS rfid_tag VARCHAR(100);

-- Index for lookups by RFID tag
CREATE INDEX IF NOT EXISTS idx_cases_rfid_tag ON cases(rfid_tag);

-- No-op if column already exists; safe to run multiple times.
