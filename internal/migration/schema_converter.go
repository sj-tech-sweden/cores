// Package migration - Schema-Konvertierung von MySQL zu SQLite
package migration

import (
	"fmt"
	"regexp"
	"strings"
)

// SchemaConverter konvertiert MySQL-Schema zu SQLite
type SchemaConverter struct {
	// Optionen
	PreserveTriggers bool
	AddIfNotExists   bool
}

// NewSchemaConverter erstellt einen neuen Konverter
func NewSchemaConverter() *SchemaConverter {
	return &SchemaConverter{
		AddIfNotExists: true,
	}
}

// ConvertCreateTable konvertiert ein MySQL CREATE TABLE Statement
func (sc *SchemaConverter) ConvertCreateTable(mysqlSQL string) (string, error) {
	// Entferne MySQL-spezifische Kommentare
	sql := sc.removeMySQLComments(mysqlSQL)

	// Extrahiere Tabellenname
	tableNameRe := regexp.MustCompile(`CREATE TABLE\s+` + "`?" + `([^` + "`" + `\s(]+)` + "`?" + `\s*\(`)
	matches := tableNameRe.FindStringSubmatch(sql)
	if len(matches) < 2 {
		return "", fmt.Errorf("konnte Tabellennamen nicht finden")
	}
	tableName := matches[1]

	// Konvertiere Spalten und Constraints
	sql = sc.convertColumnTypes(sql)
	sql = sc.convertAutoIncrement(sql)
	sql = sc.convertDefaultValues(sql)
	sql = sc.removeEngineAndCharset(sql)
	sql = sc.convertOnUpdateTimestamp(sql)

	// IF NOT EXISTS hinzufügen
	if sc.AddIfNotExists && !strings.Contains(strings.ToUpper(sql), "IF NOT EXISTS") {
		sql = strings.Replace(sql, "CREATE TABLE", "CREATE TABLE IF NOT EXISTS", 1)
	}

	// Formatieren
	sql = sc.formatSQL(sql)

	_ = tableName // für spätere Verwendung
	return sql, nil
}

// ConvertCreateIndex konvertiert ein MySQL CREATE INDEX Statement
func (sc *SchemaConverter) ConvertCreateIndex(mysqlSQL string) string {
	sql := mysqlSQL

	// Entferne USING BTREE/HASH
	sql = regexp.MustCompile(`\s+USING\s+(BTREE|HASH)`).ReplaceAllString(sql, "")

	// Entferne Kommentar
	sql = regexp.MustCompile(`\s+COMMENT\s+'[^']*'`).ReplaceAllString(sql, "")

	// IF NOT EXISTS hinzufügen
	if sc.AddIfNotExists && !strings.Contains(strings.ToUpper(sql), "IF NOT EXISTS") {
		sql = strings.Replace(sql, "CREATE INDEX", "CREATE INDEX IF NOT EXISTS", 1)
		sql = strings.Replace(sql, "CREATE UNIQUE INDEX", "CREATE UNIQUE INDEX IF NOT EXISTS", 1)
	}

	return sql
}

// ConvertTrigger konvertiert einen MySQL-Trigger zu SQLite
func (sc *SchemaConverter) ConvertTrigger(mysqlTrigger string) string {
	sql := mysqlTrigger

	// DELIMITER entfernen
	sql = regexp.MustCompile(`DELIMITER\s+\S+\s*`).ReplaceAllString(sql, "")

	// FOR EACH ROW hinzufügen wenn nicht vorhanden
	if !strings.Contains(strings.ToUpper(sql), "FOR EACH ROW") {
		sql = strings.Replace(sql, "BEGIN", "FOR EACH ROW BEGIN", 1)
	}

	// SET @var = ... zu SQLite-kompatibel
	sql = regexp.MustCompile(`SET\s+@(\w+)\s*=\s*([^;]+);`).ReplaceAllString(sql, "-- SET @$1 = $2; /* Variable nicht unterstützt */")

	// NEW.column und OLD.column sind in SQLite gleich
	// Keine Änderung nötig

	return sql
}

// =============================================================================
// Interne Konvertierungsfunktionen
// =============================================================================

func (sc *SchemaConverter) removeMySQLComments(sql string) string {
	// Entferne /*!40xxx ... */ MySQL-spezifische Kommentare
	sql = regexp.MustCompile(`/\*!\d+\s+[^*]*\*/`).ReplaceAllString(sql, "")
	sql = regexp.MustCompile(`/\*!\d+\s*`).ReplaceAllString(sql, "")
	sql = regexp.MustCompile(`\*/`).ReplaceAllString(sql, "")

	return sql
}

func (sc *SchemaConverter) convertColumnTypes(sql string) string {
	replacements := []struct {
		pattern     string
		replacement string
	}{
		// Integer-Typen
		{`\bTINYINT\(\d+\)(\s+UNSIGNED)?`, "INTEGER"},
		{`\bSMALLINT\(\d+\)(\s+UNSIGNED)?`, "INTEGER"},
		{`\bMEDIUMINT\(\d+\)(\s+UNSIGNED)?`, "INTEGER"},
		{`\bINT\(\d+\)(\s+UNSIGNED)?`, "INTEGER"},
		{`\bBIGINT\(\d+\)(\s+UNSIGNED)?`, "INTEGER"},
		{`\bTINYINT(\s+UNSIGNED)?`, "INTEGER"},
		{`\bSMALLINT(\s+UNSIGNED)?`, "INTEGER"},
		{`\bMEDIUMINT(\s+UNSIGNED)?`, "INTEGER"},
		{`\bINT(\s+UNSIGNED)?`, "INTEGER"},
		{`\bBIGINT(\s+UNSIGNED)?`, "INTEGER"},

		// Dezimal-Typen
		{`\bDECIMAL\([^)]+\)`, "REAL"},
		{`\bNUMERIC\([^)]+\)`, "REAL"},
		{`\bFLOAT(\([^)]+\))?`, "REAL"},
		{`\bDOUBLE(\([^)]+\))?`, "REAL"},
		{`\bREAL(\([^)]+\))?`, "REAL"},

		// String-Typen
		{`\bVARCHAR\(\d+\)`, "TEXT"},
		{`\bCHAR\(\d+\)`, "TEXT"},
		{`\bTINYTEXT`, "TEXT"},
		{`\bMEDIUMTEXT`, "TEXT"},
		{`\bLONGTEXT`, "TEXT"},
		{`\bTEXT`, "TEXT"},

		// ENUM und SET zu TEXT
		{`\bENUM\([^)]+\)`, "TEXT"},
		{`\bSET\([^)]+\)`, "TEXT"},

		// JSON zu TEXT
		{`\bJSON\b`, "TEXT"},

		// Datum/Zeit zu TEXT
		{`\bDATETIME(\(\d+\))?`, "TEXT"},
		{`\bTIMESTAMP(\(\d+\))?`, "TEXT"},
		{`\bDATE\b`, "TEXT"},
		{`\bTIME(\(\d+\))?`, "TEXT"},
		{`\bYEAR(\(\d+\))?`, "TEXT"},

		// Binär-Typen
		{`\bTINYBLOB`, "BLOB"},
		{`\bMEDIUMBLOB`, "BLOB"},
		{`\bLONGBLOB`, "BLOB"},
		{`\bBLOB`, "BLOB"},
		{`\bBINARY\(\d+\)`, "BLOB"},
		{`\bVARBINARY\(\d+\)`, "BLOB"},

		// Boolean
		{`\bBOOL(EAN)?`, "INTEGER"},
	}

	for _, r := range replacements {
		re := regexp.MustCompile("(?i)" + r.pattern)
		sql = re.ReplaceAllString(sql, r.replacement)
	}

	return sql
}

func (sc *SchemaConverter) convertAutoIncrement(sql string) string {
	// AUTO_INCREMENT zu AUTOINCREMENT
	sql = regexp.MustCompile(`(?i)\bAUTO_INCREMENT`).ReplaceAllString(sql, "AUTOINCREMENT")

	// PRIMARY KEY AUTOINCREMENT - SQLite benötigt spezielle Syntax
	// INTEGER PRIMARY KEY AUTOINCREMENT
	// Bereits korrekt wenn Typ zu INTEGER konvertiert wurde

	return sql
}

func (sc *SchemaConverter) convertDefaultValues(sql string) string {
	// CURRENT_TIMESTAMP bleibt
	// NOW() zu datetime('now')
	sql = regexp.MustCompile(`(?i)\bNOW\(\)`).ReplaceAllString(sql, "(datetime('now'))")

	// CURDATE() zu date('now')
	sql = regexp.MustCompile(`(?i)\bCURDATE\(\)`).ReplaceAllString(sql, "(date('now'))")

	// ON UPDATE CURRENT_TIMESTAMP entfernen (wird als Trigger behandelt)
	sql = regexp.MustCompile(`(?i)\s+ON\s+UPDATE\s+CURRENT_TIMESTAMP(\(\d*\))?`).ReplaceAllString(sql, "")

	return sql
}

func (sc *SchemaConverter) removeEngineAndCharset(sql string) string {
	// ENGINE=InnoDB entfernen
	sql = regexp.MustCompile(`(?i)\s*ENGINE\s*=\s*\w+`).ReplaceAllString(sql, "")

	// DEFAULT CHARSET entfernen
	sql = regexp.MustCompile(`(?i)\s*DEFAULT\s+CHARSET\s*=\s*\w+`).ReplaceAllString(sql, "")
	sql = regexp.MustCompile(`(?i)\s*CHARACTER\s+SET\s*=?\s*\w+`).ReplaceAllString(sql, "")

	// COLLATE entfernen
	sql = regexp.MustCompile(`(?i)\s*COLLATE\s*=?\s*\w+`).ReplaceAllString(sql, "")

	// ROW_FORMAT entfernen
	sql = regexp.MustCompile(`(?i)\s*ROW_FORMAT\s*=\s*\w+`).ReplaceAllString(sql, "")

	// COMMENT entfernen
	sql = regexp.MustCompile(`(?i)\s*COMMENT\s*=?\s*'[^']*'`).ReplaceAllString(sql, "")

	// AUTO_INCREMENT=n am Ende entfernen
	sql = regexp.MustCompile(`(?i)\s*AUTO_INCREMENT\s*=\s*\d+`).ReplaceAllString(sql, "")

	return sql
}

func (sc *SchemaConverter) convertOnUpdateTimestamp(sql string) string {
	// ON UPDATE wird in SQLite als Trigger implementiert
	// Hier entfernen wir es nur
	return sql
}

func (sc *SchemaConverter) formatSQL(sql string) string {
	// Mehrfache Leerzeichen reduzieren
	sql = regexp.MustCompile(`\s+`).ReplaceAllString(sql, " ")

	// Leerzeichen vor/nach Klammern
	sql = strings.ReplaceAll(sql, "( ", "(")
	sql = strings.ReplaceAll(sql, " )", ")")

	// Leerzeichen vor Komma entfernen
	sql = strings.ReplaceAll(sql, " ,", ",")

	// Zeilenumbrüche nach Spalten hinzufügen
	sql = strings.ReplaceAll(sql, ", ", ",\n  ")

	// Trim
	sql = strings.TrimSpace(sql)

	return sql
}

// =============================================================================
// Trigger-Generator für ON UPDATE CURRENT_TIMESTAMP
// =============================================================================

// GenerateUpdateTimestampTrigger erstellt einen Trigger für ON UPDATE CURRENT_TIMESTAMP
func GenerateUpdateTimestampTrigger(tableName, columnName string) string {
	triggerName := fmt.Sprintf("tr_%s_%s_update", tableName, columnName)

	return fmt.Sprintf(`CREATE TRIGGER IF NOT EXISTS %s
AFTER UPDATE ON %s
FOR EACH ROW
BEGIN
  UPDATE %s SET %s = datetime('now') WHERE rowid = NEW.rowid;
END;`,
		triggerName, tableName, tableName, columnName)
}

// =============================================================================
// Insert-Konvertierung
// =============================================================================

// ConvertInsert konvertiert MySQL INSERT zu SQLite
func ConvertInsert(mysqlInsert string) string {
	sql := mysqlInsert

	// INSERT IGNORE zu INSERT OR IGNORE
	sql = regexp.MustCompile(`(?i)INSERT\s+IGNORE\s+INTO`).ReplaceAllString(sql, "INSERT OR IGNORE INTO")

	// REPLACE INTO zu INSERT OR REPLACE
	sql = regexp.MustCompile(`(?i)REPLACE\s+INTO`).ReplaceAllString(sql, "INSERT OR REPLACE INTO")

	// ON DUPLICATE KEY UPDATE zu ON CONFLICT DO UPDATE
	// Dies ist komplexer und erfordert die Kenntnis des Primary Keys
	if strings.Contains(strings.ToUpper(sql), "ON DUPLICATE KEY UPDATE") {
		// Einfache Konvertierung - erfordert manuelles Anpassen des Conflict-Targets
		sql = regexp.MustCompile(`(?i)ON\s+DUPLICATE\s+KEY\s+UPDATE`).ReplaceAllString(sql, "ON CONFLICT DO UPDATE SET")

		// VALUES(col) zu excluded.col
		sql = regexp.MustCompile(`(?i)VALUES\((\w+)\)`).ReplaceAllString(sql, "excluded.$1")
	}

	return sql
}

// =============================================================================
// View-Konvertierung
// =============================================================================

// ConvertView konvertiert MySQL VIEW zu SQLite
func ConvertView(mysqlView string) string {
	sql := mysqlView

	// ALGORITHM, DEFINER, SQL SECURITY entfernen
	sql = regexp.MustCompile(`(?i)ALGORITHM\s*=\s*\w+\s*`).ReplaceAllString(sql, "")
	sql = regexp.MustCompile(`(?i)DEFINER\s*=\s*`+"`"+`[^`+"`"+`]+`+"`"+`@`+"`"+`[^`+"`"+`]+`+"`"+`\s*`).ReplaceAllString(sql, "")
	sql = regexp.MustCompile(`(?i)SQL\s+SECURITY\s+\w+\s*`).ReplaceAllString(sql, "")

	// WITH CHECK OPTION wird unterstützt
	// Keine Änderung nötig

	return sql
}
