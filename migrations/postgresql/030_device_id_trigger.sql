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
    abbreviation VARCHAR(50);
    pos_cat INT;
    prefix    TEXT;
    lock_key  BIGINT;
    next_counter INT;
BEGIN
    -- If productID is NULL we cannot derive a device ID prefix — fail early with a
    -- clear message rather than surfacing the confusing 'No abbreviation found for
    -- productID NULL' error that the abbreviation lookup would produce.
    IF NEW.productID IS NULL THEN
        RAISE EXCEPTION 'Cannot auto-generate deviceID: productID must not be NULL';
    END IF;

    -- 1) Get abbreviation from subcategory
    SELECT s.abbreviation
      INTO abbreviation
      FROM subcategories s
      JOIN products p ON s.subcategoryID = p.subcategoryID
     WHERE p.productID = NEW.productID
     LIMIT 1;

    -- If no abbreviation found, raise error
    IF abbreviation IS NULL THEN
        RAISE EXCEPTION 'No abbreviation found for productID %', NEW.productID;
    END IF;

    -- 2) Get pos_in_category from product
    SELECT COALESCE(p.pos_in_category, 0)
      INTO pos_cat
      FROM products p
     WHERE p.productID = NEW.productID;

    -- 3) Acquire a transaction-scoped advisory lock keyed on the device-ID
    --    prefix so that concurrent inserts for the same prefix are serialised.
    --    Two sessions that compute the same prefix will queue on this lock;
    --    each reads the counter only after the previous transaction commits,
    --    eliminating the MAX()+1 race condition.
    prefix   := abbreviation || pos_cat::TEXT;
    -- Use a 64-bit hash derived from the MD5 of the prefix so that unrelated
    -- prefixes are very unlikely to share an advisory lock key.
    -- (hashtext() is only 32-bit; this gives us the full 64-bit lock space.)
    lock_key := ('x' || left(md5(prefix), 16))::bit(64)::BIGINT;
    PERFORM pg_advisory_xact_lock(lock_key);

    -- 4) Calculate next counter (max of last 3 digits + 1)
    SELECT COALESCE(MAX(
        CASE
            WHEN RIGHT(d.deviceID, 3) ~ '^[0-9]+$'
            THEN CAST(RIGHT(d.deviceID, 3) AS INTEGER)
            ELSE 0
        END
    ), 0) + 1
      INTO next_counter
      FROM devices d
     WHERE d.deviceID LIKE prefix || '%';

    -- 5) Build deviceID (without hyphen)
    NEW.deviceID := prefix || LPAD(next_counter::TEXT, 3, '0');

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
