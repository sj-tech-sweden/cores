-- Migration 053: Stage removal of cross-service foreign keys referencing TARGET_TABLE
-- Replace TARGET_TABLE with actual table name (e.g., cables) before applying.

DO $$
DECLARE
  r RECORD;
  target_table TEXT := 'TARGET_TABLE'; -- replace with actual table name, e.g. 'cables'
BEGIN
  FOR r IN
    SELECT conrelid::regclass::text AS table_name, conname
    FROM pg_constraint c
    JOIN pg_class t ON c.confrelid = t.oid
    WHERE contype = 'f' AND t.relname = target_table
  LOOP
    EXECUTE format('ALTER TABLE %s DROP CONSTRAINT IF EXISTS %I', r.table_name, r.conname);
  END LOOP;
END$$;

-- NOTE: Keep a backup of constraint names before running. Use a maintenance window.
