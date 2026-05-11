#!/usr/bin/env bash
# db-init/01_create_multi_dbs.sh
# Runs inside the PostgreSQL container on first initialisation.
# All variables are sourced from the container environment (env_file: .env.multi).
# Copy .env.multi.example to .env.multi and set real credentials before first start.

set -euo pipefail

: "${RENTAL_DB_USER:?RENTAL_DB_USER is not set}"
: "${RENTAL_DB_PASSWORD:?RENTAL_DB_PASSWORD is not set}"
: "${RENTAL_DB_NAME:?RENTAL_DB_NAME is not set}"
: "${WAREHOUSE_DB_USER:?WAREHOUSE_DB_USER is not set}"
: "${WAREHOUSE_DB_PASSWORD:?WAREHOUSE_DB_PASSWORD is not set}"
: "${WAREHOUSE_DB_NAME:?WAREHOUSE_DB_NAME is not set}"

# Validate that identifier values (DB names and role names) are safe:
# only alphanumeric characters and underscores are permitted.
check_identifier() {
    local value="$1" label="$2"
    if [[ ! "$value" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        echo "ERROR: $label ('$value') must be a valid SQL identifier (letters, digits, underscores only)." >&2
        exit 1
    fi
}

check_identifier "$RENTAL_DB_USER"    "RENTAL_DB_USER"
check_identifier "$RENTAL_DB_NAME"    "RENTAL_DB_NAME"
check_identifier "$WAREHOUSE_DB_USER" "WAREHOUSE_DB_USER"
check_identifier "$WAREHOUSE_DB_NAME" "WAREHOUSE_DB_NAME"

psql -v ON_ERROR_STOP=1 \
    -v "rental_db_user=$RENTAL_DB_USER" \
    -v "rental_db_password=$RENTAL_DB_PASSWORD" \
    -v "rental_db_name=$RENTAL_DB_NAME" \
    -v "warehouse_db_user=$WAREHOUSE_DB_USER" \
    -v "warehouse_db_password=$WAREHOUSE_DB_PASSWORD" \
    -v "warehouse_db_name=$WAREHOUSE_DB_NAME" \
    --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" << 'EOSQL'
    -- Service roles (idempotent); format() safely quotes identifiers and string literals.
    DO $$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'rental_db_user') THEN
            EXECUTE format('CREATE ROLE %I WITH LOGIN PASSWORD %L',
                           :'rental_db_user', :'rental_db_password');
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'warehouse_db_user') THEN
            EXECUTE format('CREATE ROLE %I WITH LOGIN PASSWORD %L',
                           :'warehouse_db_user', :'warehouse_db_password');
        END IF;
    END $$;

    -- Create databases (idempotent via \gexec)
    SELECT format('CREATE DATABASE %I OWNER %I', :'rental_db_name', :'rental_db_user')
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = :'rental_db_name')
    \gexec

    SELECT format('CREATE DATABASE %I OWNER %I', :'warehouse_db_name', :'warehouse_db_user')
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = :'warehouse_db_name')
    \gexec

    -- Grant privileges
    DO $$
    BEGIN
        EXECUTE format('GRANT ALL PRIVILEGES ON DATABASE %I TO %I',
                       :'rental_db_name', :'rental_db_user');
        EXECUTE format('GRANT ALL PRIVILEGES ON DATABASE %I TO %I',
                       :'warehouse_db_name', :'warehouse_db_user');
    END $$;
EOSQL

# Install extensions inside each database (cannot run inside the heredoc above
# because CREATE EXTENSION requires a connection to the target database).
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "${RENTAL_DB_NAME}" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS pg_trgm;
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
EOSQL

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "${WAREHOUSE_DB_NAME}" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS pg_trgm;
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
EOSQL
