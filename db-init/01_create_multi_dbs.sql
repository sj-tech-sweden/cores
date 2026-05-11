-- Run by postgres container on first init.
-- Create two databases and users for RentalCore and WarehouseCore.

-- NOTE: Docker's init SQL runner does not substitute environment variables inside files.
-- Replace placeholders below with concrete values, or generate this file from the .env.multi prior to first start.

-- Service users (idempotent via DO block)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rental_user') THEN
        CREATE ROLE rental_user WITH LOGIN PASSWORD 'change_me_rental';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'warehouse_user') THEN
        CREATE ROLE warehouse_user WITH LOGIN PASSWORD 'change_me_warehouse';
    END IF;
END $$;

-- Create databases owned by the respective users (idempotent via \gexec)
SELECT 'CREATE DATABASE rentalcore_db OWNER rental_user'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'rentalcore_db')
\gexec

SELECT 'CREATE DATABASE warehousecore_db OWNER warehouse_user'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'warehousecore_db')
\gexec

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE rentalcore_db TO rental_user;
GRANT ALL PRIVILEGES ON DATABASE warehousecore_db TO warehouse_user;

-- Install useful extensions inside each DB
\connect rentalcore_db
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

\connect warehousecore_db
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Return to default DB
\connect postgres
