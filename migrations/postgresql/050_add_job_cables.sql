-- Migration 050: Create job_cables table
-- Adds a join table linking jobs and cables for rental assignments

CREATE TABLE IF NOT EXISTS job_cables (
    jobid INTEGER NOT NULL,
    cableid INTEGER NOT NULL,
    PRIMARY KEY (jobid, cableid),
    FOREIGN KEY (jobid) REFERENCES jobs(jobid) ON DELETE CASCADE,
    FOREIGN KEY (cableid) REFERENCES cables(cableid) ON DELETE CASCADE
);
