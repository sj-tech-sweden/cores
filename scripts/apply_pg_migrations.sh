#!/usr/bin/env bash
set -eu

# Apply only Postgres-compatible SQL files from a migrations directory
# Skips files that contain common MySQL-only syntax (backticks, AUTO_INCREMENT, DELIMITER, UNSIGNED, INSERT IGNORE, ON DUPLICATE KEY, ENGINE, FULLTEXT)

MIGRATIONS_DIR=${1:-../warehousecore/migrations}
DB_CONTAINER=${2:-warehouse-db}
DB_USER=${3:-${WAREHOUSE_DB_USER:-warehouse}}
DB_NAME=${4:-${WAREHOUSE_DB_NAME:-warehousecore_dev}}

echo "Applying Postgres-compatible migrations from: $MIGRATIONS_DIR -> container: $DB_CONTAINER"

shopt -s nullglob
for f in "$MIGRATIONS_DIR"/*.sql; do
  echo "--- checking $f"
  if grep -qiE '`|AUTO_INCREMENT|DELIMITER|UNSIGNED|INSERT IGNORE|ON DUPLICATE KEY|ENGINE=|FULLTEXT|MODIFY |`' "$f"; then
    echo "SKIP (contains MySQL-only syntax): $f"
    continue
  fi
  echo "APPLY: $f"
  cat "$f" | docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME"
done

echo "Done. Review skipped files for manual conversion to Postgres if needed."
