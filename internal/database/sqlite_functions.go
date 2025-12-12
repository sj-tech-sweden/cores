// Package database provides SQLite custom function registration
// Diese Datei registriert Custom SQL Functions für SQLite,
// um MySQL-Kompatibilität auf Datenbankebene zu ermöglichen
package database

import (
	"database/sql"
	"fmt"
	"strings"

	"github.com/mattn/go-sqlite3"
)

// SQLiteDriverName ist der Name des erweiterten SQLite-Treibers
const SQLiteDriverName = "sqlite3_extended"

// driverRegistered verhindert mehrfache Registrierung
var driverRegistered = false

// RegisterSQLiteExtendedDriver registriert den erweiterten SQLite-Treiber
// mit MySQL-kompatiblen Funktionen
//
// Verwendung:
//
//	database.RegisterSQLiteExtendedDriver()
//	db, err := sql.Open("sqlite3_extended", "file:mydb.sqlite?cache=shared")
func RegisterSQLiteExtendedDriver() error {
	if driverRegistered {
		return nil
	}

	sql.Register(SQLiteDriverName, &sqlite3.SQLiteDriver{
		ConnectHook: func(conn *sqlite3.SQLiteConn) error {
			return registerCustomFunctions(conn)
		},
	})

	driverRegistered = true
	return nil
}

// registerCustomFunctions registriert alle Custom Functions
func registerCustomFunctions(conn *sqlite3.SQLiteConn) error {
	// SUBSTRING_INDEX(str, delim, count)
	// Emuliert MySQL SUBSTRING_INDEX
	if err := conn.RegisterFunc("substring_index", substringIndexSQL, true); err != nil {
		return fmt.Errorf("failed to register substring_index: %w", err)
	}

	// LPAD(str, length, padStr)
	// Emuliert MySQL LPAD
	if err := conn.RegisterFunc("lpad", lpadSQL, true); err != nil {
		return fmt.Errorf("failed to register lpad: %w", err)
	}

	// RPAD(str, length, padStr)
	// Emuliert MySQL RPAD
	if err := conn.RegisterFunc("rpad", rpadSQL, true); err != nil {
		return fmt.Errorf("failed to register rpad: %w", err)
	}

	// CONCAT_WS(separator, str1, str2, ...)
	// Emuliert MySQL CONCAT_WS (mit bis zu 10 Argumenten)
	if err := conn.RegisterFunc("concat_ws", concatWsSQL, true); err != nil {
		return fmt.Errorf("failed to register concat_ws: %w", err)
	}

	// IF(condition, true_val, false_val)
	// Emuliert MySQL IF() - SQLite hat nur IIF()
	if err := conn.RegisterFunc("if", ifSQL, true); err != nil {
		return fmt.Errorf("failed to register if: %w", err)
	}

	// FIELD(str, str1, str2, ...)
	// Emuliert MySQL FIELD() - gibt Position des ersten Args in der Liste zurück
	if err := conn.RegisterFunc("field", fieldSQL, true); err != nil {
		return fmt.Errorf("failed to register field: %w", err)
	}

	// NOW() -> datetime('now', 'localtime')
	// Für bessere MySQL-Kompatibilität
	if err := conn.RegisterFunc("now", nowSQL, false); err != nil {
		return fmt.Errorf("failed to register now: %w", err)
	}

	// CURDATE() -> date('now', 'localtime')
	if err := conn.RegisterFunc("curdate", curdateSQL, false); err != nil {
		return fmt.Errorf("failed to register curdate: %w", err)
	}

	// CURTIME() -> time('now', 'localtime')
	if err := conn.RegisterFunc("curtime", curtimeSQL, false); err != nil {
		return fmt.Errorf("failed to register curtime: %w", err)
	}

	return nil
}

// =============================================================================
// SQL Function Implementations
// =============================================================================

func substringIndexSQL(str, delim string, count int64) string {
	if count == 0 || str == "" || delim == "" {
		return ""
	}

	parts := strings.Split(str, delim)
	intCount := int(count)

	if intCount > 0 {
		if intCount >= len(parts) {
			return str
		}
		return strings.Join(parts[:intCount], delim)
	}

	// count < 0
	absCount := -intCount
	if absCount >= len(parts) {
		return str
	}
	return strings.Join(parts[len(parts)-absCount:], delim)
}

func lpadSQL(str string, length int64, padStr string) string {
	intLen := int(length)
	if len(str) >= intLen {
		return str[:intLen]
	}
	if padStr == "" {
		padStr = " "
	}

	padLen := intLen - len(str)
	fullPad := strings.Repeat(padStr, (padLen/len(padStr))+1)
	return fullPad[:padLen] + str
}

func rpadSQL(str string, length int64, padStr string) string {
	intLen := int(length)
	if len(str) >= intLen {
		return str[:intLen]
	}
	if padStr == "" {
		padStr = " "
	}

	padLen := intLen - len(str)
	fullPad := strings.Repeat(padStr, (padLen/len(padStr))+1)
	return str + fullPad[:padLen]
}

// concatWsSQL verbindet Strings mit Separator
// Hinweis: SQLite Variadic Functions haben Limitierungen,
// daher hier eine Version mit max 10 Strings
func concatWsSQL(sep string, parts ...interface{}) string {
	var nonEmpty []string
	for _, p := range parts {
		if p == nil {
			continue
		}
		str := fmt.Sprintf("%v", p)
		if str != "" {
			nonEmpty = append(nonEmpty, str)
		}
	}
	return strings.Join(nonEmpty, sep)
}

func ifSQL(condition bool, trueVal, falseVal interface{}) interface{} {
	if condition {
		return trueVal
	}
	return falseVal
}

// fieldSQL gibt die Position (1-basiert) des ersten Arguments in der Liste zurück
// Gibt 0 zurück wenn nicht gefunden
func fieldSQL(search string, values ...string) int64 {
	for i, v := range values {
		if v == search {
			return int64(i + 1)
		}
	}
	return 0
}

func nowSQL() string {
	return SQLiteNow()
}

func curdateSQL() string {
	return SQLiteDate()
}

func curtimeSQL() string {
	return strings.Split(SQLiteNow(), " ")[1]
}

// =============================================================================
// Helper für Query-Anpassung
// =============================================================================

// SQLDialect repräsentiert den Datenbanktyp
type SQLDialect int

const (
	DialectMySQL SQLDialect = iota
	DialectSQLite
)

// QueryAdapter passt SQL-Queries an verschiedene Dialekte an
type QueryAdapter struct {
	Dialect SQLDialect
}

// NewQueryAdapter erstellt einen neuen QueryAdapter
func NewQueryAdapter(dialect SQLDialect) *QueryAdapter {
	return &QueryAdapter{Dialect: dialect}
}

// AdaptQuery passt eine MySQL-Query für SQLite an
// Achtung: Dies ist eine einfache Implementierung für häufige Fälle
func (qa *QueryAdapter) AdaptQuery(mysqlQuery string) string {
	if qa.Dialect == DialectMySQL {
		return mysqlQuery
	}

	query := mysqlQuery

	// NOW() -> datetime('now')
	query = strings.ReplaceAll(query, "NOW()", "datetime('now')")

	// CURDATE() -> date('now')
	query = strings.ReplaceAll(query, "CURDATE()", "date('now')")

	// IFNULL -> COALESCE (optional, beide funktionieren)
	// query = strings.ReplaceAll(query, "IFNULL(", "COALESCE(")

	// Backticks zu double quotes (für Identifiers)
	// Achtung: Nur für einfache Fälle, keine verschachtelten Strings
	query = strings.ReplaceAll(query, "`", "\"")

	return query
}

// AdaptUpsert konvertiert MySQL ON DUPLICATE KEY UPDATE zu SQLite ON CONFLICT
func (qa *QueryAdapter) AdaptUpsert(table, conflictColumn string, columns []string, values []interface{}) string {
	if qa.Dialect == DialectMySQL {
		// MySQL: INSERT ... ON DUPLICATE KEY UPDATE
		cols := strings.Join(columns, ", ")
		placeholders := strings.Repeat("?, ", len(columns))
		placeholders = placeholders[:len(placeholders)-2]

		updates := make([]string, len(columns))
		for i, col := range columns {
			updates[i] = fmt.Sprintf("%s = VALUES(%s)", col, col)
		}

		return fmt.Sprintf(
			"INSERT INTO %s (%s) VALUES (%s) ON DUPLICATE KEY UPDATE %s",
			table, cols, placeholders, strings.Join(updates, ", "),
		)
	}

	// SQLite: INSERT ... ON CONFLICT DO UPDATE
	cols := strings.Join(columns, ", ")
	placeholders := strings.Repeat("?, ", len(columns))
	placeholders = placeholders[:len(placeholders)-2]

	updates := make([]string, len(columns))
	for i, col := range columns {
		if col != conflictColumn {
			updates[i] = fmt.Sprintf("%s = excluded.%s", col, col)
		}
	}
	// Filter leere Einträge
	var filteredUpdates []string
	for _, u := range updates {
		if u != "" {
			filteredUpdates = append(filteredUpdates, u)
		}
	}

	return fmt.Sprintf(
		"INSERT INTO %s (%s) VALUES (%s) ON CONFLICT(%s) DO UPDATE SET %s",
		table, cols, placeholders, conflictColumn, strings.Join(filteredUpdates, ", "),
	)
}
