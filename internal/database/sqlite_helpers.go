// Package database provides SQLite helper functions for MySQL compatibility
// Diese Datei enthält Hilfsfunktionen um MySQL-spezifische Funktionen
// in SQLite zu emulieren
package database

import (
	"database/sql"
	"fmt"
	"strings"
	"time"
)

// =============================================================================
// String-Funktionen (MySQL-Kompatibilität)
// =============================================================================

// SubstringIndex emuliert MySQL SUBSTRING_INDEX(str, delim, count)
// Gibt den Substring vor (count > 0) oder nach (count < 0) dem n-ten Vorkommen des Delimiters zurück
//
// Beispiele:
//
//	SubstringIndex("www.example.com", ".", 1)  => "www"
//	SubstringIndex("www.example.com", ".", 2)  => "www.example"
//	SubstringIndex("www.example.com", ".", -1) => "com"
//	SubstringIndex("www.example.com", ".", -2) => "example.com"
func SubstringIndex(str, delim string, count int) string {
	if count == 0 || str == "" || delim == "" {
		return ""
	}

	parts := strings.Split(str, delim)

	if count > 0 {
		if count >= len(parts) {
			return str
		}
		return strings.Join(parts[:count], delim)
	}

	// count < 0
	absCount := -count
	if absCount >= len(parts) {
		return str
	}
	return strings.Join(parts[len(parts)-absCount:], delim)
}

// LPad emuliert MySQL LPAD(str, length, padStr)
// Füllt den String links auf bis zur gewünschten Länge
//
// Beispiele:
//
//	LPad("42", 5, "0")   => "00042"
//	LPad("hello", 3, "x") => "hel"  (truncated)
//	LPad("hi", 5, "xy")  => "xyxhi"
func LPad(str string, length int, padStr string) string {
	strLen := len(str)
	if strLen >= length {
		return str[:length]
	}
	if padStr == "" {
		padStr = " "
	}

	padLen := length - strLen
	// Erstelle genug Padding
	fullPad := strings.Repeat(padStr, (padLen/len(padStr))+1)
	return fullPad[:padLen] + str
}

// RPad emuliert MySQL RPAD(str, length, padStr)
// Füllt den String rechts auf bis zur gewünschten Länge
//
// Beispiele:
//
//	RPad("42", 5, "0")   => "42000"
//	RPad("hello", 3, "x") => "hel"  (truncated)
func RPad(str string, length int, padStr string) string {
	strLen := len(str)
	if strLen >= length {
		return str[:length]
	}
	if padStr == "" {
		padStr = " "
	}

	padLen := length - strLen
	fullPad := strings.Repeat(padStr, (padLen/len(padStr))+1)
	return str + fullPad[:padLen]
}

// ConcatWS emuliert MySQL CONCAT_WS(separator, str1, str2, ...)
// Verbindet Strings mit Separator, überspringt leere Werte
//
// Beispiele:
//
//	ConcatWS(", ", "a", "", "b", "c") => "a, b, c"
//	ConcatWS("-", "2025", "12", "01") => "2025-12-01"
func ConcatWS(separator string, parts ...string) string {
	var nonEmpty []string
	for _, p := range parts {
		if p != "" {
			nonEmpty = append(nonEmpty, p)
		}
	}
	return strings.Join(nonEmpty, separator)
}

// ConcatWSNullable ist wie ConcatWS, aber für sql.NullString Werte
func ConcatWSNullable(separator string, parts ...sql.NullString) string {
	var nonEmpty []string
	for _, p := range parts {
		if p.Valid && p.String != "" {
			nonEmpty = append(nonEmpty, p.String)
		}
	}
	return strings.Join(nonEmpty, separator)
}

// =============================================================================
// Datum/Zeit-Funktionen (MySQL-Kompatibilität)
// =============================================================================

// DateAdd emuliert MySQL DATE_ADD(date, INTERVAL value unit)
// Unterstützte Units: SECOND, MINUTE, HOUR, DAY, WEEK, MONTH, YEAR
func DateAdd(date time.Time, value int, unit string) time.Time {
	switch strings.ToUpper(unit) {
	case "SECOND", "SECONDS":
		return date.Add(time.Duration(value) * time.Second)
	case "MINUTE", "MINUTES":
		return date.Add(time.Duration(value) * time.Minute)
	case "HOUR", "HOURS":
		return date.Add(time.Duration(value) * time.Hour)
	case "DAY", "DAYS":
		return date.AddDate(0, 0, value)
	case "WEEK", "WEEKS":
		return date.AddDate(0, 0, value*7)
	case "MONTH", "MONTHS":
		return date.AddDate(0, value, 0)
	case "YEAR", "YEARS":
		return date.AddDate(value, 0, 0)
	default:
		return date
	}
}

// DateSub emuliert MySQL DATE_SUB (ist DATE_ADD mit negativem Wert)
func DateSub(date time.Time, value int, unit string) time.Time {
	return DateAdd(date, -value, unit)
}

// DateDiff berechnet die Differenz in Tagen zwischen zwei Daten
// Emuliert MySQL DATEDIFF(date1, date2)
// Gibt date1 - date2 in Tagen zurück
func DateDiff(date1, date2 time.Time) int {
	// Normalisiere auf Mitternacht
	d1 := time.Date(date1.Year(), date1.Month(), date1.Day(), 0, 0, 0, 0, time.UTC)
	d2 := time.Date(date2.Year(), date2.Month(), date2.Day(), 0, 0, 0, 0, time.UTC)
	diff := d1.Sub(d2)
	return int(diff.Hours() / 24)
}

// TimestampDiff berechnet die Differenz in der angegebenen Einheit
// Emuliert MySQL TIMESTAMPDIFF(unit, datetime1, datetime2)
func TimestampDiff(unit string, dt1, dt2 time.Time) int64 {
	diff := dt2.Sub(dt1)

	switch strings.ToUpper(unit) {
	case "SECOND":
		return int64(diff.Seconds())
	case "MINUTE":
		return int64(diff.Minutes())
	case "HOUR":
		return int64(diff.Hours())
	case "DAY":
		return int64(diff.Hours() / 24)
	case "WEEK":
		return int64(diff.Hours() / (24 * 7))
	case "MONTH":
		// Approximation
		return int64(diff.Hours() / (24 * 30))
	case "YEAR":
		// Approximation
		return int64(diff.Hours() / (24 * 365))
	default:
		return int64(diff.Seconds())
	}
}

// MySQLDateFormatToGo konvertiert MySQL DATE_FORMAT Platzhalter zu Go time.Format
var mysqlToGoFormat = map[string]string{
	"%Y": "2006",     // 4-stelliges Jahr
	"%y": "06",       // 2-stelliges Jahr
	"%m": "01",       // Monat (01-12)
	"%c": "1",        // Monat (1-12)
	"%d": "02",       // Tag (01-31)
	"%e": "2",        // Tag (1-31)
	"%H": "15",       // Stunde 24h (00-23)
	"%h": "03",       // Stunde 12h (01-12)
	"%I": "03",       // Stunde 12h (01-12)
	"%i": "04",       // Minute (00-59)
	"%s": "05",       // Sekunde (00-59)
	"%S": "05",       // Sekunde (00-59)
	"%p": "PM",       // AM/PM
	"%M": "January",  // Monatsname
	"%b": "Jan",      // Monatsname kurz
	"%W": "Monday",   // Wochentagsname
	"%a": "Mon",      // Wochentagsname kurz
	"%T": "15:04:05", // Time 24h
	"%r": "03:04:05 PM", // Time 12h mit AM/PM
}

// FormatDate emuliert MySQL DATE_FORMAT(date, format)
func FormatDate(t time.Time, mysqlFormat string) string {
	goFormat := mysqlFormat
	for mysql, goFmt := range mysqlToGoFormat {
		goFormat = strings.ReplaceAll(goFormat, mysql, goFmt)
	}
	return t.Format(goFormat)
}

// ParseMySQLDateTime parst einen MySQL DATETIME String
func ParseMySQLDateTime(s string) (time.Time, error) {
	// Versuche verschiedene Formate
	formats := []string{
		"2006-01-02 15:04:05",
		"2006-01-02T15:04:05",
		"2006-01-02T15:04:05Z",
		"2006-01-02",
	}

	for _, format := range formats {
		if t, err := time.Parse(format, s); err == nil {
			return t, nil
		}
	}
	return time.Time{}, fmt.Errorf("cannot parse datetime: %s", s)
}

// =============================================================================
// SQLite-spezifische Helfer
// =============================================================================

// SQLiteNow gibt die aktuelle Zeit im SQLite-kompatiblen Format zurück
// (ISO8601 ohne Zeitzone)
func SQLiteNow() string {
	return time.Now().UTC().Format("2006-01-02 15:04:05")
}

// SQLiteDate gibt das aktuelle Datum im SQLite-kompatiblen Format zurück
func SQLiteDate() string {
	return time.Now().UTC().Format("2006-01-02")
}

// ToSQLiteDateTime konvertiert ein time.Time zu SQLite-kompatiblem String
func ToSQLiteDateTime(t time.Time) string {
	return t.UTC().Format("2006-01-02 15:04:05")
}

// ToSQLiteDate konvertiert ein time.Time zu SQLite-kompatiblem Datumsstring
func ToSQLiteDate(t time.Time) string {
	return t.Format("2006-01-02")
}

// SQLiteDatetimeExpr erzeugt einen SQLite datetime() Ausdruck
// Nützlich für dynamische Query-Generierung
//
// Beispiele:
//
//	SQLiteDatetimeExpr("now", 30, "days")  => "datetime('now', '+30 days')"
//	SQLiteDatetimeExpr("now", -7, "days")  => "datetime('now', '-7 days')"
func SQLiteDatetimeExpr(base string, value int, unit string) string {
	if value >= 0 {
		return fmt.Sprintf("datetime('%s', '+%d %s')", base, value, unit)
	}
	return fmt.Sprintf("datetime('%s', '%d %s')", base, value, unit)
}

// =============================================================================
// Null-Handling Helfer
// =============================================================================

// Coalesce gibt den ersten nicht-nil/nicht-leeren Wert zurück
func Coalesce(values ...interface{}) interface{} {
	for _, v := range values {
		if v != nil {
			switch val := v.(type) {
			case string:
				if val != "" {
					return val
				}
			case sql.NullString:
				if val.Valid && val.String != "" {
					return val.String
				}
			case sql.NullInt64:
				if val.Valid {
					return val.Int64
				}
			case sql.NullFloat64:
				if val.Valid {
					return val.Float64
				}
			case sql.NullBool:
				if val.Valid {
					return val.Bool
				}
			default:
				return v
			}
		}
	}
	return nil
}

// CoalesceString gibt den ersten nicht-leeren String zurück
func CoalesceString(values ...string) string {
	for _, v := range values {
		if v != "" {
			return v
		}
	}
	return ""
}

// CoalesceNullString gibt den ersten gültigen NullString zurück
func CoalesceNullString(values ...sql.NullString) string {
	for _, v := range values {
		if v.Valid && v.String != "" {
			return v.String
		}
	}
	return ""
}

// IfNull emuliert MySQL IFNULL(expr1, expr2)
// Gibt expr1 zurück wenn nicht leer, sonst expr2
func IfNull(expr1, expr2 string) string {
	if expr1 != "" {
		return expr1
	}
	return expr2
}

// IfNullInt64 für Integer-Werte
func IfNullInt64(val sql.NullInt64, defaultVal int64) int64 {
	if val.Valid {
		return val.Int64
	}
	return defaultVal
}

// =============================================================================
// Device ID Generator (ersetzt MySQL Trigger)
// =============================================================================

// DeviceIDGenerator generiert Device IDs im Format: [Abbreviation][PosCategory][Counter]
type DeviceIDGenerator struct {
	db *sql.DB
}

// NewDeviceIDGenerator erstellt einen neuen Generator
func NewDeviceIDGenerator(db *sql.DB) *DeviceIDGenerator {
	return &DeviceIDGenerator{db: db}
}

// Generate generiert eine neue DeviceID für das gegebene Produkt
// Dies ersetzt den MySQL Trigger "devices_before_insert"
func (g *DeviceIDGenerator) Generate(productID int) (string, error) {
	// 1) Hole Abkürzung und Position
	var abbreviation string
	var posCategory int

	err := g.db.QueryRow(`
		SELECT s.abbreviation, p.pos_in_category
		FROM subcategories s
		JOIN products p ON s.subcategoryID = p.subcategoryID
		WHERE p.productID = ?
		LIMIT 1
	`, productID).Scan(&abbreviation, &posCategory)
	if err != nil {
		return "", fmt.Errorf("failed to get product info: %w", err)
	}

	// 2) Erstelle Prefix
	prefix := fmt.Sprintf("%s%d", abbreviation, posCategory)

	// 3) Finde nächsten Counter
	var nextCounter int
	err = g.db.QueryRow(`
		SELECT COALESCE(MAX(CAST(substr(deviceID, -3) AS INTEGER)), 0) + 1
		FROM devices
		WHERE deviceID LIKE ? || '%'
	`, prefix).Scan(&nextCounter)
	if err != nil {
		return "", fmt.Errorf("failed to get next counter: %w", err)
	}

	// 4) Generiere DeviceID
	return fmt.Sprintf("%s%03d", prefix, nextCounter), nil
}

// IsPackageDevice prüft ob eine DeviceID zu einem virtuellen Package-Device gehört
func IsPackageDevice(deviceID string) bool {
	return strings.HasPrefix(deviceID, "PKG_")
}

// =============================================================================
// Cable Name Generator (ersetzt MySQL Trigger)
// =============================================================================

// CableNameGenerator generiert Kabelnamen
type CableNameGenerator struct {
	db *sql.DB
}

// NewCableNameGenerator erstellt einen neuen Generator
func NewCableNameGenerator(db *sql.DB) *CableNameGenerator {
	return &CableNameGenerator{db: db}
}

// CableInfo enthält die Informationen für die Namensgenerierung
type CableInfo struct {
	TypeID       int
	Connector1ID int
	Connector2ID int
	Length       float64
}

// Generate generiert den Kabelnamen
// Dies ersetzt die MySQL Trigger "cables_before_insert" und "cables_before_update"
func (g *CableNameGenerator) Generate(info CableInfo) (string, error) {
	// Hole Typ-Namen
	var typeName string
	err := g.db.QueryRow(
		"SELECT name FROM cable_types WHERE cable_typesID = ?",
		info.TypeID,
	).Scan(&typeName)
	if err != nil {
		return "", fmt.Errorf("failed to get cable type: %w", err)
	}

	// Hole Connector 1 Namen (Abkürzung bevorzugt)
	var conn1Name string
	err = g.db.QueryRow(
		"SELECT COALESCE(abbreviation, name) FROM cable_connectors WHERE cable_connectorsID = ?",
		info.Connector1ID,
	).Scan(&conn1Name)
	if err != nil {
		return "", fmt.Errorf("failed to get connector1: %w", err)
	}

	// Hole Connector 2 Namen
	var conn2Name string
	err = g.db.QueryRow(
		"SELECT COALESCE(abbreviation, name) FROM cable_connectors WHERE cable_connectorsID = ?",
		info.Connector2ID,
	).Scan(&conn2Name)
	if err != nil {
		return "", fmt.Errorf("failed to get connector2: %w", err)
	}

	// Format: TypeName (Conn1-Conn2) - X.XX m
	return fmt.Sprintf("%s (%s-%s) - %.2f m", typeName, conn1Name, conn2Name, info.Length), nil
}
