-- Migration 054: Backfill denormalized columns from authoritative service.
-- NOTE: Postgres cannot reliably call external HTTP APIs in all installations.
-- Recommended approach: run an external one-off script (Go/Python) that:
-- 1) Queries jobs needing backfill
-- 2) Calls WarehouseCore API /admin/cables/{id} or /devices/{id}
-- 3) Updates jobs.cable_snapshot with the returned JSON

-- This file is a template placeholder describing the backfill approach.
