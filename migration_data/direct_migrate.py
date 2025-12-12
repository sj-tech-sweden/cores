#!/usr/bin/env python3
import mysql.connector
import sqlite3
from decimal import Decimal
from datetime import date, datetime

# MySQL Verbindung
mysql_conn = mysql.connector.connect(
    host="tsunami-events.de",
    port=3306,
    user="tsweb",
    password="j4z4mZv7DpG7cdCLkSQVjXCfXMOmt9dEGRp2Pmdn2Xzl5y8AAkwLmKX",
    database="RentalCore",
    ssl_disabled=True
)

# SQLite Verbindung
sqlite_conn = sqlite3.connect('/opt/dev/cores/migration_data/rentalcore_new.db')
sqlite_conn.execute("PRAGMA journal_mode=WAL")
sqlite_conn.execute("PRAGMA busy_timeout=5000")
sqlite_conn.execute("PRAGMA foreign_keys=OFF")

def convert_value(val):
    """Konvertiere MySQL-Typen zu SQLite-kompatiblen"""
    if val is None:
        return None
    if isinstance(val, Decimal):
        return float(val)
    if isinstance(val, (date, datetime)):
        return val.isoformat()
    if isinstance(val, bytes):
        return val.decode('utf-8', errors='replace')
    return val

def convert_row(row):
    """Konvertiere komplette Zeile"""
    return tuple(convert_value(v) for v in row)

# Tabellen die migriert werden sollen
tables = [
    'devices', 'cables', 'products', 'customers', 'jobs', 'jobdevices',
    'categories', 'subcategories', 'subbiercategories', 'brands', 'manufacturer',
    'cases', 'devicescases', 'cable_connectors', 'cable_types', 'status',
    'users', 'roles', 'user_roles', 'user_profiles', 'employee', 'employeejob',
    'storage_zones', 'zone_types', 'led_controllers', 'led_controller_zone_types',
    'product_packages', 'product_package_items', 'package_devices', 'package_categories',
    'job_attachments', 'job_history', 'job_packages', 'jobCategory', 'device_movements',
    'app_settings', 'company_settings', 'invoice_settings', 'invoice_templates',
    'email_templates', 'label_templates', 'retention_policies', 'count_types',
    'documents', 'insuranceprovider', 'insurances', 'rental_equipment', 'equipment_packages',
    'api_keys', 'invoices', 'invoice_line_items'
]

mysql_cursor = mysql_conn.cursor()
sqlite_cursor = sqlite_conn.cursor()

total_rows = 0

for table in tables:
    try:
        # Hole alle Daten
        mysql_cursor.execute(f"SELECT * FROM `{table}`")
        rows = mysql_cursor.fetchall()
        
        if len(rows) == 0:
            print(f"  {table}: LEER")
            continue
        
        # Hole Spalteninformationen aus MySQL
        mysql_columns = [desc[0] for desc in mysql_cursor.description]
        
        # Hole SQLite Spalten
        sqlite_cursor.execute(f'PRAGMA table_info("{table}")')
        sqlite_cols = [row[1] for row in sqlite_cursor.fetchall()]
        
        # Finde gemeinsame Spalten
        common_cols = [c for c in mysql_columns if c in sqlite_cols]
        common_indices = [mysql_columns.index(c) for c in common_cols]
        
        # Erstelle SQLite Insert
        placeholders = ','.join(['?' for _ in common_cols])
        cols_quoted = ','.join([f'"{c}"' for c in common_cols])
        
        insert_sql = f'INSERT OR REPLACE INTO "{table}" ({cols_quoted}) VALUES ({placeholders})'
        
        # Konvertiere und filtere Rows
        converted_rows = []
        for row in rows:
            filtered_row = tuple(convert_value(row[i]) for i in common_indices)
            converted_rows.append(filtered_row)
        
        # Insert in SQLite
        sqlite_cursor.executemany(insert_sql, converted_rows)
        sqlite_conn.commit()
        
        total_rows += len(rows)
        print(f"  {table}: {len(rows)} Zeilen")
        
    except Exception as e:
        print(f"  {table}: FEHLER - {str(e)[:80]}")

print(f"\n=== TOTAL: {total_rows} Zeilen migriert ===")

mysql_conn.close()
sqlite_conn.close()
