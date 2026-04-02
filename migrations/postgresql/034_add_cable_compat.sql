-- Add compatibility column `cable_id` expected by WarehouseCore ORM
ALTER TABLE cables ADD COLUMN IF NOT EXISTS cable_id INT;

-- Backfill existing rows
UPDATE cables SET cable_id = cableid WHERE cable_id IS NULL;

-- Ensure uniqueness to avoid ambiguity
CREATE UNIQUE INDEX IF NOT EXISTS idx_cables_cable_id ON cables(cable_id);

-- Trigger to populate `cable_id` after new rows are inserted (serial `cableid` available after insert)
CREATE OR REPLACE FUNCTION set_cable_id_after_insert()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE cables
    SET cable_id = NEW.cableid
    WHERE cableid = NEW.cableid
      AND (cable_id IS NULL OR cable_id <> NEW.cableid);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_set_cable_id ON cables;
CREATE TRIGGER tr_set_cable_id
AFTER INSERT ON cables
FOR EACH ROW
EXECUTE FUNCTION set_cable_id_after_insert();

-- Safe to run multiple times; idempotent operations used above.
