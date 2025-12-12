import re
import sys

def convert_mysql_to_sqlite(input_file, output_file):
    with open(input_file, 'r', encoding='utf-8', errors='replace') as f:
        content = f.read()
    
    # Entferne MySQL-spezifische Befehle
    content = re.sub(r'^SET .*?;$', '', content, flags=re.MULTILINE | re.IGNORECASE)
    content = re.sub(r'^set autocommit.*?;$', '', content, flags=re.MULTILINE | re.IGNORECASE)
    content = re.sub(r'^commit;$', '', content, flags=re.MULTILINE | re.IGNORECASE)
    content = re.sub(r'^LOCK TABLES.*?;$', '', content, flags=re.MULTILINE | re.IGNORECASE)
    content = re.sub(r'^UNLOCK TABLES.*?;$', '', content, flags=re.MULTILINE | re.IGNORECASE)
    content = re.sub(r'^/\*!.*?\*/;$', '', content, flags=re.MULTILINE)
    
    # Konvertiere Backticks zu Anführungszeichen
    content = content.replace('`', '"')
    
    # Konvertiere MySQL escaped quotes \' zu SQLite ''
    # Aber NUR innerhalb von Strings, nicht am Anfang
    lines = []
    for line in content.split('\n'):
        if line.strip().startswith('INSERT INTO'):
            # Ersetze backslash-escaped quotes mit double quotes
            # \' -> ''
            new_line = line.replace("\\'", "''")
            lines.append(new_line)
        else:
            lines.append(line)
    
    content = '\n'.join(lines)
    
    # Entferne leere Zeilen
    content = re.sub(r'\n{3,}', '\n\n', content)
    
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"Converted {input_file} -> {output_file}")

if __name__ == "__main__":
    convert_mysql_to_sqlite(sys.argv[1], sys.argv[2])
