# Backfill Denormalized Columns from WarehouseCore API

This guide describes how to populate the `jobs.cable_snapshot` and `jobs.cable_id` columns
(added by migration `052_add_denorm_columns.sql`) after the schema migration has run.

## Why an external script?

PostgreSQL cannot reliably call external HTTP APIs from within a migration. The backfill
must be performed by a one-off script (Go or Python) that runs **after** the migration is
applied.

## Steps

1. **Run the schema migration** — apply `052_add_denorm_columns.sql` to add the columns.

2. **Run the backfill script** — the script should:
   - Query all `jobs` rows where `cable_id IS NULL` (or where `cable_snapshot IS NULL`).
   - For each job that references a cable (via the `job_cables` join table), call the
     WarehouseCore API endpoint `GET /admin/cables/{id}` to retrieve the cable metadata.
   - Write the returned JSON into `jobs.cable_snapshot` and the cable's string identifier
     into `jobs.cable_id`.

3. **Verify** — spot-check a sample of rows to confirm the columns are populated correctly.

## Example (pseudo-Go)

```go
// Error handling omitted for brevity; production code should check all errors.
rows, _ := db.Query(`SELECT j.jobid, jc."cableID" FROM jobs j JOIN job_cables jc ON j.jobid = jc.jobid WHERE j.cable_snapshot IS NULL`)
for rows.Next() {
    var jobID, cableID int
    rows.Scan(&jobID, &cableID)
    cable := warehouseCoreClient.GetCable(cableID)
    db.Exec(`UPDATE jobs SET cable_id=$1, cable_snapshot=$2 WHERE jobid=$3`, strconv.Itoa(cableID), cable.JSON(), jobID)
}
```

## Notes

- Run during a maintenance window or as a background job during low-traffic periods.
- The script is safe to re-run (it only targets rows where `cable_snapshot IS NULL`).
- Once complete, the `job_cables` join table can be considered a legacy relation and
  eventually dropped when all consumers have been updated to use `cable_snapshot`.
