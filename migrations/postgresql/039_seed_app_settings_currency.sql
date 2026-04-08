-- Migration: app_settings currency seed
-- Description: Seeds the default currency symbol for WarehouseCore.
--              WarehouseCore queries scope='warehousecore', key='app.currency'
--              and expects a JSON object with a "symbol" key.
--              The app_settings table already exists (000_combined_init.sql).

INSERT INTO app_settings (scope, key, value, description)
VALUES ('warehousecore', 'app.currency', '{"symbol": "€"}', 'Currency symbol displayed in WarehouseCore UI')
ON CONFLICT (scope, key) DO NOTHING;
