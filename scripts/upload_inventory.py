#!/usr/bin/env python3
"""
Simple inventory uploader for WarehouseCore API.

Usage:
  python scripts/upload_inventory.py --file /path/to/inventory.json \
    --api-url http://localhost:8080 --endpoint /api/v1/admin/devices --token $TOKEN

The script is intentionally generic: it posts each JSON record to the given
endpoint. The JSON file may be a top-level array or an object containing a
single array (common keys: `items`, `devices`, `products`, `inventory`).

Options:
  --file FILE         JSON file to upload (required)
  --api-url URL       Base API URL (default: http://localhost:8080)
  --endpoint PATH     API path to POST each record to (default: /api/v1/admin/devices)
  --token TOKEN       Bearer token for Authorization header (optional)
  --batch-size N      Number of items per batch (default: 1)
  --dry-run           Don't POST; just print what would be sent
  --quiet             Minimal output

Note: Ensure the API endpoint and token are correct for your environment.
"""

import argparse
import json
import os
import sys
import time
from typing import Any, List

import requests
import difflib


def detect_array_root(data: Any) -> List[Any]:
    if isinstance(data, list):
        return data
    if isinstance(data, dict):
        # common container keys
        for key in ("items", "devices", "products", "inventory", "rows"):
            if key in data and isinstance(data[key], list):
                return data[key]
        # if single top-level list-like value exists, pick it
        for v in data.values():
            if isinstance(v, list):
                return v
    raise ValueError("JSON file does not contain an array of records")


def post_record(session: requests.Session, url: str, record: dict, quiet: bool) -> (bool, str):
    try:
        r = session.post(url, json=record, timeout=30)
    except Exception as e:
        return False, f"request-failed: {e}"
    if r.status_code >= 200 and r.status_code < 300:
        return True, r.text
    return False, f"{r.status_code}: {r.text}"


def fetch_canonical_categories(session: requests.Session, api_base: str) -> List[str]:
    # Try a few common endpoints that might return category lists
    candidates = [
        '/api/v1/product-categories',
        '/api/v1/categories',
        '/api/v1/products/categories',
    ]
    for path in candidates:
        url = api_base.rstrip('/') + path
        try:
            r = session.get(url, timeout=10)
            if r.status_code == 200:
                data = r.json()
                # Accept either list of strings or list of objects with 'name'
                if isinstance(data, list):
                    names = []
                    for item in data:
                        if isinstance(item, str):
                            names.append(item)
                        elif isinstance(item, dict) and 'name' in item:
                            names.append(item['name'])
                    if names:
                        return names
        except Exception:
            continue
    # Fallback canonical categories
    return [
        'Cables', 'Audio', 'Lighting', 'Video', 'Cases', 'Accessories', 'Power', 'Tools', 'Rigging', 'Consumables'
    ]


def match_category(value: str, canonical: List[str]) -> str:
    if not value:
        return ''
    v = value.lower()
    # Keyword heuristics for cables
    cable_keywords = ('cable', 'kabel', 'lead', 'xlr', 'hdmi', 'dvi', 'power', 'ethernet', 'network', 'trss', 'rca')
    for kw in cable_keywords:
        if kw in v:
            return 'Cables'

    # Try substring match against canonical names
    for name in canonical:
        if name.lower() in v or v in name.lower():
            return name

    # Fuzzy match
    matches = difflib.get_close_matches(value, canonical, n=1, cutoff=0.6)
    if matches:
        return matches[0]

    # No good match, return original (capitalized)
    return value.strip().title()


def main():
    p = argparse.ArgumentParser(description="Upload inventory JSON to WarehouseCore API")
    p.add_argument("--file", required=True, help="Path to inventory JSON file")
    p.add_argument("--api-url", default=os.environ.get("WAREHOUSE_API_URL", "http://localhost:8080"))
    p.add_argument("--endpoint", default="/api/v1/admin/devices")
    p.add_argument("--token", default=os.environ.get("WAREHOUSE_API_TOKEN"))
    p.add_argument("--batch-size", type=int, default=1)
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--map-categories", action="store_true", help="Enable fuzzy mapping of categories (cables detection)")
    p.add_argument("--auto-create", action="store_true", help="Automatically create products and devices when missing")
    p.add_argument("--quiet", action="store_true")
    args = p.parse_args()

    # Build target URL
    api_base = args.api_url.rstrip('/')
    endpoint = args.endpoint if args.endpoint.startswith('/') else '/' + args.endpoint
    target = api_base + endpoint

    if not args.quiet:
        print(f"Uploading {args.file} → {target} (dry-run={args.dry_run})")

    try:
        with open(args.file, 'r', encoding='utf-8') as fh:
            data = json.load(fh)
    except Exception as e:
        print(f"Failed to read JSON file: {e}")
        sys.exit(2)

    try:
        records = detect_array_root(data)
    except ValueError as e:
        print(f"{e}")
        sys.exit(2)

    session = requests.Session()
    headers = {"Content-Type": "application/json"}
    if args.token:
        headers["Authorization"] = f"Bearer {args.token}"
    session.headers.update(headers)

    # Optionally fetch canonical categories for fuzzy mapping
    canonical_categories = []
    if args.map_categories:
        canonical_categories = fetch_canonical_categories(session, args.api_url)
        if not args.quiet:
            print(f"Using canonical categories: {canonical_categories}")

    # If auto-create is requested, fetch existing products once
    existing_products = []
    if args.auto_create:
        try:
            r = session.get(args.api_url.rstrip('/') + '/admin/products', timeout=20)
            if r.status_code == 200:
                existing_products = r.json()
                if not args.quiet:
                    print(f"Fetched {len(existing_products)} existing products")
        except Exception as e:
            if not args.quiet:
                print(f"Warning: failed to fetch existing products: {e}")

    total = len(records)
    success = 0
    failed = []

    batch_size = max(1, args.batch_size)
    for i in range(0, total, batch_size):
        batch = records[i:i + batch_size]
        for rec in batch:
            # Normalize and map categories if requested
            if args.map_categories:
                # prefer common keys
                cat_keys = ['category', 'product_category', 'category_name', 'prod_category', 'type']
                found = None
                for k in cat_keys:
                    if k in rec and rec[k]:
                        found = rec[k]
                        rec[k] = match_category(str(found), canonical_categories)
                        break
                # If no explicit category, try product_name/name
                if not found:
                    name_keys = ['name', 'product_name', 'product', 'title']
                    for nk in name_keys:
                        if nk in rec and rec[nk]:
                            mapped = match_category(str(rec[nk]), canonical_categories)
                            # assign only if mapped to a canonical value
                            if mapped:
                                rec['product_category'] = mapped
                                break

            if args.dry_run:
                if not args.quiet:
                    print(json.dumps(rec, ensure_ascii=False))
                success += 1
                continue

            # Auto-create flow for admin/devices endpoint
            if args.auto_create and endpoint.endswith('/admin/devices'):
                # Build product candidate
                product_name = rec.get('TITLE') or rec.get('name') or rec.get('TITLE')
                product_desc = rec.get('DESCRIPTION') or rec.get('MEMO') or None
                price = rec.get('PRICE1') or rec.get('PRICE') or None

                matched_product = None
                for p in existing_products:
                    if p.get('name') and product_name and p.get('name').strip().lower() == product_name.strip().lower():
                        matched_product = p
                        break

                if not matched_product:
                    # Dry-run handled above; here create product for real
                    payload = {'name': product_name}
                    if product_desc:
                        payload['description'] = product_desc
                    if price:
                        try:
                            payload['price'] = float(price)
                        except Exception:
                            pass
                    try:
                        r = session.post(args.api_url.rstrip('/') + '/admin/products', json=payload, timeout=30)
                        if r.status_code in (200, 201):
                            matched_product = r.json()
                            existing_products.append(matched_product)
                            if not args.quiet:
                                print(f"Created product: {matched_product.get('product_id') or matched_product.get('id') or matched_product.get('name')}")
                        else:
                            failed.append({"index": i + 1, "error": f"product-create {r.status_code}: {r.text}", "record": rec})
                            continue
                    except Exception as e:
                        failed.append({"index": i + 1, "error": f"product-create-exc: {e}", "record": rec})
                        continue

                # create devices from serialnumbers
                serials = []
                if 'serialnumbers' in rec and isinstance(rec['serialnumbers'], list):
                    for s in rec['serialnumbers']:
                        cell = s.get('cell') or {}
                        serials.append({
                            'barcode': cell.get('BARCODE') or None,
                            'serial_number': cell.get('SERIAL') or None,
                            'purchase_date': cell.get('PURCHASE_DATE') or None,
                        })

                pid = matched_product.get('product_id') or matched_product.get('id') if matched_product else None
                if not pid:
                    failed.append({"index": i + 1, "error": "no-product-id", "record": rec})
                    continue

                for s in serials:
                    dev_payload = {
                        'product_id': pid,
                        'serial_number': s.get('serial_number'),
                        'barcode': s.get('barcode'),
                        'status': 'in_storage'
                    }
                    ok, info = post_record(session, args.api_url.rstrip('/') + '/admin/devices', dev_payload, args.quiet)
                    if ok:
                        success += 1
                    else:
                        failed.append({"index": i + 1, "error": info, "record": dev_payload})
                # small delay to avoid spamming the API
                time.sleep(0.05)
                continue

            # Default behavior: post to target endpoint
            ok, info = post_record(session, target, rec, args.quiet)
            if ok:
                success += 1
                if not args.quiet:
                    print(f"[{i+1}/{total}] OK")
            else:
                failed.append({"index": i + 1, "error": info, "record": rec})
                print(f"[{i+1}/{total}] FAILED: {info}")

            # small delay to avoid spamming the API
            time.sleep(0.05)

    print("---")
    print(f"Total: {total}, Successful: {success}, Failed: {len(failed)}")
    if failed:
        print("Failed items (first 10):")
        for f in failed[:10]:
            print(json.dumps(f, ensure_ascii=False))


if __name__ == '__main__':
    main()
