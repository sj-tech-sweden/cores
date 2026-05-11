-- Migration 050: Create job_cables table
-- Adds a join table linking jobs and cables for rental assignments.
-- Note: no FK to cables(cableid) — cables live in WarehouseCore and will be
-- in a separate database once the two services are fully decoupled.

CREATE TABLE IF NOT EXISTS job_cables (
    jobid INTEGER NOT NULL,
    cableid INTEGER NOT NULL,
    PRIMARY KEY (jobid, cableid),
    FOREIGN KEY (jobid) REFERENCES jobs(jobid) ON DELETE CASCADE
);
