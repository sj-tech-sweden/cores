-- Migration 041: Migrate currency setting to shared global scope
-- Description: Both RentalCore and WarehouseCore now read/write currency from
--              scope='global' so the setting is truly shared between services.
--              This migration promotes the existing warehousecore-scoped row to
--              global (if present), then seeds a default if neither exists.

-- 1. Promote existing warehousecore currency to global scope.
INSERT INTO app_settings (scope, key, value, description)
SELECT 'global', key, value, description
FROM app_settings
WHERE scope = 'warehousecore' AND key = 'app.currency'
ON CONFLICT (scope, key) DO UPDATE
    SET value = EXCLUDED.value,
        updated_at = NOW();

-- 2. Seed default global currency if still missing (fresh installs).
INSERT INTO app_settings (scope, key, value, description)
VALUES ('global', 'app.currency', '{"symbol": "€"}', 'Currency symbol shared between RentalCore and WarehouseCore')
ON CONFLICT (scope, key) DO NOTHING;
