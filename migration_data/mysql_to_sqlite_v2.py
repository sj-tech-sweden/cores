#!/usr/bin/env python3
"""Convert MySQL dump to SQLite compatible SQL - V2"""
import re
import sys

def convert_mysql_to_sqlite(mysql_sql):
    lines = []
    in_create = False
    current_table = ""
    
    for line in mysql_sql.split('\n'):
        # Skip mysqldump header/comments
        if line.startswith('--') or line.startswith('/*') or line.startswith('SET ') or 'mysqldump' in line.lower():
            continue
        if line.startswith('LOCK TABLES') or line.startswith('UNLOCK TABLES'):
            continue
        if '/*!40' in line or '/*!50' in line:
            continue
        if line.strip() == '':
            continue
            
        lines.append(line)
    
    sql = '\n'.join(lines)
    
    # Remove backticks
    sql = sql.replace('`', '"')
    
    # Convert data types
    type_conversions = [
        (r'\bINT\(\d+\)\s+UNSIGNED', 'INTEGER'),
        (r'\bINT\(\d+\)', 'INTEGER'),
        (r'\bINT\b', 'INTEGER'),
        (r'\bTINYINT\(\d+\)\s+UNSIGNED', 'INTEGER'),
        (r'\bTINYINT\(\d+\)', 'INTEGER'),
        (r'\bTINYINT\b', 'INTEGER'),
        (r'\bSMALLINT\(\d+\)', 'INTEGER'),
        (r'\bSMALLINT\b', 'INTEGER'),
        (r'\bMEDIUMINT\(\d+\)', 'INTEGER'),
        (r'\bMEDIUMINT\b', 'INTEGER'),
        (r'\bBIGINT\(\d+\)\s+UNSIGNED', 'INTEGER'),
        (r'\bBIGINT\(\d+\)', 'INTEGER'),
        (r'\bBIGINT\b', 'INTEGER'),
        (r'\bDOUBLE\b', 'REAL'),
        (r'\bFLOAT\b', 'REAL'),
        (r'\bDECIMAL\([^)]+\)', 'REAL'),
        (r'\bDATETIME\b', 'TEXT'),
        (r'\bTIMESTAMP\b', 'TEXT'),
        (r'\bDATE\b', 'TEXT'),
        (r'\bTIME\b', 'TEXT'),
        (r'\bYEAR\b', 'INTEGER'),
        (r'\bLONGTEXT\b', 'TEXT'),
        (r'\bMEDIUMTEXT\b', 'TEXT'),
        (r'\bTINYTEXT\b', 'TEXT'),
        (r'\bVARCHAR\(\d+\)', 'TEXT'),
        (r'\bCHAR\(\d+\)', 'TEXT'),
        (r'\bLONGBLOB\b', 'BLOB'),
        (r'\bMEDIUMBLOB\b', 'BLOB'),
        (r'\bTINYBLOB\b', 'BLOB'),
        (r'\bJSON\b', 'TEXT'),
        (r"ENUM\([^)]+\)", 'TEXT'),
    ]
    
    for pattern, replacement in type_conversions:
        sql = re.sub(pattern, replacement, sql, flags=re.IGNORECASE)
    
    # Remove UNSIGNED
    sql = re.sub(r'\s+UNSIGNED', '', sql, flags=re.IGNORECASE)
    
    # Remove AUTO_INCREMENT
    sql = re.sub(r'\s+AUTO_INCREMENT', '', sql, flags=re.IGNORECASE)
    
    # Remove ON UPDATE CURRENT_TIMESTAMP
    sql = re.sub(r'\s+ON\s+UPDATE\s+CURRENT_TIMESTAMP', '', sql, flags=re.IGNORECASE)
    
    # Convert DEFAULT CURRENT_TIMESTAMP
    sql = re.sub(r"DEFAULT\s+CURRENT_TIMESTAMP", "DEFAULT CURRENT_TIMESTAMP", sql, flags=re.IGNORECASE)
    
    # Remove COLLATE
    sql = re.sub(r'\s+COLLATE\s+\w+', '', sql, flags=re.IGNORECASE)
    sql = re.sub(r'\s+CHARACTER\s+SET\s+\w+', '', sql, flags=re.IGNORECASE)
    sql = re.sub(r'\s+COMMENT\s+\'[^\']*\'', '', sql, flags=re.IGNORECASE)
    
    # Remove KEY definitions
    sql = re.sub(r',\s*KEY\s+"[^"]+"\s*\([^)]+\)\s*', '', sql, flags=re.IGNORECASE)
    sql = re.sub(r',\s*UNIQUE\s+KEY\s+"[^"]+"\s*\([^)]+\)\s*', '', sql, flags=re.IGNORECASE)
    sql = re.sub(r',\s*FULLTEXT\s+KEY\s+"[^"]+"\s*\([^)]+\)\s*', '', sql, flags=re.IGNORECASE)
    
    # Remove CONSTRAINT ... FOREIGN KEY - BUT keep in multi-line scenarios
    sql = re.sub(r',?\s*CONSTRAINT\s+"[^"]+"\s+FOREIGN\s+KEY\s*\([^)]+\)\s*REFERENCES\s+"[^"]+"\s*\([^)]+\)[^,)]*', '', sql, flags=re.IGNORECASE)
    
    # Remove stray REFERENCES after PRIMARY KEY
    sql = re.sub(r'\)\s*REFERENCES\s+"[^"]+"\s*\([^)]+\)[^;]*;', ');', sql, flags=re.IGNORECASE)
    
    # Remove USING BTREE
    sql = re.sub(r'\s+USING\s+BTREE', '', sql, flags=re.IGNORECASE)
    
    # Remove ENGINE=... and everything after
    sql = re.sub(r'\)\s*ENGINE\s*=\s*\w+[^;]*;', ');', sql, flags=re.IGNORECASE)
    
    # Fix boolean defaults
    sql = re.sub(r"DEFAULT\s+'0'", "DEFAULT 0", sql)
    sql = re.sub(r"DEFAULT\s+'1'", "DEFAULT 1", sql)
    
    # Clean up multiple commas before closing parenthesis
    sql = re.sub(r',\s*\)', ')', sql)
    
    return sql

if __name__ == '__main__':
    input_file = sys.argv[1] if len(sys.argv) > 1 else 'schema_only.sql'
    output_file = sys.argv[2] if len(sys.argv) > 2 else 'schema_sqlite.sql'
    
    with open(input_file, 'r') as f:
        mysql_sql = f.read()
    
    sqlite_sql = convert_mysql_to_sqlite(mysql_sql)
    
    with open(output_file, 'w') as f:
        f.write(sqlite_sql)
    
    print(f"Converted {input_file} -> {output_file}")
