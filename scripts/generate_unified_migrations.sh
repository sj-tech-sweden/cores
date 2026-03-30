#!/usr/bin/env bash
set -euo pipefail

# Generate a unified SQL file by concatenating the combined init and all
# migration SQL files from rentalcore and warehousecore (sorted).
# Output: migrations/unified/000_unified_init.sql and a diff against the combined init.

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT_DIR/migrations/unified"
COMBINED="$ROOT_DIR/migrations/postgresql/000_combined_init.sql"
OUT_FILE="$OUT_DIR/000_unified_init.sql"

mkdir -p "$OUT_DIR"

echo "/* Unified migrations file generated: $(date -u) */" > "$OUT_FILE"
echo "-- Source: $COMBINED" >> "$OUT_FILE"
echo "" >> "$OUT_FILE"
cat "$COMBINED" >> "$OUT_FILE"

append_dir() {
  src_dir="$1"
  if [ -d "$src_dir" ]; then
    echo "" >> "$OUT_FILE"
    echo "-- ===== Begin migrations from: $src_dir =====" >> "$OUT_FILE"
    echo "" >> "$OUT_FILE"
    for f in $(ls -1 "$src_dir"/*.sql 2>/dev/null | sort); do
      base="$(basename "$f")"

      # Skip rollback files in unified init output.
      if [[ "$base" == *.down.sql || "$base" == *_down.sql ]]; then
        echo "-- ---- SKIP (down migration): $f ----" >> "$OUT_FILE"
        continue
      fi

      # Skip files that are clearly MySQL-only or not PostgreSQL compatible.
      if grep -Eiq 'ENGINE=InnoDB|AUTO_INCREMENT|CHARSET=|COLLATE=utf8|CREATE DATABASE IF NOT EXISTS|^[[:space:]]*USE[[:space:]]+`|^[[:space:]]*USE[[:space:]]+[A-Za-z0-9_]+|[[:space:]]AFTER[[:space:]]|ADD[[:space:]]+KEY|MODIFY[[:space:]]+COLUMN|`[A-Za-z0-9_]+`|ON UPDATE CURRENT_TIMESTAMP|DELIMITER|CREATE[[:space:]]+PROCEDURE|DROP[[:space:]]+PROCEDURE|JSON_OBJECT|JSON_ARRAY|ON DUPLICATE KEY UPDATE' "$f"; then
        echo "-- ---- SKIP (non-postgres syntax): $f ----" >> "$OUT_FILE"
        continue
      fi

      echo "-- ---- BEGIN: $f ----" >> "$OUT_FILE"
      echo "" >> "$OUT_FILE"
      sed 's/\r$//' "$f" >> "$OUT_FILE"
      echo "" >> "$OUT_FILE"
      echo "-- ---- END: $f ----" >> "$OUT_FILE"
      echo "" >> "$OUT_FILE"
    done
  fi
}

# Keep unified bootstrap deterministic: do not append raw service migration dumps.
# Those files include legacy/incompatible SQL and are not safe for first-run bootstrap.

# Ensure admin user exists at the end as a safety net for dev environments
cat >> "$OUT_FILE" <<'SQL'

-- ===== Final safety seed: ensure admin user exists =====
INSERT INTO users (username, email, password_hash, first_name, last_name, is_admin, is_active, force_password_change)
VALUES ('admin', 'admin@example.com', '$2a$10$AlHJcEvCFEXXAoxQ/S4XXeVy3coR0yHtTv0Pn3bHEH/z3t3jdGVru', 'System', 'Administrator', TRUE, TRUE, TRUE)
ON CONFLICT (username) DO NOTHING;

DO $$
DECLARE
  admin_user_id INT;
BEGIN
  SELECT userid INTO admin_user_id FROM users WHERE username = 'admin';
  IF admin_user_id IS NOT NULL THEN
    INSERT INTO user_roles (userid, roleid)
    SELECT admin_user_id, roleid FROM roles WHERE name IN ('super_admin', 'admin', 'warehouse_admin')
    ON CONFLICT (userid, roleid) DO NOTHING;
  END IF;
END $$;
SQL

echo "" >> "$OUT_FILE"
echo "/* End of unified migrations */" >> "$OUT_FILE"

echo "Generated: $OUT_FILE"

# Also produce a diff vs combined init for PR-style review
DIFF_FILE="$OUT_DIR/000_unified_init.diff"
diff -u "$COMBINED" "$OUT_FILE" > "$DIFF_FILE" || true
echo "Diff written to: $DIFF_FILE"
