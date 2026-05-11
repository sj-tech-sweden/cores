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

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Service roles (idempotent)
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${RENTAL_DB_USER}') THEN
            CREATE ROLE ${RENTAL_DB_USER} WITH LOGIN PASSWORD '${RENTAL_DB_PASSWORD}';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${WAREHOUSE_DB_USER}') THEN
            CREATE ROLE ${WAREHOUSE_DB_USER} WITH LOGIN PASSWORD '${WAREHOUSE_DB_PASSWORD}';
        END IF;
    END \$\$;

    -- Create databases (idempotent via \gexec)
    SELECT 'CREATE DATABASE ${RENTAL_DB_NAME} OWNER ${RENTAL_DB_USER}'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${RENTAL_DB_NAME}')
    \gexec

    SELECT 'CREATE DATABASE ${WAREHOUSE_DB_NAME} OWNER ${WAREHOUSE_DB_USER}'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${WAREHOUSE_DB_NAME}')
    \gexec

    -- Grant privileges
    GRANT ALL PRIVILEGES ON DATABASE ${RENTAL_DB_NAME}    TO ${RENTAL_DB_USER};
    GRANT ALL PRIVILEGES ON DATABASE ${WAREHOUSE_DB_NAME} TO ${WAREHOUSE_DB_USER};
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
