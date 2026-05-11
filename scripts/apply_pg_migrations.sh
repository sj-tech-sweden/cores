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
  sql_without_comments="$(perl -0pe 's{/\*.*?\*/}{}gs; s{^[[:space:]]*--.*$}{}gm; s{^[[:space:]]*#.*$}{}gm' "$f")"
  if printf '%s' "$sql_without_comments" | grep -qiE '`|AUTO_INCREMENT|(^|[[:space:]])DELIMITER([[:space:]]|$)|(^|[[:space:][:punct:]])UNSIGNED([[:space:][:punct:]]|$)|INSERT[[:space:]]+IGNORE|ON[[:space:]]+DUPLICATE[[:space:]]+KEY|ENGINE[[:space:]]*=|(^|[[:space:]])FULLTEXT([[:space:]]|$)|(^|[[:space:]])MODIFY([[:space:]]|$)'; then
    echo "SKIP (contains MySQL-only syntax): $f"
    continue
  fi
  echo "APPLY: $f"
  docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 < "$f"
done

echo "Done. Review skipped files for manual conversion to Postgres if needed."
