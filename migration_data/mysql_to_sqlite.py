#!/usr/bin/env python3
"""Convert MySQL dump to SQLite compatible SQL"""
import re
import sys

def convert_mysql_to_sqlite(mysql_sql):
    # Remove MySQL-specific settings
    lines = []
    skip_block = False
    
    for line in mysql_sql.split('\n'):
        # Skip comments and settings
        if line.startswith('--') or line.startswith('/*') or line.startswith('SET ') or line.startswith('LOCK TABLES') or line.startswith('UNLOCK TABLES'):
            continue
        if '/*!40' in line or '/*!50' in line:
            continue
        if line.strip() == '':
            continue
            
        lines.append(line)
    
    sql = '\n'.join(lines)
    
    # Convert CREATE TABLE
    sql = re.sub(r'CREATE TABLE IF NOT EXISTS', 'CREATE TABLE IF NOT EXISTS', sql)
    sql = re.sub(r'CREATE TABLE `', 'CREATE TABLE IF NOT EXISTS `', sql)
    
    # Remove backticks (SQLite uses double quotes or nothing)
    sql = sql.replace('`', '"')
    
    # Convert data types
    sql = re.sub(r'\bINT\(\d+\)', 'INTEGER', sql, flags=re.IGNORECASE)
    sql = re.sub(r'\bINT\b', 'INTEGER', sql, flags=re.IGNORECASE)
    sql = re.sub(r'\bTINYINT\(\d+\)', 'INTEGER', sql, flags=re.IGNORECASE)
    sql = re.sub(r'\bTINYINT\b', 'INTEGER', sql, flags=re.IGNORECASE)
    sql = re.sub(r'\bSMALLINT\(\d+\)', 'INTEGER', sql, flags=re.IGNORECASE)
    sql = re.sub(r'\bSMALLINT\b', 'INTEGER', sql, flags=re.IGNORECASE)
    sql = re.sub(r'\bMEDIUMINT\(\d+\)', 'INTEGER', sql, flags=re.IGNORECASE)
    sql = re.sub(r'\bMEDIUMINT\b', 'INTEGER', sql, flags=re.IGNORECASE)
    sql = re.sub(r'\bBIGINT\(\d+\)', 'INTEGER', sql, flags=re.IGNORECASE)
    sql = re.sub(r'\bBIGINT\b', 'INTEGER', sql, flags=re.IGNORECASE)
    sql = re.sub(r'\bDOUBLE\b', 'REAL', sql, flags=re.IGNORECASE)
    sql = re.sub(r'\bFLOAT\b', 'REAL', sql, flags=re.IGNORECASE)
    sql = re.sub(r'\bDECIMAL\([^)]+\)', 'REAL', sql, flags=re.IGNORECASE)
    sql = re.sub(r'\bDATETIME\b', 'TEXT', sql, flags=re.IGNORECASE)
    sql = re.sub(r'\bTIMESTAMP\b', 'TEXT', sql, flags=re.IGNORECASE)
    sql = re.sub(r'\bDATE\b', 'TEXT', sql, flags=re.IGNORECASE)
    sql = re.sub(r'\bTIME\b', 'TEXT', sql, flags=re.IGNORECASE)
    sql = re.sub(r'\bYEAR\b', 'INTEGER', sql, flags=re.IGNORECASE)
    sql = re.sub(r'\bLONGTEXT\b', 'TEXT', sql, flags=re.IGNORECASE)
    sql = re.sub(r'\bMEDIUMTEXT\b', 'TEXT', sql, flags=re.IGNORECASE)
    sql = re.sub(r'\bTINYTEXT\b', 'TEXT', sql, flags=re.IGNORECASE)
    sql = re.sub(r'\bVARCHAR\(\d+\)', 'TEXT', sql, flags=re.IGNORECASE)
    sql = re.sub(r'\bCHAR\(\d+\)', 'TEXT', sql, flags=re.IGNORECASE)
    sql = re.sub(r'\bLONGBLOB\b', 'BLOB', sql, flags=re.IGNORECASE)
    sql = re.sub(r'\bMEDIUMBLOB\b', 'BLOB', sql, flags=re.IGNORECASE)
    sql = re.sub(r'\bTINYBLOB\b', 'BLOB', sql, flags=re.IGNORECASE)
    sql = re.sub(r'\bJSON\b', 'TEXT', sql, flags=re.IGNORECASE)
    
    # Convert ENUM to TEXT
    sql = re.sub(r"ENUM\([^)]+\)", 'TEXT', sql, flags=re.IGNORECASE)
    
    # Remove UNSIGNED
    sql = re.sub(r'\s+UNSIGNED', '', sql, flags=re.IGNORECASE)
    
    # Remove AUTO_INCREMENT from column definition (SQLite uses AUTOINCREMENT differently)
    sql = re.sub(r'\s+AUTO_INCREMENT', '', sql, flags=re.IGNORECASE)
    
    # Remove ENGINE, CHARSET, COLLATE clauses
    sql = re.sub(r'\)\s*ENGINE\s*=\s*\w+[^;]*;', ');', sql, flags=re.IGNORECASE)
    sql = re.sub(r'\s+DEFAULT\s+CHARSET\s*=\s*\w+', '', sql, flags=re.IGNORECASE)
    sql = re.sub(r'\s+COLLATE\s*=?\s*\w+', '', sql, flags=re.IGNORECASE)
    sql = re.sub(r'\s+CHARACTER\s+SET\s+\w+', '', sql, flags=re.IGNORECASE)
    sql = re.sub(r'\s+COMMENT\s+\'[^\']*\'', '', sql, flags=re.IGNORECASE)
    
    # Remove KEY definitions (we'll add indexes separately)
    sql = re.sub(r',\s*KEY\s+"[^"]+"\s*\([^)]+\)', '', sql, flags=re.IGNORECASE)
    sql = re.sub(r',\s*UNIQUE\s+KEY\s+"[^"]+"\s*\([^)]+\)', '', sql, flags=re.IGNORECASE)
    sql = re.sub(r',\s*FULLTEXT\s+KEY\s+"[^"]+"\s*\([^)]+\)', '', sql, flags=re.IGNORECASE)
    
    # Convert ON UPDATE CURRENT_TIMESTAMP
    sql = re.sub(r'\s+ON\s+UPDATE\s+CURRENT_TIMESTAMP', '', sql, flags=re.IGNORECASE)
    
    # Convert DEFAULT CURRENT_TIMESTAMP
    sql = re.sub(r"DEFAULT\s+CURRENT_TIMESTAMP", "DEFAULT (datetime('now'))", sql, flags=re.IGNORECASE)
    
    # Fix boolean defaults
    sql = re.sub(r"DEFAULT\s+'0'", "DEFAULT 0", sql)
    sql = re.sub(r"DEFAULT\s+'1'", "DEFAULT 1", sql)
    
    # Remove empty CONSTRAINT clauses
    sql = re.sub(r',\s*CONSTRAINT\s+"[^"]+"\s+FOREIGN KEY[^,)]+', '', sql, flags=re.IGNORECASE)
    
    # Clean up double quotes in INSERT statements
    sql = sql.replace('\\"', "''")
    
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
