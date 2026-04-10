#!/usr/bin/env python3
"""Smart sync of warehousecore migrations into cores/migrations/postgresql.

Heuristics:
- Skip exact-duplicates (identical normalized content).
- If `000_combined_init.sql` already contains `CREATE TABLE` for a table created by the
  warehouse migration AND the migration is a *pure* CREATE TABLE (no other DDL/DML),
  the migration is considered covered and skipped.  If extra statements are present,
  a `needs_manual_review` reason is logged and the file is scheduled for copy.
- If combined init contains `INSERT INTO <table>` and the warehouse migration is an
  *insert-only* file for the same table, skip to avoid duplicate seeding.
- If a cores migration has high textual similarity to the warehouse migration (default
  threshold 0.7), it's treated as duplicate and skipped.

Usage:
  python3 scripts/sync_warehouse_migrations.py
  python3 scripts/sync_warehouse_migrations.py --apply
  python3 scripts/sync_warehouse_migrations.py --source ../warehousecore/migrations --dest migrations/postgresql --apply
"""

import argparse
import re
import shutil
import sys
from pathlib import Path
from difflib import SequenceMatcher


def normalize_sql(s: str) -> str:
    # remove /* */ comments
    s = re.sub(r'/\*.*?\*/', ' ', s, flags=re.S)
    # remove -- comments
    s = re.sub(r'--.*?\n', ' ', s)
    # collapse whitespace
    s = re.sub(r"\s+", ' ', s)
    return s.strip().lower()


def extract_tables(s: str):
    tables = set()
    # patterns for CREATE/ALTER/INSERT/UPDATE/INTO
    patterns = [r'create table if not exists\s+`?"?([a-z0-9_]+)`?"?',
                r'create table\s+`?"?([a-z0-9_]+)`?"?',
                r'alter table\s+`?"?([a-z0-9_]+)`?"?',
                r'insert into\s+`?"?([a-z0-9_]+)`?"?',
                r'update\s+`?"?([a-z0-9_]+)`?"?']
    for p in patterns:
        for m in re.finditer(p, s, flags=re.I):
            tables.add(m.group(1).lower())
    return tables


def has_schema_changes(sql_norm: str) -> bool:
    """Return True if the normalized SQL contains schema-changing DDL (CREATE, ALTER, DROP)."""
    return bool(re.search(
        r'\b(create|alter|drop)\b',
        sql_norm, flags=re.I))


def has_dml_or_extra_ddl(sql_norm: str) -> bool:
    """Return True if the normalized SQL contains DML or DDL beyond pure CREATE TABLE."""
    return bool(re.search(
        r'\b(insert\s+into|update\s+\w|delete\s+from|alter\s+table|'
        r'create\s+(?:unique\s+)?index|create\s+trigger|create\s+function|'
        r'create\s+(?:or\s+replace\s+)?view|drop\s+\w)\b',
        sql_norm, flags=re.I))



    return SequenceMatcher(None, a, b).ratio()


def load_files(path: Path, pattern='*.sql'):
    files = []
    if not path.exists():
        return files
    for p in sorted(path.glob(pattern)):
        if p.is_file():
            files.append(p)
    return files


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--source', default='../warehousecore/migrations', help='warehousecore migrations dir')
    p.add_argument('--dest', default='migrations/postgresql', help='cores migrations dir (relative to repo root)')
    p.add_argument('--repo-root', default=None, help='Override repo root directory (default: derived from script location)')
    p.add_argument('--apply', action='store_true', help='Copy selected migrations (default: dry-run)')
    p.add_argument('--include-downs', action='store_true', help='Include down/rollback files (default: skip)')
    p.add_argument('--threshold', type=float, default=0.70, help='Similarity threshold to treat as duplicate')
    args = p.parse_args()

    # Default repo root: directory containing this script's parent (i.e. the repo root).
    # Allow override with --repo-root for non-standard layouts.
    if args.repo_root:
        repo_root = Path(args.repo_root).resolve()
    else:
        repo_root = Path(__file__).resolve().parents[1]
    src_dir = (repo_root / args.source).resolve()
    dst_dir = (repo_root / args.dest).resolve()
    combined_init = dst_dir / '000_combined_init.sql'

    if not src_dir.exists():
        print('Source dir not found:', src_dir)
        sys.exit(2)
    if not dst_dir.exists():
        if args.apply:
            print('Destination dir not found, creating:', dst_dir)
            dst_dir.mkdir(parents=True, exist_ok=True)
        else:
            print('Destination dir not found; would create:', dst_dir)

    warehouse_files = load_files(src_dir)
    core_files = load_files(dst_dir)

    core_contents = {p.name: p.read_text(encoding='utf-8', errors='ignore') for p in core_files}
    core_norm = {name: normalize_sql(c) for name, c in core_contents.items()}
    combined_text = ''
    if combined_init.exists():
        combined_text = combined_init.read_text(encoding='utf-8', errors='ignore')
        combined_norm = normalize_sql(combined_text)
    else:
        combined_norm = ''

    to_copy = []
    skipped = []

    for wf in warehouse_files:
        # skip down/rollback files by default
        lower_name = wf.name.lower()
        if (lower_name.endswith('_down.sql') or lower_name.endswith('.down.sql')) and not args.include_downs:
            skipped.append((wf.name, 'skipped_down_file'))
            continue
        wtext = wf.read_text(encoding='utf-8', errors='ignore')
        wnorm = normalize_sql(wtext)
        wtables = extract_tables(wtext)

        # 1) exact duplicate
        if wnorm in core_norm.values():
            skipped.append((wf.name, 'identical_exists'))
            continue

        # 2) table already created in combined init AND this migration creates that table.
        #    Only skip when the migration is a *pure* CREATE TABLE (no other DDL/DML such
        #    as INSERT, ALTER, CREATE INDEX/TRIGGER/FUNCTION/VIEW, etc.).  When extra
        #    statements are present the migration may carry important non-table changes
        #    that would be silently lost, so flag it for manual review instead.
        wtext_tables_created = set()
        for cp in [r'create table if not exists\s+[`"]?([a-z0-9_]+)[`"]?',
                   r'create table\s+[`"]?([a-z0-9_]+)[`"]?']:
            for m in re.finditer(cp, wtext, flags=re.I):
                wtext_tables_created.add(m.group(1).lower())
        has_extra_ddl = has_dml_or_extra_ddl(wnorm)
        covered = False
        for t in wtext_tables_created:
            if re.search(r'create table(?:\s+if\s+not\s+exists)?\s+' + re.escape(t) + r'\b',
                         combined_norm, flags=re.I):
                if has_extra_ddl:
                    skipped.append((wf.name,
                                    f'needs_manual_review (table {t!r} in combined_init '
                                    f'but migration has extra DDL/DML)'))
                else:
                    covered = True
                break
        if covered:
            skipped.append((wf.name, 'covered_by_combined_init'))
            continue

        # 3) seed duplication: only skip if the migration is *insert-only* (no CREATE,
        #    ALTER, or DROP) AND combined_init already seeds the same table.  Migrations
        #    that mix seeding with schema changes must be reviewed manually.
        is_insert_only = not has_schema_changes(wnorm)
        if is_insert_only and re.search(r'insert into', wtext, flags=re.I):
            seeded = False
            for t in wtables:
                if re.search(r'insert into\s+\b' + re.escape(t) + r'\b', combined_norm):
                    seeded = True
                    break
            if seeded:
                skipped.append((wf.name, 'seed_covered_by_combined_init'))
                continue

        # 4) similarity to any existing core file
        similar_found = False
        for name, cnorm in core_norm.items():
            if similar(wnorm, cnorm) >= args.threshold:
                skipped.append((wf.name, f'similar_to_{name}'))
                similar_found = True
                break
        if similar_found:
            continue

        # otherwise schedule for copy
        to_copy.append(wf)

    # Report
    print('\nSummary:')
    print('  Warehouse migrations found:', len(warehouse_files))
    print('  To copy:', len(to_copy))
    if skipped:
        print('  Skipped:', len(skipped))
        for name, reason in skipped:
            print('   -', name, ':', reason)

    if not to_copy:
        print('\nNo migrations to copy.')
        return

    if args.apply:
        for wf in to_copy:
            dst = dst_dir / wf.name
            print('Copying', wf.name, '->', dst.relative_to(repo_root))
            shutil.copy2(wf, dst)
        print('\nDone. Please review and commit the copied files manually.')
    else:
        print('\nDry-run mode. Use --apply to copy the files:')
        for wf in to_copy:
            print('  [DRY] would copy:', wf.name)


if __name__ == '__main__':
    main()
