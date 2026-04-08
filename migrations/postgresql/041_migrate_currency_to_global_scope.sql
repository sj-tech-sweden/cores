-- Migration 041: Migrate currency setting to shared global scope
-- Description: Both RentalCore and WarehouseCore now read/write currency from
--              scope='global' so the setting is truly shared between services.
--              This migration promotes the existing warehousecore-scoped row to
--              global (if absent), then seeds/normalizes the default if needed.
--
-- Note: `v` is the WarehouseCore compatibility column (alias for `value`) defined
--       in 000_combined_init.sql. The sync_app_settings_compat trigger only
--       backfills it when NULL, so ON CONFLICT DO UPDATE must set it explicitly.

-- 1. Promote existing warehousecore currency to global scope only when global is missing.
--    If a global value already exists, preserve it as the source of truth.
INSERT INTO app_settings (scope, key, value, v, description)
SELECT 'global', key, value, value, description
FROM app_settings
WHERE scope = 'warehousecore' AND key = 'app.currency'
ON CONFLICT (scope, key) DO NOTHING;

-- 2. Seed/normalize global currency: insert if missing, or update when the existing
--    value is not a valid JSON object containing the "symbol" key (e.g. legacy plain-text).
--    Uses a CASE expression to safely test JSON validity before casting to jsonb,
--    avoiding cast errors on non-JSON legacy values.
INSERT INTO app_settings (scope, key, value, v, description)
VALUES ('global', 'app.currency', '{"symbol": "€"}', '{"symbol": "€"}', 'Currency symbol shared between RentalCore and WarehouseCore')
ON CONFLICT (scope, key) DO UPDATE
    SET value       = EXCLUDED.value,
        v           = EXCLUDED.value,
        description = EXCLUDED.description,
        updated_at  = NOW()
WHERE app_settings.value IS NULL
   OR CASE
        WHEN app_settings.value ~ '^[[:space:]]*\{' THEN
            NOT (app_settings.value::jsonb ? 'symbol')
        ELSE TRUE
      END;
