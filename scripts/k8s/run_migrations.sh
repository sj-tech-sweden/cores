#!/bin/sh
set -eu

: "${DB_HOST:?DB_HOST is required}"
: "${DB_PORT:=5432}"
: "${DB_NAME:?DB_NAME is required}"
: "${DB_USER:?DB_USER is required}"
: "${DB_PASSWORD:?DB_PASSWORD is required}"
: "${MIGRATIONS_DIR:=/migrations/postgresql}"
: "${MIGRATIONS_TABLE:=schema_migrations}"
: "${MIGRATION_LOCK_KEY:=837194}"

export PGPASSWORD="$DB_PASSWORD"

psql_base="psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -v ON_ERROR_STOP=1"

echo "Waiting for PostgreSQL at $DB_HOST:$DB_PORT ..."
until sh -c "$psql_base -c 'SELECT 1' >/dev/null 2>&1"; do
  sleep 2
done

echo "Ensuring migration tracking table exists..."
sh -c "$psql_base <<'SQL'
CREATE TABLE IF NOT EXISTS schema_migrations (
  filename TEXT PRIMARY KEY,
  applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
SQL"

echo "Acquiring advisory lock..."
sh -c "$psql_base -c 'SELECT pg_advisory_lock($MIGRATION_LOCK_KEY);' >/dev/null"

cleanup() {
  echo "Releasing advisory lock..."
  sh -c "$psql_base -c 'SELECT pg_advisory_unlock($MIGRATION_LOCK_KEY);' >/dev/null" || true
}
trap cleanup EXIT

if [ ! -d "$MIGRATIONS_DIR" ]; then
  echo "Migrations directory not found: $MIGRATIONS_DIR"
  exit 1
fi

files=$(find "$MIGRATIONS_DIR" -maxdepth 1 -type f -name '*.sql' | sort)

if [ -z "$files" ]; then
  echo "No migration files found in $MIGRATIONS_DIR"
  exit 0
fi

for file in $files; do
  filename=$(basename "$file")

  already_applied=$(sh -c "$psql_base -tA -c \"SELECT 1 FROM $MIGRATIONS_TABLE WHERE filename = '$filename'\"")
  if [ "$already_applied" = "1" ]; then
    echo "Skipping already applied migration: $filename"
    continue
  fi

  echo "Applying migration: $filename"
  sh -c "$psql_base -f '$file'"
  sh -c "$psql_base -c \"INSERT INTO $MIGRATIONS_TABLE (filename) VALUES ('$filename');\""
  echo "Applied: $filename"
done

echo "All pending migrations applied successfully."
