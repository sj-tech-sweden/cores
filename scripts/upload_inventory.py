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
import csv


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


def fetch_category_map(session: requests.Session, api_base: str):
    """Return dict mapping lowercase category name -> category_id when available"""
    try:
        r = session.get(api_base.rstrip('/') + '/api/v1/admin/categories', timeout=10)
        if r.status_code == 200:
            data = r.json()
            if isinstance(data, list):
                m = {}
                for item in data:
                    if isinstance(item, dict):
                        name = item.get('name')
                        cid = item.get('category_id') or item.get('id') or item.get('categoryID')
                        if name and cid is not None:
                            m[name.strip().lower()] = cid
                return m
    except Exception:
        pass
    return {}


def fetch_name_id_map(session: requests.Session, api_base: str, path: str, id_key: str = 'id'):
    try:
        r = session.get(api_base.rstrip('/') + f'/api/v1/admin/{path}', timeout=10)
        if r.status_code == 200:
            data = r.json()
            if isinstance(data, list):
                m = {}
                for item in data:
                    if isinstance(item, dict):
                        name = item.get('name')
                        cid = item.get(id_key) or item.get(id_key.lower())
                        if name and cid is not None:
                            m[name.strip().lower()] = cid
                return m
    except Exception:
        pass
    return {}


def load_hirehop_mapping(path: str):
    """Load mapping CSV into dict: hirehop_lower -> {category, subcategory}
    Expected CSV: hirehop_category,*,warehousecore_category,*,warehousecore_subcategory
    Handles simple two/three column formats gracefully.
    """
    m = {}
    def process_row(row):
        hire = row[0].strip()
        if not hire:
            return
        wc_cat = None
        wc_sub = None
        if len(row) >= 3 and row[2].strip():
            wc_cat = row[2].strip()
        elif len(row) >= 2 and row[1].strip():
            wc_cat = row[1].strip()
        if len(row) >= 5 and row[4].strip():
            wc_sub = row[4].strip()
        elif len(row) >= 4 and row[3].strip():
            wc_sub = row[3].strip()
        m[hire.lower()] = {'category': wc_cat, 'subcategory': wc_sub}

    try:
        with open(path, newline='', encoding='utf-8') as cf:
            reader = csv.reader(cf)
            first_data_row = True
            for row in reader:
                if not row:
                    continue
                if row[0].strip().lower().startswith('#'):
                    continue

                if first_data_row:
                    first_data_row = False
                    normalized = [col.strip().lower() for col in row]
                    is_header = (
                        len(normalized) >= 1 and normalized[0] == 'hirehop_category' and (
                            (len(normalized) >= 3 and normalized[2] == 'warehousecore_category') or
                            (len(normalized) >= 2 and normalized[1] == 'warehousecore_category')
                        )
                    )
                    if is_header:
                        continue

                process_row(row)
    except Exception:
        pass
    return m


def create_or_get_entity(session: requests.Session, api_base: str, path: str, name: str, id_key: str = 'id'):
    """Create an entity (brand/manufacturer) if missing and return its id."""
    if not name:
        return None
    try:
        # Try exact-name GET
        q = {'name': name}
        rr = session.get(api_base.rstrip('/') + f'/api/v1/admin/{path}', params=q, timeout=10)
        if rr.status_code == 200:
            try:
                found = rr.json()
                if isinstance(found, list) and found:
                    for f in found:
                        if isinstance(f, dict) and f.get('name') and f.get('name').strip().lower() == name.strip().lower():
                            return f.get(id_key) or f.get(id_key.lower())
            except Exception:
                pass
        # Not found, create
        payload = {'name': name}
        cr = session.post(api_base.rstrip('/') + f'/api/v1/admin/{path}', json=payload, timeout=20)
        if cr.status_code in (200, 201):
            try:
                obj = cr.json()
                if isinstance(obj, dict):
                    return obj.get(id_key) or obj.get(id_key.lower())
            except Exception:
                loc = cr.headers.get('Location') or cr.headers.get('location')
                if loc:
                    return loc.rstrip('/').split('/')[-1]
        return None
    except Exception:
        return None


def match_category(value: str, canonical: List[str]) -> str:
    if not value:
        return ''
    v = value.lower()
    # Keyword heuristics for cables. Keep generic cable-specific terms, but
    # avoid overly broad matches such as standalone "power" which would
    # incorrectly classify categories like "Power Distribution" as cables.
    cable_keywords = (
        'cable', 'kabel', 'lead', 'xlr', 'hdmi', 'dvi',
        'power cable', 'power lead',
        'ethernet', 'network', 'trss', 'rca'
    )
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
    p.add_argument("--cookies", help="Path to cookies.txt (Netscape/curl -c) to load session cookies")
    p.add_argument("--session-id", help="Raw session_id cookie value to set for the API host (convenience)")
    p.add_argument("--batch-size", type=int, default=1)
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--map-categories", action="store_true", help="Enable fuzzy mapping of categories (cables detection)")
    p.add_argument("--auto-create", action="store_true", help="Automatically create products and devices when missing")
    p.add_argument("--quiet", action="store_true")
    p.add_argument("--debug", action="store_true", help="Enable verbose debug output (may print request details)")
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

    # Load cookies from Netscape 'cookies.txt' (curl -c) if provided
    def load_cookies_netscape(path):
        cookies = {}
        try:
            with open(path, 'r', encoding='utf-8') as cf:
                for line in cf:
                    line = line.rstrip('\n')
                    if not line:
                        continue
                    # lines starting with '#HttpOnly_' are valid cookie lines with a leading '#'
                    if line.startswith('#HttpOnly_'):
                        line = line[1:]
                    elif line.startswith('#'):
                        continue
                    parts = line.split('\t')
                    if len(parts) >= 7:
                        name = parts[5]
                        value = parts[6]
                        cookies[name] = value
        except Exception:
            return {}
        return cookies

    if args.cookies:
        ck = load_cookies_netscape(args.cookies)
        if ck:
            session.cookies.update(ck)
            if not args.quiet:
                print(f"Loaded {len(ck)} cookies from {args.cookies}")
    # If a raw session id is provided, set it for the API host explicitly
    if args.session_id:
        try:
            from urllib.parse import urlparse
            p = urlparse(args.api_url)
            host = p.hostname or 'localhost'
            # set cookie for the host and root path
            session.cookies.set('session_id', args.session_id, domain=host, path='/')
            if not args.quiet:
                print(f"Set session_id cookie for host {host}")
        except Exception:
            session.cookies.set('session_id', args.session_id)

    # Optionally fetch canonical categories for fuzzy mapping
    canonical_categories = []
    if args.map_categories:
        canonical_categories = fetch_canonical_categories(session, args.api_url)
        if not args.quiet:
            print(f"Using canonical categories: {canonical_categories}")

    # Fetch id maps for categories, brands and manufacturers to populate numeric IDs
    category_map = {}
    brand_map = {}
    manufacturer_map = {}
    subcategory_map = {}
    hirehop_map = {}
    if args.map_categories:
        category_map = fetch_category_map(session, args.api_url)
        brand_map = fetch_name_id_map(session, args.api_url, 'brands', id_key='brand_id')
        manufacturer_map = fetch_name_id_map(session, args.api_url, 'manufacturers', id_key='manufacturer_id')
        subcategory_map = fetch_name_id_map(session, args.api_url, 'subcategories', id_key='subcategory_id')
        # load mapping CSV if present
        mapping_csv = os.path.join(os.path.dirname(__file__), 'hirehop_to_warehousecore_map.csv')
        hirehop_map = load_hirehop_mapping(mapping_csv)
        if not args.quiet:
            print(f"Category map keys: {list(category_map.keys())[:10]}")

    # If auto-create is requested, fetch existing products once
    existing_products = []
    if args.auto_create:
        try:
            r = session.get(args.api_url.rstrip('/') + '/api/v1/admin/products', timeout=20)
            if r.status_code == 200:
                try:
                    data = r.json()
                except Exception as e:
                    if not args.quiet:
                        print(f"Warning: failed to parse existing products response: {e} (status {r.status_code})")
                    data = []
                # Ensure we have a list
                if isinstance(data, list):
                    existing_products = data
                else:
                    # sometimes API returns an object or null; coerce to empty list
                    existing_products = []
                if not args.quiet:
                    try:
                        cnt = len(existing_products)
                    except Exception:
                        cnt = 0
                    print(f"Fetched {cnt} existing products (parsed)")
        except Exception as e:
            if not args.quiet:
                print(f"Warning: failed to fetch existing products: {e}")

    total = len(records)
    success = 0
    records_processed = 0
    devices_created = 0
    failed = []

    batch_size = max(1, args.batch_size)
    for batch_start in range(0, total, batch_size):
        batch = records[batch_start:batch_start + batch_size]
        for record_index, rec in enumerate(batch, start=batch_start):
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

            # Handle dry-run: show transformed payloads when auto-creating,
            # otherwise show the original record.
            if args.dry_run:
                if args.auto_create and endpoint.endswith('/admin/devices'):
                    # Show the product payload that would be created
                    product_name = rec.get('TITLE') or rec.get('name') or rec.get('TITLE')
                    product_desc = rec.get('DESCRIPTION') or rec.get('MEMO') or None
                    price = rec.get('PRICE1') or rec.get('PRICE') or None
                    prod_payload = {'name': product_name}
                    if product_desc:
                        prod_payload['description'] = product_desc
                    if price:
                        try:
                            prod_payload['price'] = float(price)
                        except Exception:
                            prod_payload['price'] = price

                    # Build device payloads from serialnumbers and quantity (QTY)
                    def _extract_qty(r):
                        for k in ('QTY', 'qty', 'quantity', 'count'):
                            if k in r and r[k] is not None:
                                try:
                                    return int(r[k])
                                except Exception:
                                    pass
                        return None

                    # Robustly extract serial entries supporting multiple shapes
                    serials = []
                    if 'serialnumbers' in rec and isinstance(rec['serialnumbers'], list):
                        for s in rec['serialnumbers']:
                            serial = None
                            barcode = None
                            purchase_date = None
                            # entry may be a dict with 'cell' or direct keys, or a primitive
                            if isinstance(s, dict):
                                cell = s.get('cell') or s
                                if isinstance(cell, dict):
                                    serial = cell.get('SERIAL') or cell.get('serial') or cell.get('serial_number') or cell.get('id')
                                    barcode = cell.get('BARCODE') or cell.get('barcode')
                                    purchase_date = cell.get('PURCHASE_DATE') or cell.get('purchase_date')
                                else:
                                    # unexpected nested primitive
                                    serial = str(cell)
                            else:
                                # primitive value
                                serial = str(s)
                            # normalize to string when present to satisfy API schema
                            serials.append({
                                'serial_number': str(serial) if serial is not None else None,
                                'barcode': barcode,
                                'purchase_date': purchase_date,
                            })

                    qty = _extract_qty(rec) or len(serials) or 1

                    # Simulate a product_id for dry-run so payloads look realistic
                    sim_pid = f"<simulated_product_id:{(product_name or 'unknown').replace(' ', '_')}>"

                    # Build final device payloads up to qty
                    devices_to_show = []
                    for idx in range(qty):
                        s = serials[idx] if idx < len(serials) else {}
                        dev = {
                            'product_id': sim_pid,
                            'serial_number': s.get('serial_number'),
                            'barcode': s.get('barcode'),
                            'status': 'in_storage'
                        }
                        # fallback to record-level purchase dates if individual serial lacks one
                        pd = s.get('purchase_date') or rec.get('PURCHASE_DATE') or rec.get('purchase_date') or rec.get('purchased_at')
                        if pd:
                            dev['purchase_date'] = pd
                        devices_to_show.append(dev)

                    if not args.quiet:
                        print('--- DRY RUN: PRODUCT PAYLOAD ---')
                        print(json.dumps(prod_payload, ensure_ascii=False, indent=2))
                        print('--- DRY RUN: DEVICE PAYLOADS (would be POSTed to /api/v1/admin/devices) ---')
                        for d in devices_to_show[:50]:
                            print(json.dumps(d, ensure_ascii=False, indent=2))
                        if len(devices_to_show) > 50:
                            print(f"... and {len(devices_to_show)-50} more devices")
                else:
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
                    # Populate additional fields from source record when available
                    # Map category name -> category_id using mapping CSV and category_map
                    hirehop_cat = None
                    if 'crumbs' in rec and isinstance(rec['crumbs'], list) and rec['crumbs']:
                        try:
                            hirehop_cat = rec['crumbs'][0].get('NAME')
                        except Exception:
                            pass
                    for ck in ('category', 'product_category', 'CATEGORY', 'CATEGORY_ID'):
                        if not hirehop_cat and ck in rec:
                            hirehop_cat = rec.get(ck)
                    # apply CSV mapping if available
                    mapped_wc_cat = None
                    mapped_wc_sub = None
                    if hirehop_cat:
                        mapped = hirehop_map.get(str(hirehop_cat).strip().lower())
                        if mapped:
                            mapped_wc_cat = mapped.get('category')
                            mapped_wc_sub = mapped.get('subcategory')
                        else:
                            mapped_wc_cat = str(hirehop_cat).strip().title()
                    if mapped_wc_cat:
                        cid = category_map.get(str(mapped_wc_cat).strip().lower())
                        if cid:
                            payload['category_id'] = cid
                        # map subcategory name -> id
                        if mapped_wc_sub:
                            scid = subcategory_map.get(str(mapped_wc_sub).strip().lower())
                            if scid:
                                payload['subcategory_id'] = scid

                    if price:
                        try:
                            pval = float(price)
                            payload['price_per_unit'] = pval
                            # also set item cost per day when reasonable
                            payload['item_cost_per_day'] = pval
                        except Exception:
                            pass

                    # Map dimensions and weight
                    def _maybe_convert_m_to_cm(v):
                        try:
                            fv = float(v)
                        except Exception:
                            return None
                        # Heuristic: values < 10 are likely meters, convert to cm
                        if 0 < fv < 10:
                            return fv * 100
                        return fv

                    try:
                        if 'WEIGHT' in rec and rec['WEIGHT'] not in (None, ''):
                            payload['weight'] = float(rec['WEIGHT'])
                    except Exception:
                        pass
                    try:
                        if 'WIDTH' in rec and rec['WIDTH'] not in (None, ''):
                            w = _maybe_convert_m_to_cm(rec['WIDTH'])
                            if w is not None:
                                payload['width'] = w
                    except Exception:
                        pass
                    try:
                        # HireHop uses LENGTH as depth
                        if 'LENGTH' in rec and rec['LENGTH'] not in (None, ''):
                            d = _maybe_convert_m_to_cm(rec['LENGTH'])
                            if d is not None:
                                payload['depth'] = d
                    except Exception:
                        pass
                    try:
                        if 'HEIGHT' in rec and rec['HEIGHT'] not in (None, ''):
                            h = _maybe_convert_m_to_cm(rec['HEIGHT'])
                            if h is not None:
                                payload['height'] = h
                    except Exception:
                        pass

                    # Manufacturer/brand from custom fields (common key 'tillverkare' or 'manufacturer')
                    def _get_custom_field(r, key):
                        if 'fields' in r and isinstance(r['fields'], dict):
                            v = r['fields'].get(key)
                            if isinstance(v, dict):
                                return v.get('value')
                        return None

                    manu = _get_custom_field(rec, 'tillverkare') or _get_custom_field(rec, 'manufacturer')
                    if manu:
                        mkey = str(manu).strip().lower()
                        mid = manufacturer_map.get(mkey)
                        if not mid:
                            mid = create_or_get_entity(session, args.api_url, 'manufacturers', manu, id_key='manufacturer_id')
                            if mid:
                                manufacturer_map[mkey] = mid
                        if mid:
                            payload['manufacturer_id'] = mid
                    brand = _get_custom_field(rec, 'brand') or _get_custom_field(rec, 'brand_name')
                    # If no explicit brand, fall back to manufacturer name as brand when available
                    if not brand and manu:
                        brand = manu
                    if brand:
                        bkey = str(brand).strip().lower()
                        bid = brand_map.get(bkey)
                        if not bid:
                            bid = create_or_get_entity(session, args.api_url, 'brands', brand, id_key='brand_id')
                            if bid:
                                brand_map[bkey] = bid
                        if bid:
                            payload['brand_id'] = bid
                    try:
                        # Debug: show URL, payload, and redacted session info
                        dbg_url = args.api_url.rstrip('/') + '/api/v1/admin/products'
                        if args.debug:
                            try:
                                ck = session.cookies.get_dict()
                                ck = {k: '***' for k in ck}
                            except Exception:
                                ck = {}
                            redacted_headers = {}
                            for hk, hv in session.headers.items():
                                if hk.lower() in ('authorization', 'cookie'):
                                    redacted_headers[hk] = '***'
                                else:
                                    redacted_headers[hk] = hv
                            print(f"[DEBUG] POST {dbg_url}", file=sys.stderr)
                            print(f"[DEBUG] session.headers: {json.dumps(redacted_headers)}", file=sys.stderr)
                            print(f"[DEBUG] session.cookies: {json.dumps(ck)}", file=sys.stderr)
                            print(f"[DEBUG] payload: {json.dumps(payload, ensure_ascii=False)[:2000]}", file=sys.stderr)
                        r = session.post(dbg_url, json=payload, timeout=30)
                        # detect HTML responses (likely the web UI or an auth redirect)
                        ctype = (r.headers.get('Content-Type') or r.headers.get('content-type') or '').lower()
                        body_start = (r.text or '').lstrip()[:20].lower()
                        if 'html' in ctype or body_start.startswith('<!doctype') or body_start.startswith('<html'):
                            failed.append({"index": record_index + 1, "error": f"product-create-no-json: HTML response (possible auth or wrong endpoint)", "record": rec})
                            # also emit debug info to stderr
                            try:
                                dbg_hdr = dict(r.headers)
                            except Exception:
                                dbg_hdr = {}
                            print(f"[DEBUG] product-create returned HTML for '{product_name}' - status={r.status_code}", file=sys.stderr)
                            print(f"[DEBUG] response-headers: {json.dumps(dbg_hdr)}", file=sys.stderr)
                            print(f"[DEBUG] response-body: {(r.text or '')[:2000]}", file=sys.stderr)
                            continue
                        if r.status_code in (200, 201):
                            # Robustly parse JSON or fallback to Location header / name lookup
                            try:
                                matched_product = r.json()
                            except Exception:
                                loc = r.headers.get('Location') or r.headers.get('location')
                                if loc:
                                    try:
                                        pid = loc.rstrip('/').split('/')[-1]
                                        matched_product = {'product_id': pid, 'id': pid, 'name': product_name}
                                    except Exception:
                                        matched_product = {'name': product_name}
                                else:
                                    matched_product = {'name': product_name}

                            # Ensure matched_product is a dict; if list, take first element
                            if isinstance(matched_product, list) and matched_product:
                                matched_product = matched_product[0]

                            # Helper to extract id from various shapes
                            def _extract_pid(obj):
                                # Robust extraction: check common keys and nested wrappers
                                if isinstance(obj, dict):
                                    for k in ('product_id', 'productID', 'id', 'productId', '_id'):
                                        v = obj.get(k)
                                        if v:
                                            return v
                                    # support nested containers like {'data': {...}} or {'result': {...}}
                                    for wrapper in ('data', 'result', 'payload', 'body'):
                                        if wrapper in obj and isinstance(obj[wrapper], (dict, list)):
                                            return _extract_pid(obj[wrapper])
                                elif isinstance(obj, list) and obj:
                                    return _extract_pid(obj[0])
                                elif isinstance(obj, (str, int)):
                                    return obj
                                return None

                            pid = _extract_pid(matched_product)
                            # If still no pid, try to fetch by name as a last resort
                            if not pid and product_name:
                                try:
                                    # Try a targeted query first
                                    q = {'name': product_name}
                                    rr = session.get(args.api_url.rstrip('/') + '/api/v1/admin/products', params=q, timeout=10)
                                    if rr.status_code == 200:
                                        try:
                                            found = rr.json()
                                            if isinstance(found, list) and found:
                                                # pick the first exact-name match if present
                                                for f in found:
                                                    if isinstance(f, dict) and f.get('name') and f.get('name').strip().lower() == product_name.strip().lower():
                                                        matched_product = f
                                                        pid = _extract_pid(matched_product)
                                                        break
                                                if not pid and isinstance(found[0], dict):
                                                    matched_product = found[0]
                                                    pid = _extract_pid(matched_product)
                                        except Exception:
                                            pass
                                    # If still not found, fetch entire list and attempt exact match
                                    if not pid:
                                        try:
                                            rr = session.get(args.api_url.rstrip('/') + '/api/v1/admin/products', timeout=20)
                                            if rr.status_code == 200:
                                                try:
                                                    allp = rr.json()
                                                    if isinstance(allp, list):
                                                        for f in allp:
                                                            if isinstance(f, dict) and f.get('name') and f.get('name').strip().lower() == product_name.strip().lower():
                                                                matched_product = f
                                                                pid = _extract_pid(matched_product)
                                                                break
                                                except Exception:
                                                    pass
                                        except Exception:
                                            pass
                                except Exception:
                                    pass

                            # Attach the resolved pid if available (normalize to int when possible)
                            if pid and isinstance(matched_product, dict):
                                try:
                                    # convert numeric strings to int
                                    if isinstance(pid, str) and pid.isdigit():
                                        pid_val = int(pid)
                                    else:
                                        pid_val = int(pid) if isinstance(pid, (int, float, str)) and str(pid).isdigit() else pid
                                except Exception:
                                    pid_val = pid
                                matched_product['product_id'] = pid_val
                                matched_product['id'] = pid_val

                            # If we still don't have a pid, log details for debugging and include headers/body
                            if not (matched_product.get('product_id') or matched_product.get('id')):
                                try:
                                    dbg_txt = r.text
                                except Exception:
                                    dbg_txt = '<no-body>'
                                try:
                                    dbg_hdr = dict(r.headers)
                                except Exception:
                                    dbg_hdr = {}
                                # write minimal debug info to stderr so user can inspect
                                print(f"[DEBUG] product-create missing id for '{product_name}' - status={r.status_code}", file=sys.stderr)
                                print(f"[DEBUG] response-headers: {json.dumps(dbg_hdr)}", file=sys.stderr)
                                print(f"[DEBUG] response-body: {dbg_txt[:2000]}", file=sys.stderr)
                            existing_products.append(matched_product)
                            if not args.quiet:
                                display = matched_product.get('product_id') or matched_product.get('id') or matched_product.get('name')
                                print(f"Created product: {display}")
                        else:
                            failed.append({"index": record_index + 1, "error": f"product-create {r.status_code}: {r.text}", "record": rec})
                            continue
                    except Exception as e:
                        failed.append({"index": record_index + 1, "error": f"product-create-exc: {e}", "record": rec})
                        continue

                # create devices from serialnumbers and ensure QTY
                # Robustly extract serial entries supporting multiple shapes
                serials = []
                if 'serialnumbers' in rec and isinstance(rec['serialnumbers'], list):
                    for s in rec['serialnumbers']:
                        serial = None
                        barcode = None
                        purchase_date = None
                        if isinstance(s, dict):
                            cell = s.get('cell') or s
                            if isinstance(cell, dict):
                                serial = cell.get('SERIAL') or cell.get('serial') or cell.get('serial_number') or cell.get('id')
                                barcode = cell.get('BARCODE') or cell.get('barcode')
                                purchase_date = cell.get('PURCHASE_DATE') or cell.get('purchase_date')
                            else:
                                serial = str(cell)
                        else:
                            serial = str(s)
                        serials.append({
                            'barcode': barcode,
                            'serial_number': str(serial) if serial is not None else None,
                            'purchase_date': purchase_date,
                        })

                # determine qty; fall back to number of serials or 1
                qty = None
                for k in ('QTY', 'qty', 'quantity', 'count'):
                    if k in rec and rec[k] is not None:
                        try:
                            qty = int(rec[k])
                        except Exception:
                            pass
                        break
                if not qty:
                    qty = len(serials) or 1

                pid = matched_product.get('product_id') or matched_product.get('id') if matched_product else None
                if not pid:
                    failed.append({"index": record_index + 1, "error": "no-product-id", "record": rec})
                    continue

                # whitelist of device fields expected by WarehouseCore API
                allowed_device_fields = ('product_id', 'serial_number', 'barcode', 'status', 'purchase_date', 'purchase_price', 'notes', 'location')

                for idx in range(qty):
                    s = serials[idx] if idx < len(serials) else {}
                    dev_payload = {
                        'product_id': pid,
                        'serial_number': s.get('serial_number'),
                        'barcode': s.get('barcode'),
                        'status': 'in_storage'
                    }
                    # prefer serial-level purchase date, fallback to record-level
                    pd = s.get('purchase_date') or rec.get('PURCHASE_DATE') or rec.get('purchase_date') or rec.get('purchased_at')
                    if pd:
                        dev_payload['purchase_date'] = pd

                    # Filter payload to allowed fields only
                    dev_payload = {k: v for k, v in dev_payload.items() if k in allowed_device_fields}

                    ok, info = post_record(session, target, dev_payload, args.quiet)
                    if ok:
                        devices_created += 1
                    else:
                        failed.append({"index": record_index + 1, "error": info, "record": dev_payload})
                records_processed += 1
                # small delay to avoid spamming the API
                time.sleep(0.05)
                continue

            # Default behavior: post to target endpoint
            ok, info = post_record(session, target, rec, args.quiet)
            if ok:
                success += 1
                if not args.quiet:
                    print(f"[{record_index+1}/{total}] OK")
            else:
                failed.append({"index": record_index + 1, "error": info, "record": rec})
                print(f"[{record_index+1}/{total}] FAILED: {info}")

            # small delay to avoid spamming the API
            time.sleep(0.05)

    print("---")
    if args.auto_create:
        print(f"Input records: {total}, Records processed: {records_processed}, Devices created: {devices_created}, Failed: {len(failed)}")
    else:
        print(f"Total: {total}, Successful: {success}, Failed: {len(failed)}")
    if failed:
        print("Failed items (first 10):")
        for f in failed[:10]:
            print(json.dumps(f, ensure_ascii=False))


if __name__ == '__main__':
    main()
