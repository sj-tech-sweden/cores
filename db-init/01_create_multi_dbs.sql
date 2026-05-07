-- Run by postgres container on first init.
-- Create two databases and users for RentalCore and WarehouseCore.

-- NOTE: Docker's init SQL runner does not substitute environment variables inside files.
-- Replace placeholders below with concrete values, or generate this file from the .env.multi prior to first start.

-- Service users
CREATE USER IF NOT EXISTS rental_user WITH PASSWORD 'change_me_rental';
CREATE USER IF NOT EXISTS warehouse_user WITH PASSWORD 'change_me_warehouse';

-- Create databases owned by the respective users
CREATE DATABASE IF NOT EXISTS rentalcore_db OWNER rental_user;
CREATE DATABASE IF NOT EXISTS warehousecore_db OWNER warehouse_user;

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
