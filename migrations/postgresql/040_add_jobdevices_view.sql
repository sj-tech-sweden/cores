-- Migration 040: Add jobdevices compatibility view and seed missing app_settings
--
-- Context
-- -------
-- RentalCore's GORM model (JobDevice.TableName() = "job_devices") uses the
-- snake_case table created in 000_combined_init.sql.  WarehouseCore's raw SQL
-- (handlers, scan_service, device_admin_service) all reference the legacy
-- camelCase name "jobdevices" inherited from the original SQLite schema.
--
-- This migration bridges the gap by exposing "jobdevices" as an updatable
-- view that delegates reads and writes to the canonical "job_devices" table.
-- INSTEAD OF triggers handle INSERT, UPDATE, and UPDATE-by-deviceID patterns
-- so WarehouseCore's scan and admin operations work without touching source.

-- ---------------------------------------------------------------------------
-- 1. Updatable view: jobdevices → job_devices
-- ---------------------------------------------------------------------------

CREATE OR REPLACE VIEW jobdevices AS
SELECT
    jobid,
    deviceid,
    custom_price,
    package_id,
    is_package_item,
    pack_status,
    pack_ts
FROM job_devices;

-- INSERT: warehousecore scan_service inserts new job-device assignments
CREATE OR REPLACE FUNCTION jobdevices_instead_insert()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO job_devices (jobid, deviceid, custom_price, package_id, is_package_item, pack_status, pack_ts)
    VALUES (
        NEW.jobid,
        NEW.deviceid,
        NEW.custom_price,
        NEW.package_id,
        COALESCE(NEW.is_package_item, FALSE),
        COALESCE(NEW.pack_status, 'pending'),
        NEW.pack_ts
    )
    ON CONFLICT (jobid, deviceid) DO UPDATE
        SET pack_status = EXCLUDED.pack_status,
            pack_ts     = EXCLUDED.pack_ts;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_jobdevices_insert ON jobdevices;
CREATE TRIGGER tr_jobdevices_insert
    INSTEAD OF INSERT ON jobdevices
    FOR EACH ROW EXECUTE FUNCTION jobdevices_instead_insert();

-- UPDATE: warehousecore updates pack_status (and optionally deviceID rename)
CREATE OR REPLACE FUNCTION jobdevices_instead_update()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    UPDATE job_devices
    SET
        deviceid       = NEW.deviceid,
        pack_status    = NEW.pack_status,
        pack_ts        = NEW.pack_ts,
        custom_price   = NEW.custom_price,
        package_id     = NEW.package_id,
        is_package_item = NEW.is_package_item
    WHERE jobid = OLD.jobid AND deviceid = OLD.deviceid;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_jobdevices_update ON jobdevices;
CREATE TRIGGER tr_jobdevices_update
    INSTEAD OF UPDATE ON jobdevices
    FOR EACH ROW EXECUTE FUNCTION jobdevices_instead_update();

-- ---------------------------------------------------------------------------
-- 2. Seed missing warehousecore app_settings
-- ---------------------------------------------------------------------------

-- Currency symbol (queried every 15 s by GetCurrencySymbol; missing row fills
-- logs with noisy "record not found" warnings).
INSERT INTO app_settings (scope, key, value, description)
VALUES (
    'warehousecore',
    'app.currency',
    '{"symbol": "€"}',
    'Currency symbol displayed in WarehouseCore UI'
)
ON CONFLICT (scope, key) DO NOTHING;
