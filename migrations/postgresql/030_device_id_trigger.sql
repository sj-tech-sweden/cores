-- Migration: 030_device_id_trigger.sql
-- Description: Create PostgreSQL trigger function for automatic device ID generation
-- Converts MySQL trigger to PostgreSQL compatible function
-- Date: 2025-12-17

-- Drop existing trigger and function if they exist
DROP TRIGGER IF EXISTS devices_before_insert ON devices;
DROP FUNCTION IF EXISTS generate_device_id();

-- Create the trigger function
CREATE OR REPLACE FUNCTION generate_device_id()
RETURNS TRIGGER AS $$
DECLARE
    abkuerzung VARCHAR(50);
    pos_cat INT;
    next_counter INT;
BEGIN
    -- 1) Get abbreviation from subcategory
    SELECT s.abbreviation
      INTO abkuerzung
      FROM subcategories s
      JOIN products p ON s.subcategoryID = p.subcategoryID
     WHERE p.productID = NEW.productID
     LIMIT 1;

    -- If no abbreviation found, raise error
    IF abkuerzung IS NULL THEN
        RAISE EXCEPTION 'No abbreviation found for productID %', NEW.productID;
    END IF;

    -- 2) Get pos_in_category from product
    SELECT COALESCE(p.pos_in_category, 0)
      INTO pos_cat
      FROM products p
     WHERE p.productID = NEW.productID;

    -- 3) Calculate next counter (max of last 3 digits + 1)
    SELECT COALESCE(MAX(
        CASE
            WHEN RIGHT(d.deviceID, 3) ~ '^[0-9]+$'
            THEN CAST(RIGHT(d.deviceID, 3) AS INTEGER)
            ELSE 0
        END
    ), 0) + 1
      INTO next_counter
      FROM devices d
     WHERE d.deviceID LIKE abkuerzung || pos_cat || '%';

    -- 4) Build deviceID (without hyphen)
    NEW.deviceID := abkuerzung || pos_cat || LPAD(next_counter::TEXT, 3, '0');

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger
CREATE TRIGGER devices_before_insert
    BEFORE INSERT ON devices
    FOR EACH ROW
    WHEN (NEW.deviceID IS NULL)
    EXECUTE FUNCTION generate_device_id();

-- Comment on the function
COMMENT ON FUNCTION generate_device_id() IS 'Auto-generates device IDs in format: {abbreviation}{pos_in_category}{counter:003d}';
