#!/usr/bin/env python3
import json
import os
from pathlib import Path


def load_json(path):
    if not path.exists():
        return {}
    with open(path, 'r', encoding='utf-8') as f:
        return json.load(f)


def save_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2, sort_keys=True)


def merge_dicts(en, de):
    # Recursively ensure both dicts have same keys.
    keys = set(en.keys()) | set(de.keys())
    out_en = {}
    out_de = {}
    for k in sorted(keys):
        ve = en.get(k)
        vd = de.get(k)
        if isinstance(ve, dict) or isinstance(vd, dict):
            ve = ve or {}
            vd = vd or {}
            me, md = merge_dicts(ve, vd)
            out_en[k] = me
            out_de[k] = md
        else:
            # Fill English first: prefer existing English, else use German, else empty string
            if ve is None:
                ve = vd if vd is not None else ""
            # Fill German: prefer existing German, else use English (now filled), else empty
            if vd is None:
                vd = ve if ve is not None else ""
            out_en[k] = ve
            out_de[k] = vd
    return out_en, out_de


def process_locale_dir(dir_path):
    dirp = Path(dir_path)
    en_path = dirp / 'en.json'
    de_path = dirp / 'de.json'

    en = load_json(en_path)
    de = load_json(de_path)

    merged_en, merged_de = merge_dicts(en, de)

    save_json(en_path, merged_en)
    save_json(de_path, merged_de)
    print(f'Merged locales in {dirp}')


def main():
    repo_root = Path(__file__).resolve().parents[1]
    targets = [
        repo_root / 'rentalcore' / 'web' / 'static' / 'locales',
        repo_root / 'warehousecore' / 'web' / 'src' / 'locales',
    ]

    for t in targets:
        if t.exists():
            process_locale_dir(t)
        else:
            print(f'Skipping missing locale dir: {t}')


if __name__ == '__main__':
    main()
