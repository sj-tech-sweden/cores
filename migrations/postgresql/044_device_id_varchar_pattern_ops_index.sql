-- Migration 044: Add a varchar_pattern_ops index on devices(deviceID) for
-- efficient LIKE 'prefix%' queries under non-C database collations. This index
-- is used by device ID allocation logic to find the next available device ID
-- counter.
--
-- devices.deviceid is already the PRIMARY KEY, so a plain btree index for
-- equality lookups and ORDER BY is already provided by the PK index.
-- idx_devices_deviceid_pattern (created in migration 030) was a redundant plain
-- btree index; it is dropped here to avoid unnecessary write overhead.
--
-- IMPORTANT: CREATE/DROP INDEX CONCURRENTLY cannot run inside a transaction
-- block. Apply this file outside of BEGIN/COMMIT (e.g. psql -f 044_...sql).
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_devices_deviceid_pattern_ops
    ON devices(deviceID varchar_pattern_ops);

DROP INDEX CONCURRENTLY IF EXISTS idx_devices_deviceid_pattern;
