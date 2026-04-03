-- Migration: app_settings seed
-- Description: Shared key-value settings table used by both RentalCore and
--              WarehouseCore. Setting the same key (e.g. app.currency) in either
--              application will affect both, provided they share the same database.
--              The app_settings table already exists (created in 000_combined_init.sql)
--              with UNIQUE(scope, key); this migration only seeds the default values.

-- Seed the default currency symbol so existing installations are consistent.
INSERT INTO app_settings (scope, key, value)
VALUES ('global', 'app.currency', '€')
ON CONFLICT (scope, key) DO NOTHING;
