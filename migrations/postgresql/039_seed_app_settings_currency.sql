-- Migration: app_settings currency seed
-- Description: Seeds the default currency symbol in the shared global scope.
--              Both RentalCore and WarehouseCore read/write currency from
--              scope='global', key='app.currency' so the setting is shared
--              between services. The app_settings table already exists
--              (000_combined_init.sql).

INSERT INTO app_settings (scope, key, value, description)
VALUES ('global', 'app.currency', '{"symbol": "€"}', 'Currency symbol shared between RentalCore and WarehouseCore')
ON CONFLICT (scope, key) DO NOTHING;
