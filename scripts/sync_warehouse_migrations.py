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
    # remove -- comments (including a trailing comment at EOF with no final newline)
    s = re.sub(r'--.*?(?:\n|\Z)', ' ', s)
    # collapse whitespace
    s = re.sub(r"\s+", ' ', s)
    return s.strip().lower()


def _normalize_table_name(identifier: str) -> str:
    """Strip schema prefix and quotes; return the bare lower-case table name."""
    parts = [part.strip('`"') for part in identifier.split('.')]
    return parts[-1].lower()


def extract_tables(s: str):
    tables = set()
    # An identifier segment: plain name (optionally backtick-quoted) or double-quoted name.
    _SEG = r'(?:`?[a-zA-Z0-9_]+`?|"[^"]+")'
    # Full identifier: optional schema prefix followed by the table name.
    _ident = rf'{_SEG}(?:\.{_SEG})?'
    # patterns for CREATE/ALTER/INSERT/UPDATE/INTO
    patterns = [rf'create table if not exists\s+({_ident})',
                rf'create table\s+({_ident})',
                rf'alter table\s+({_ident})',
                rf'insert into\s+({_ident})',
                rf'update\s+({_ident})']
    for p in patterns:
        for m in re.finditer(p, s, flags=re.I):
            tables.add(_normalize_table_name(m.group(1)))
    return tables


def has_schema_changes(sql_norm: str) -> bool:
    """Return True if the normalized SQL contains schema-changing DDL (CREATE, ALTER, DROP)."""
    return bool(re.search(
        r'\b(create|alter|drop)\b',
        sql_norm, flags=re.I))


def has_dml_or_extra_ddl(sql_norm: str) -> bool:
    """Return True unless the normalized SQL is made up only of plain CREATE TABLE statements.

    DML (INSERT, UPDATE, DELETE, MERGE, TRUNCATE) is flagged directly.
    For DDL, CREATE TABLE / CREATE TABLE IF NOT EXISTS statements are stripped first;
    if any CREATE/ALTER/DROP keyword remains the migration contains non-table DDL
    (e.g. CREATE SEQUENCE/TYPE/INDEX/EXTENSION, ALTER TYPE, DROP FUNCTION, etc.)
    and must be copied/flagged for manual review.
    """
    # Fast path: flag any DML immediately.
    if re.search(
        r'\b(insert\s+into|update\s+\w|delete\s+from|merge\s+into|truncate\s+table)\b',
        sql_norm, flags=re.I,
    ):
        return True

    # Strip all bare CREATE TABLE statements (including IF NOT EXISTS variants),
    # then check whether any schema-changing keyword survives.
    sql_without_create_table = re.sub(
        r'\bcreate\s+table(?:\s+if\s+not\s+exists)?\s+[^;]+(?:;|$)',
        ' ',
        sql_norm,
        flags=re.I,
    )
    return bool(re.search(r'\b(create|alter|drop)\b', sql_without_create_table, flags=re.I))


def similar(a: str, b: str) -> float:
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
    p.add_argument('--force', action='store_true', help='Overwrite existing destination files even when content differs (requires --apply)')
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
    # Pre-build a set of normalized content values for O(1) exact-duplicate checks.
    core_norm_set = set(core_norm.values())
    # Exclude 000_combined_init.sql from similarity comparisons — it's very large and
    # is already handled explicitly by the covered_by_combined_init heuristic below.
    SIMILARITY_EXCLUDE = {'000_combined_init.sql'}
    core_norm_for_similarity = {k: v for k, v in core_norm.items() if k not in SIMILARITY_EXCLUDE}
    combined_text = ''
    if combined_init.exists():
        combined_text = combined_init.read_text(encoding='utf-8', errors='ignore')
        combined_norm = normalize_sql(combined_text)
    else:
        combined_norm = ''

    to_copy = []
    skipped = []
    needs_review = []  # Files scheduled for copy but flagged for manual review

    for wf in warehouse_files:
        # skip down/rollback files by default
        lower_name = wf.name.lower()
        if (lower_name.endswith('_down.sql') or lower_name.endswith('.down.sql')) and not args.include_downs:
            skipped.append((wf.name, 'skipped_down_file'))
            continue
        wtext = wf.read_text(encoding='utf-8', errors='ignore')
        wnorm = normalize_sql(wtext)
        # Run table extraction on the comment-stripped, normalized SQL so that
        # commented-out statements (e.g. "-- CREATE TABLE foo …") do not falsely
        # influence the seeding/coverage heuristics.
        wtables = extract_tables(wnorm)

        # 1) exact duplicate
        if wnorm in core_norm_set:
            skipped.append((wf.name, 'identical_exists'))
            continue

        # 2) table already created in combined init AND this migration creates that table.
        #    Only skip when the migration is a *pure* CREATE TABLE (no other DDL/DML such
        #    as INSERT, ALTER, CREATE INDEX/TRIGGER/FUNCTION/VIEW, etc.).  When extra
        #    statements are present the migration may carry important non-table changes
        #    that would be silently lost, so flag it for manual review, add it to to_copy,
        #    and continue immediately so it is never dropped by later heuristics.
        wtext_tables_created = set()
        for cp in [r'create table if not exists\s+[`"]?([a-z0-9_]+)[`"]?',
                   r'create table\s+[`"]?([a-z0-9_]+)[`"]?']:
            for m in re.finditer(cp, wtext, flags=re.I):
                wtext_tables_created.add(m.group(1).lower())
        has_extra_ddl = has_dml_or_extra_ddl(wnorm)
        covered = False
        force_copy = False
        if wtext_tables_created:
            all_in_combined = all(
                re.search(
                    r'create table(?:\s+if\s+not\s+exists)?\s+' + re.escape(t) + r'\b',
                    combined_norm, flags=re.I,
                )
                for t in wtext_tables_created
            )
            if all_in_combined:
                if has_extra_ddl:
                    needs_review.append((wf.name,
                                        'all created tables present in combined_init '
                                        'but migration has extra DDL/DML — review before applying'))
                    force_copy = True
                else:
                    covered = True
        if force_copy:
            to_copy.append(wf)
            continue  # bypass all later heuristics; file is already queued for review
        if covered:
            skipped.append((wf.name, 'covered_by_combined_init'))
            continue

        # 3) seed duplication: only skip if the migration is *truly insert-only* — i.e.
        #    it contains at least one INSERT INTO and no DDL (CREATE/ALTER/DROP) and no
        #    other DML (UPDATE/DELETE/MERGE/TRUNCATE) — AND combined_init already seeds
        #    the same table.  Migrations mixing seeding with any other statement type
        #    are not skipped here.
        is_insert_only = (
            bool(re.search(r'\binsert\s+into\b', wnorm, flags=re.I))
            and not re.search(
                r'\b(update\s+\w|delete\s+from|merge\s+into|truncate\s+table'
                r'|create|alter|drop)\b',
                wnorm, flags=re.I,
            )
        )
        if is_insert_only:
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
        for name, cnorm in core_norm_for_similarity.items():
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
    if needs_review:
        print('  Needs manual review (will be copied):', len(needs_review))
        for name, reason in needs_review:
            print('   ! ', name, ':', reason)
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
            if dst.exists():
                dst_norm = normalize_sql(dst.read_text(encoding='utf-8', errors='ignore'))
                wf_norm = normalize_sql(wf.read_text(encoding='utf-8', errors='ignore'))
                if dst_norm == wf_norm:
                    print('Skipping (identical):', wf.name)
                    continue
                if not args.force:
                    print(f'WARN: {wf.name} already exists at destination with different content. '
                          f'Use --force to overwrite.')
                    continue
                print('Overwriting (--force):', wf.name, '->', dst.relative_to(repo_root))
            else:
                print('Copying', wf.name, '->', dst.relative_to(repo_root))
            shutil.copy2(wf, dst)
        print('\nDone. Please review and commit the copied files manually.')
    else:
        print('\nDry-run mode. Use --apply to copy the files:')
        for wf in to_copy:
            dst = dst_dir / wf.name
            if dst.exists():
                dst_norm = normalize_sql(dst.read_text(encoding='utf-8', errors='ignore'))
                wf_norm = normalize_sql(wf.read_text(encoding='utf-8', errors='ignore'))
                if dst_norm == wf_norm:
                    print('  [DRY] would skip (identical):', wf.name)
                else:
                    print('  [DRY] would overwrite (use --force):', wf.name)
            else:
                print('  [DRY] would copy:', wf.name)


if __name__ == '__main__':
    main()
