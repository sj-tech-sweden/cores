#!/usr/bin/env bash
set -euo pipefail

# Apply all SQL migration files from migrations/postgresql to the running Postgres container
# Usage: COMPOSE_FILE=docker-compose.dev.yaml ./scripts/apply_migrations.sh

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.dev.yaml}"
SERVICE="${POSTGRES_SERVICE:-postgres}"
DB_USER="${POSTGRES_USER:-rentalcore}"
DB_NAME="${POSTGRES_DB:-rentalcore}"
UNIFIED_MIGRATIONS_DIR="${UNIFIED_MIGRATIONS_DIR:-}"

if [ -n "$UNIFIED_MIGRATIONS_DIR" ]; then
  SQL_DIRS=("$UNIFIED_MIGRATIONS_DIR")
else
  SQL_DIRS=("${SQL_DIR:-./migrations/postgresql}" "${WAREHOUSE_MIGRATIONS_DIR:-../warehousecore/migrations}")
fi

all_found=false
for SQL_DIR in "${SQL_DIRS[@]}"; do
  if [ ! -d "$SQL_DIR" ]; then
    continue
  fi

  # collect and sort .sql files
  mapfile -t files_sorted < <(ls -1 "$SQL_DIR"/*.sql 2>/dev/null | sort)
  if [ ${#files_sorted[@]} -eq 0 ]; then
    continue
  fi

  all_found=true
  echo "Applying SQL files from $SQL_DIR to $SERVICE (db: $DB_NAME user: $DB_USER) using compose file $COMPOSE_FILE"
  for f in "${files_sorted[@]}"; do
    echo "--- Applying: $f ---"
    docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" psql -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 -f - < "$f"
    echo "OK: $f"
  done
done

if [ "$all_found" = false ]; then
  echo "No .sql files found in any migration directories. Checked: ${SQL_DIRS[*]}"
  exit 0
fi

echo "All migrations applied."
