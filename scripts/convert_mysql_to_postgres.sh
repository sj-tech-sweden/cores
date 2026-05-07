#!/usr/bin/env bash
set -euo pipefail

MIGRATIONS_DIR=${1:-.}
echo "Scanning migrations under: $MIGRATIONS_DIR"

SKIP_PATTERNS=("DELIMITER" "PROCEDURE" "FUNCTION" "ON DUPLICATE KEY" "ENGINE=" "FULLTEXT")

report_file="convert_report.txt"
> "$report_file"

shopt -s nullglob
for f in $(find "$MIGRATIONS_DIR" -name '*.sql' | sort); do
  echo "\nProcessing: $f"
  skip=0
  for p in "${SKIP_PATTERNS[@]}"; do
    if grep -q -i "$p" "$f"; then
      echo "  SKIP (complex MySQL syntax: $p)" | tee -a "$report_file"
      skip=1
      break
    fi
  done
  if [ "$skip" -eq 1 ]; then
    continue
  fi

  bak="$f.bak"
  if [ ! -f "$bak" ]; then
    cp "$f" "$bak"
  fi

  # 1) Replace backticks with double quotes
  perl -0777 -pe 's/`([^`]*)`/"$1"/g' "$bak" > "$f.tmp"

  # 2) Remove ENGINE/CHARSET/COLLATE at line ends
  sed -E -e 's/\) ENGINE=[^;]*;//g' -e 's/DEFAULT CHARSET=[^;]*;//g' -e 's/ COLLATE=[^;]*;//g' "$f.tmp" > "$f.tmp2" && mv "$f.tmp2" "$f.tmp"

  # 3) Convert AUTO_INCREMENT primary keys
  sed -E -e 's/"([^"]+)"\s+BIGINT\s+AUTO_INCREMENT\s+PRIMARY\s+KEY/"\1" BIGSERIAL PRIMARY KEY/Ig' -e 's/"([^"]+)"\s+INT\s+AUTO_INCREMENT\s+PRIMARY\s+KEY/"\1" SERIAL PRIMARY KEY/Ig' "$f.tmp" > "$f.tmp2" && mv "$f.tmp2" "$f.tmp"

  # 4) Remove remaining AUTO_INCREMENT and UNSIGNED tokens
  sed -E -e 's/AUTO_INCREMENT//Ig' -e 's/UNSIGNED//Ig' "$f.tmp" > "$f.tmp2" && mv "$f.tmp2" "$f.tmp"

  # 5) Remove MySQL-style column comments
  sed -E -e "s/COMMENT '[^']*'//g" "$f.tmp" > "$f.tmp2" && mv "$f.tmp2" "$f.tmp"

  # 6) Remove ON UPDATE CURRENT_TIMESTAMP (Postgres handles differently)
  sed -E -e 's/ON UPDATE CURRENT_TIMESTAMP//Ig' "$f.tmp" > "$f.tmp2" && mv "$f.tmp2" "$f.tmp"

  # 7) Replace INSERT IGNORE with INSERT (note: may need manual review)
  sed -E -e 's/INSERT\\s+IGNORE\\s+INTO/INSERT INTO/Ig' "$f.tmp" > "$f.tmp2" && mv "$f.tmp2" "$f.tmp"

  # 7b) For INSERT statements that previously used IGNORE, append ON CONFLICT DO NOTHING
  # This is a safe no-op when a unique constraint exists; complex ON DUPLICATE KEY patterns are skipped earlier.
  perl -0777 -pe 's/(INSERT\\s+INTO\\s+[^;]*?VALUES\\s*\\([^;]*?\\))\\s*;/\\1 ON CONFLICT DO NOTHING;/igs' "$f.tmp" > "$f.tmp2" && mv "$f.tmp2" "$f.tmp"

  mv "$f.tmp" "$f"
  echo "  Converted (backup: $bak)" | tee -a "$report_file"
done

echo "\nConversion complete. See $report_file for skipped files and notes."
