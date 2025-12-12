# MySQL zu SQLite Konvertierungs-Leitfaden 🔄

**Erstellt von:** Horst (SQLite-Konvertierungs-Spezialist)  
**Datum:** 12. Dezember 2025  
**Projekt:** RentalCore/WarehouseCore

---

## 📋 Inhaltsverzeichnis

1. [Mapping-Tabelle: MySQL → SQLite](#1-mapping-tabelle-mysql--sqlite)
2. [Go-Hilfsfunktionen](#2-go-hilfsfunktionen)
3. [Trigger-Konvertierung](#3-trigger-konvertierung)
4. [ENUM zu TEXT Konvertierung](#4-enum-zu-text-konvertierung)
5. [Weitere wichtige Konvertierungen](#5-weitere-wichtige-konvertierungen)

---

## 1. Mapping-Tabelle: MySQL → SQLite

### 1.1 Datetime-Funktionen

| MySQL | SQLite | Beispiel |
|-------|--------|----------|
| `NOW()` | `datetime('now')` | `datetime('now')` → `2025-12-12 14:30:00` |
| `CURRENT_TIMESTAMP` | `CURRENT_TIMESTAMP` oder `datetime('now')` | Identisch, aber ohne `ON UPDATE` |
| `CURDATE()` | `date('now')` | `date('now')` → `2025-12-12` |
| `CURTIME()` | `time('now')` | `time('now')` → `14:30:00` |
| `DATE_ADD(NOW(), INTERVAL 30 DAY)` | `datetime('now', '+30 days')` | Modifier-basiert |
| `DATE_SUB(NOW(), INTERVAL 7 DAY)` | `datetime('now', '-7 days')` | Modifier-basiert |
| `DATE_ADD(date, INTERVAL n MONTH)` | `datetime(date, '+n months')` | `datetime('now', '+3 months')` |
| `DATE_FORMAT(date, '%Y-%m-%d')` | `strftime('%Y-%m-%d', date)` | Siehe Format-Tabelle |
| `DATEDIFF(date1, date2)` | `CAST(julianday(date1) - julianday(date2) AS INTEGER)` | Gibt Tage als Integer |
| `TIMESTAMPDIFF(SECOND, d1, d2)` | `strftime('%s', d2) - strftime('%s', d1)` | Unix-Timestamps |
| `UNIX_TIMESTAMP()` | `strftime('%s', 'now')` | Sekunden seit Epoch |
| `FROM_UNIXTIME(ts)` | `datetime(ts, 'unixepoch')` | Unix → Datetime |

### 1.2 Date Format Konvertierung

| MySQL Format | SQLite Format | Beschreibung |
|--------------|---------------|--------------|
| `%Y` | `%Y` | Jahr 4-stellig |
| `%m` | `%m` | Monat 2-stellig |
| `%d` | `%d` | Tag 2-stellig |
| `%H` | `%H` | Stunde 24h |
| `%i` | `%M` | Minute ⚠️ |
| `%s` | `%S` | Sekunde |
| `%W` | `%w` | Wochentag (unterschiedlich!) |

### 1.3 String-Funktionen

| MySQL | SQLite | Hinweis |
|-------|--------|---------|
| `IFNULL(a, b)` | `IFNULL(a, b)` oder `COALESCE(a, b)` | Beide funktionieren ✅ |
| `CONCAT(a, b, c)` | `a \|\| b \|\| c` | String-Konkatenation |
| `CONCAT_WS(',', a, b)` | Nicht direkt verfügbar | → Go-Code |
| `SUBSTRING_INDEX(str, delim, n)` | Nicht verfügbar | → Go-Hilfsfunktion |
| `LPAD(str, len, pad)` | `printf('%0*d', len, val)` für Zahlen | → Go für Strings |
| `RPAD(str, len, pad)` | Nicht verfügbar | → Go-Code |
| `LEFT(str, n)` | `substr(str, 1, n)` | |
| `RIGHT(str, n)` | `substr(str, -n)` | |
| `INSTR(str, substr)` | `instr(str, substr)` | Identisch ✅ |
| `LOCATE(substr, str)` | `instr(str, substr)` | Reihenfolge beachten! |
| `REPLACE(str, old, new)` | `replace(str, old, new)` | Identisch ✅ |
| `TRIM(str)` | `trim(str)` | Identisch ✅ |
| `UPPER(str)` | `upper(str)` | Identisch ✅ |
| `LOWER(str)` | `lower(str)` | Identisch ✅ |
| `LENGTH(str)` | `length(str)` | Identisch ✅ |
| `CHAR_LENGTH(str)` | `length(str)` | SQLite kennt kein CHAR_LENGTH |

### 1.4 INSERT/UPDATE Konstrukte

| MySQL | SQLite |
|-------|--------|
| `INSERT ... ON DUPLICATE KEY UPDATE col = VALUES(col)` | `INSERT ... ON CONFLICT(key) DO UPDATE SET col = excluded.col` |
| `INSERT IGNORE INTO ...` | `INSERT OR IGNORE INTO ...` |
| `REPLACE INTO ...` | `INSERT OR REPLACE INTO ...` |

**Beispiel-Konvertierung:**

```sql
-- MySQL
INSERT INTO devices (deviceID, name, status)
VALUES ('DEV001', 'Camera', 'free')
ON DUPLICATE KEY UPDATE 
    name = VALUES(name),
    status = VALUES(status);

-- SQLite
INSERT INTO devices (deviceID, name, status)
VALUES ('DEV001', 'Camera', 'free')
ON CONFLICT(deviceID) DO UPDATE SET
    name = excluded.name,
    status = excluded.status;
```

### 1.5 Typ-Konvertierungen

| MySQL | SQLite | Hinweis |
|-------|--------|---------|
| `INT AUTO_INCREMENT` | `INTEGER PRIMARY KEY` | AUTOINCREMENT optional |
| `BIGINT UNSIGNED` | `INTEGER` | Kein UNSIGNED in SQLite |
| `TINYINT(1)` / `BOOLEAN` | `INTEGER` | 0/1 verwenden |
| `FLOAT` / `DOUBLE` | `REAL` | |
| `VARCHAR(n)` | `TEXT` | Kein Längenlimit |
| `CHAR(n)` | `TEXT` | Kein Längenlimit |
| `TEXT` / `MEDIUMTEXT` / `LONGTEXT` | `TEXT` | Alles TEXT |
| `BLOB` / `MEDIUMBLOB` / `LONGBLOB` | `BLOB` | |
| `DATETIME` | `TEXT` | ISO8601 Format |
| `TIMESTAMP` | `TEXT` | ISO8601 Format |
| `DATE` | `TEXT` | YYYY-MM-DD |
| `TIME` | `TEXT` | HH:MM:SS |
| `DECIMAL(m,n)` | `REAL` oder `TEXT` | Für Geld: TEXT empfohlen |
| `JSON` | `TEXT` | JSON als String |
| `ENUM(...)` | `TEXT` + CHECK | Siehe Abschnitt 4 |

### 1.6 CAST-Konvertierungen

| MySQL | SQLite |
|-------|--------|
| `CAST(x AS UNSIGNED)` | `CAST(x AS INTEGER)` |
| `CAST(x AS SIGNED)` | `CAST(x AS INTEGER)` |
| `CAST(x AS CHAR)` | `CAST(x AS TEXT)` |
| `CAST(x AS DECIMAL)` | `CAST(x AS REAL)` |
| `CAST(x AS DATETIME)` | `datetime(x)` |

---

## 2. Go-Hilfsfunktionen

### 2.1 Erforderliche Hilfsfunktionen

Erstelle diese Datei: `internal/database/sqlite_helpers.go`

```go
package database

import (
	"database/sql"
	"fmt"
	"strings"
	"time"
)

// SQLiteHelpers enthält Hilfsfunktionen für SQLite-Kompatibilität
type SQLiteHelpers struct{}

// SubstringIndex emuliert MySQL SUBSTRING_INDEX(str, delim, count)
// Gibt den Substring vor (count > 0) oder nach (count < 0) dem n-ten Vorkommen des Delimiters zurück
func SubstringIndex(str, delim string, count int) string {
	if count == 0 {
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
func LPad(str string, length int, padStr string) string {
	if len(str) >= length {
		return str[:length]
	}
	if padStr == "" {
		padStr = " "
	}

	padLen := length - len(str)
	padding := strings.Repeat(padStr, (padLen/len(padStr))+1)
	return padding[:padLen] + str
}

// RPad emuliert MySQL RPAD(str, length, padStr)
func RPad(str string, length int, padStr string) string {
	if len(str) >= length {
		return str[:length]
	}
	if padStr == "" {
		padStr = " "
	}

	padLen := length - len(str)
	padding := strings.Repeat(padStr, (padLen/len(padStr))+1)
	return str + padding[:padLen]
}

// ConcatWS emuliert MySQL CONCAT_WS(separator, str1, str2, ...)
// Verbindet Strings mit Separator, überspringt NULL/leere Werte
func ConcatWS(separator string, parts ...string) string {
	var nonEmpty []string
	for _, p := range parts {
		if p != "" {
			nonEmpty = append(nonEmpty, p)
		}
	}
	return strings.Join(nonEmpty, separator)
}

// DateAdd emuliert MySQL DATE_ADD
// Gibt ein neues Datum zurück
func DateAdd(date time.Time, value int, unit string) time.Time {
	switch strings.ToUpper(unit) {
	case "DAY", "DAYS":
		return date.AddDate(0, 0, value)
	case "WEEK", "WEEKS":
		return date.AddDate(0, 0, value*7)
	case "MONTH", "MONTHS":
		return date.AddDate(0, value, 0)
	case "YEAR", "YEARS":
		return date.AddDate(value, 0, 0)
	case "HOUR", "HOURS":
		return date.Add(time.Duration(value) * time.Hour)
	case "MINUTE", "MINUTES":
		return date.Add(time.Duration(value) * time.Minute)
	case "SECOND", "SECONDS":
		return date.Add(time.Duration(value) * time.Second)
	default:
		return date
	}
}

// DateDiff berechnet die Differenz in Tagen zwischen zwei Daten
func DateDiff(date1, date2 time.Time) int {
	diff := date1.Sub(date2)
	return int(diff.Hours() / 24)
}

// FormatDate konvertiert MySQL DATE_FORMAT zu Go time.Format
// Häufige MySQL-Formate zu Go:
//   %Y-%m-%d -> 2006-01-02
//   %d.%m.%Y -> 02.01.2006
//   %H:%i:%s -> 15:04:05
func FormatDate(t time.Time, mysqlFormat string) string {
	// MySQL zu Go Format-Mapping
	replacements := map[string]string{
		"%Y": "2006",
		"%m": "01",
		"%d": "02",
		"%H": "15",
		"%i": "04",
		"%s": "05",
		"%M": "January",
		"%D": "2nd",
		"%W": "Monday",
	}

	goFormat := mysqlFormat
	for mysql, goFmt := range replacements {
		goFormat = strings.ReplaceAll(goFormat, mysql, goFmt)
	}

	return t.Format(goFormat)
}

// NullString gibt den ersten nicht-leeren String zurück (wie COALESCE)
func NullString(values ...sql.NullString) string {
	for _, v := range values {
		if v.Valid && v.String != "" {
			return v.String
		}
	}
	return ""
}

// SQLiteNow gibt die aktuelle Zeit im SQLite-kompatiblen Format zurück
func SQLiteNow() string {
	return time.Now().UTC().Format("2006-01-02 15:04:05")
}

// SQLiteDateAdd erzeugt einen SQLite-kompatiblen datetime-Ausdruck
func SQLiteDateAdd(baseExpr string, days int) string {
	if days >= 0 {
		return fmt.Sprintf("datetime(%s, '+%d days')", baseExpr, days)
	}
	return fmt.Sprintf("datetime(%s, '%d days')", baseExpr, days)
}
```

### 2.2 SQLite Custom Functions registrieren

```go
package database

import (
	"database/sql"
	"strings"

	"github.com/mattn/go-sqlite3"
)

// RegisterSQLiteFunctions registriert Custom Functions für SQLite
// um MySQL-Kompatibilität zu verbessern
func RegisterSQLiteFunctions() {
	sql.Register("sqlite3_extended", &sqlite3.SQLiteDriver{
		ConnectHook: func(conn *sqlite3.SQLiteConn) error {
			// SUBSTRING_INDEX(str, delim, count)
			if err := conn.RegisterFunc("substring_index", SubstringIndex, true); err != nil {
				return err
			}

			// LPAD(str, length, padStr)
			if err := conn.RegisterFunc("lpad", LPad, true); err != nil {
				return err
			}

			// RPAD(str, length, padStr)
			if err := conn.RegisterFunc("rpad", RPad, true); err != nil {
				return err
			}

			// CONCAT_WS(separator, ...)
			if err := conn.RegisterFunc("concat_ws", func(sep string, parts ...string) string {
				var nonEmpty []string
				for _, p := range parts {
					if p != "" {
						nonEmpty = append(nonEmpty, p)
					}
				}
				return strings.Join(nonEmpty, sep)
			}, true); err != nil {
				return err
			}

			// DATEDIFF(date1, date2) - returns days
			if err := conn.RegisterFunc("datediff", func(d1, d2 string) int {
				// Simplified: uses julianday internally
				// SELECT CAST(julianday(d1) - julianday(d2) AS INTEGER)
				return 0 // Placeholder - use SQL expression instead
			}, true); err != nil {
				return err
			}

			return nil
		},
	})
}
```

### 2.3 Verwendung im Repository

```go
// Vorher (MySQL):
query := `SELECT SUBSTRING_INDEX(deviceID, '-', 1) FROM devices`

// Nachher Option 1 (SQLite mit registrierter Funktion):
query := `SELECT substring_index(deviceID, '-', 1) FROM devices`

// Nachher Option 2 (Go-Code):
var deviceID string
db.QueryRow("SELECT deviceID FROM devices WHERE id = ?", id).Scan(&deviceID)
prefix := SubstringIndex(deviceID, "-", 1)

// Vorher (MySQL):
query := `SELECT * FROM jobs WHERE created_at > DATE_ADD(NOW(), INTERVAL -30 DAY)`

// Nachher (SQLite):
query := `SELECT * FROM jobs WHERE created_at > datetime('now', '-30 days')`
```

---

## 3. Trigger-Konvertierung

### 3.1 MySQL vs SQLite Trigger-Syntax

| Aspekt | MySQL | SQLite |
|--------|-------|--------|
| DELIMITER | Erforderlich | Nicht verwendet |
| DEFINER | Unterstützt | Nicht unterstützt |
| Labeled Blocks | `label: BEGIN ... LEAVE label` | Nicht unterstützt |
| Variables | `DECLARE var TYPE` | Nicht unterstützt |
| Multiple Statements | In BEGIN...END | Nur einzelne Statements oder CASE |
| Subqueries in SET | Erlaubt | Muss anders strukturiert werden |

### 3.2 Beispiel: devices Trigger Konvertierung

**Original MySQL Trigger:**

```sql
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`%`*/ /*!50003 TRIGGER `devices` 
BEFORE INSERT ON `devices` FOR EACH ROW device_trigger: BEGIN
    DECLARE abkuerzung   VARCHAR(50);
    DECLARE pos_cat      INT;
    DECLARE next_counter INT;

    -- Skip auto-generation for virtual package devices (start with PKG_)
    IF NEW.deviceID IS NOT NULL AND NEW.deviceID LIKE 'PKG_%' THEN
      LEAVE device_trigger;
    END IF;

    -- 1) Abkürzung holen
    SELECT s.abbreviation INTO abkuerzung
      FROM subcategories s
      JOIN products p ON s.subcategoryID = p.subcategoryID
     WHERE p.productID = NEW.productID
     LIMIT 1;

    -- 2) pos_in_category holen
    SELECT p.pos_in_category INTO pos_cat
      FROM products p
     WHERE p.productID = NEW.productID;

    -- 3) Laufindex ermitteln
    SELECT COALESCE(MAX(CAST(RIGHT(d.deviceID, 3) AS UNSIGNED)), 0) + 1
      INTO next_counter
      FROM devices d
     WHERE d.deviceID LIKE CONCAT(abkuerzung, pos_cat, '%');

    -- 4) deviceID zusammenbauen
    SET NEW.deviceID = CONCAT(
        abkuerzung,
        pos_cat,
        LPAD(next_counter, 3, '0')
    );
END */;;
DELIMITER ;
```

**Konvertierter SQLite Trigger:**

```sql
-- Hinweis: SQLite-Trigger sind einfacher strukturiert.
-- Komplexe Logik sollte in Go verlagert werden.
-- Hier ein vereinfachter Trigger, der deviceID generiert:

-- Option 1: Vereinfachter Trigger (eingeschränkte Funktionalität)
CREATE TRIGGER devices_before_insert 
BEFORE INSERT ON devices
FOR EACH ROW
WHEN NEW.deviceID IS NULL OR (NEW.deviceID NOT LIKE 'PKG_%')
BEGIN
    -- SQLite kann keine komplexen Variablen, daher Workaround:
    SELECT RAISE(ABORT, 'deviceID must be set by application layer for SQLite');
END;

-- Option 2: EMPFOHLEN - Logik in Go verschieben
-- Kein Trigger, stattdessen Go-Code vor dem INSERT
```

**Empfohlene Go-Implementierung:**

```go
// GenerateDeviceID generiert eine neue DeviceID
// Diese Funktion ersetzt den MySQL-Trigger
func (r *DeviceRepository) GenerateDeviceID(ctx context.Context, productID int) (string, error) {
    // Skip für Package-Devices
    // (wird vom Caller geprüft)

    // 1) Abkürzung holen
    var abbreviation string
    var posCategory int

    err := r.db.QueryRowContext(ctx, `
        SELECT s.abbreviation, p.pos_in_category
        FROM subcategories s
        JOIN products p ON s.subcategoryID = p.subcategoryID
        WHERE p.productID = ?
        LIMIT 1
    `, productID).Scan(&abbreviation, &posCategory)
    if err != nil {
        return "", fmt.Errorf("failed to get product info: %w", err)
    }

    // 2) Prefix erstellen
    prefix := fmt.Sprintf("%s%d", abbreviation, posCategory)

    // 3) Nächsten Counter ermitteln
    var nextCounter int
    err = r.db.QueryRowContext(ctx, `
        SELECT COALESCE(MAX(CAST(substr(deviceID, -3) AS INTEGER)), 0) + 1
        FROM devices
        WHERE deviceID LIKE ? || '%'
    `, prefix).Scan(&nextCounter)
    if err != nil {
        return "", fmt.Errorf("failed to get next counter: %w", err)
    }

    // 4) DeviceID zusammenbauen
    deviceID := fmt.Sprintf("%s%03d", prefix, nextCounter)

    return deviceID, nil
}
```

### 3.3 Beispiel: cables_before_insert Trigger

**Original MySQL:**

```sql
CREATE TRIGGER `cables_before_insert` BEFORE INSERT ON `cables` FOR EACH ROW BEGIN
  DECLARE typ_name VARCHAR(50);
  DECLARE conn1_name VARCHAR(50);
  DECLARE conn2_name VARCHAR(50);

  SELECT name INTO typ_name FROM cable_types WHERE cable_typesID = NEW.typ;
  SELECT IFNULL(abbreviation, name) INTO conn1_name FROM cable_connectors WHERE cable_connectorsID = NEW.connector1;
  SELECT IFNULL(abbreviation, name) INTO conn2_name FROM cable_connectors WHERE cable_connectorsID = NEW.connector2;

  SET NEW.name = CONCAT(typ_name,' (', conn1_name, '-', conn2_name, ')', ' - ', ROUND(NEW.length, 2), ' m');
END;
```

**SQLite Alternative (Go-Code):**

```go
// GenerateCableName generiert den zusammengesetzten Kabelnamen
func (r *CableRepository) GenerateCableName(ctx context.Context, cable *Cable) error {
    var typeName string
    err := r.db.QueryRowContext(ctx, 
        "SELECT name FROM cable_types WHERE cable_typesID = ?", 
        cable.TypeID).Scan(&typeName)
    if err != nil {
        return err
    }

    var conn1Name, conn2Name string
    err = r.db.QueryRowContext(ctx,
        "SELECT COALESCE(abbreviation, name) FROM cable_connectors WHERE cable_connectorsID = ?",
        cable.Connector1ID).Scan(&conn1Name)
    if err != nil {
        return err
    }

    err = r.db.QueryRowContext(ctx,
        "SELECT COALESCE(abbreviation, name) FROM cable_connectors WHERE cable_connectorsID = ?",
        cable.Connector2ID).Scan(&conn2Name)
    if err != nil {
        return err
    }

    cable.Name = fmt.Sprintf("%s (%s-%s) - %.2f m", typeName, conn1Name, conn2Name, cable.Length)
    return nil
}
```

### 3.4 SQLite Trigger-Syntax Referenz

```sql
-- Einfacher INSERT Trigger
CREATE TRIGGER trigger_name 
AFTER INSERT ON table_name
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, action, record_id, timestamp)
    VALUES ('table_name', 'INSERT', NEW.id, datetime('now'));
END;

-- UPDATE Trigger mit Bedingung
CREATE TRIGGER trigger_name
AFTER UPDATE ON table_name
FOR EACH ROW
WHEN OLD.status != NEW.status
BEGIN
    INSERT INTO status_history (record_id, old_status, new_status, changed_at)
    VALUES (NEW.id, OLD.status, NEW.status, datetime('now'));
END;

-- INSTEAD OF Trigger (für Views)
CREATE TRIGGER trigger_name
INSTEAD OF DELETE ON view_name
FOR EACH ROW
BEGIN
    UPDATE base_table SET deleted = 1 WHERE id = OLD.id;
END;
```

---

## 4. ENUM zu TEXT Konvertierung

### 4.1 Vollständige ENUM-Liste aus RentalCore

| Tabelle | Spalte | ENUM-Werte | Empfohlener CHECK |
|---------|--------|------------|-------------------|
| `cache_rental_prices` | `period_type` | `'daily','weekly','monthly','yearly'` | ✅ CHECK empfohlen |
| `app_settings` | `scope` | `'global','warehousecore'` | ✅ CHECK empfohlen |
| `customers` | `gender` | `'male','female'` | ✅ CHECK empfohlen |
| `devices` | `status` | `'free','rented','maintance',''` | ✅ CHECK empfohlen |
| `gdpr_requests` | `request_type` | `'access','rectification','erasure','portability','restriction','objection'` | ✅ CHECK empfohlen |
| `gdpr_requests` | `status` | `'pending','processing','completed','rejected'` | ✅ CHECK empfohlen |
| `damage_reports` | `severity` | `'low','medium','high','critical'` | ✅ CHECK empfohlen |
| `damage_reports` | `status` | `'open','in_progress','repaired','closed'` | ✅ CHECK empfohlen |
| `device_movements` | `action` | `'intake','outtake','transfer','return','move'` | ✅ CHECK empfohlen |
| `device_verifications` | `verification_status` | `'valid','invalid','pending'` | ✅ CHECK empfohlen |
| `documents` | `entity_type` | `'job','device','customer','user','system'` | ✅ CHECK empfohlen |
| `documents` | `document_type` | `'contract','manual','photo','invoice','receipt','signature','other'` | ✅ CHECK empfohlen |
| `email_templates` | `template_type` | `'invoice','reminder','payment_confirmation','general'` | ✅ CHECK empfohlen |
| `job_device_history` | `action` | `'assigned','returned','maintenance','available'` | ✅ CHECK empfohlen |
| `job_transactions` | `type` | `'rental','deposit','payment','refund','fee','discount'` | ✅ CHECK empfohlen |
| `job_transactions` | `status` | `'pending','completed','failed','cancelled'` | ✅ CHECK empfohlen |
| `inventory_transactions` | `transaction_type` | `'in','out','adjustment','initial'` | ✅ CHECK empfohlen |
| `invoice_items` | `item_type` | `'device','service','package','custom'` | ✅ CHECK empfohlen |
| `settings` | `setting_type` | `'text','number','boolean','json'` | ✅ CHECK empfohlen |
| `invoices` | `status` | `'draft','sent','paid','overdue','cancelled'` | ✅ CHECK empfohlen |

### 4.2 SQLite Schema-Definitionen

```sql
-- Beispiel: devices Tabelle
CREATE TABLE devices (
    deviceID TEXT PRIMARY KEY,
    productID INTEGER NOT NULL,
    status TEXT NOT NULL DEFAULT 'free' 
        CHECK(status IN ('free', 'rented', 'maintance', '')),
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (productID) REFERENCES products(productID)
);

-- Beispiel: damage_reports Tabelle
CREATE TABLE damage_reports (
    id INTEGER PRIMARY KEY,
    device_id TEXT NOT NULL,
    severity TEXT NOT NULL DEFAULT 'medium'
        CHECK(severity IN ('low', 'medium', 'high', 'critical')),
    status TEXT NOT NULL DEFAULT 'open'
        CHECK(status IN ('open', 'in_progress', 'repaired', 'closed')),
    description TEXT,
    reported_at TEXT DEFAULT (datetime('now')),
    resolved_at TEXT,
    FOREIGN KEY (device_id) REFERENCES devices(deviceID)
);

-- Beispiel: invoices Tabelle
CREATE TABLE invoices (
    id INTEGER PRIMARY KEY,
    invoice_number TEXT UNIQUE NOT NULL,
    customer_id INTEGER NOT NULL,
    status TEXT NOT NULL DEFAULT 'draft'
        CHECK(status IN ('draft', 'sent', 'paid', 'overdue', 'cancelled')),
    total_amount REAL NOT NULL DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (customer_id) REFERENCES customers(customerID)
);

-- Beispiel: gdpr_requests Tabelle (zwei ENUMs)
CREATE TABLE gdpr_requests (
    id INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    request_type TEXT NOT NULL
        CHECK(request_type IN ('access', 'rectification', 'erasure', 
                               'portability', 'restriction', 'objection')),
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK(status IN ('pending', 'processing', 'completed', 'rejected')),
    request_data TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    completed_at TEXT,
    FOREIGN KEY (customer_id) REFERENCES customers(customerID)
);
```

### 4.3 Go Konstanten für ENUM-Werte

```go
package models

// DeviceStatus repräsentiert den Status eines Geräts
type DeviceStatus string

const (
    DeviceStatusFree      DeviceStatus = "free"
    DeviceStatusRented    DeviceStatus = "rented"
    DeviceStatusMaintance DeviceStatus = "maintance"
    DeviceStatusEmpty     DeviceStatus = ""
)

func (s DeviceStatus) IsValid() bool {
    switch s {
    case DeviceStatusFree, DeviceStatusRented, DeviceStatusMaintance, DeviceStatusEmpty:
        return true
    }
    return false
}

// DamageSeverity repräsentiert die Schwere eines Schadens
type DamageSeverity string

const (
    SeverityLow      DamageSeverity = "low"
    SeverityMedium   DamageSeverity = "medium"
    SeverityHigh     DamageSeverity = "high"
    SeverityCritical DamageSeverity = "critical"
)

func (s DamageSeverity) IsValid() bool {
    switch s {
    case SeverityLow, SeverityMedium, SeverityHigh, SeverityCritical:
        return true
    }
    return false
}

// InvoiceStatus repräsentiert den Status einer Rechnung
type InvoiceStatus string

const (
    InvoiceStatusDraft     InvoiceStatus = "draft"
    InvoiceStatusSent      InvoiceStatus = "sent"
    InvoiceStatusPaid      InvoiceStatus = "paid"
    InvoiceStatusOverdue   InvoiceStatus = "overdue"
    InvoiceStatusCancelled InvoiceStatus = "cancelled"
)

func (s InvoiceStatus) IsValid() bool {
    switch s {
    case InvoiceStatusDraft, InvoiceStatusSent, InvoiceStatusPaid, 
         InvoiceStatusOverdue, InvoiceStatusCancelled:
        return true
    }
    return false
}

// GDPRRequestType Typen für GDPR-Anfragen
type GDPRRequestType string

const (
    GDPRAccess      GDPRRequestType = "access"
    GDPRRectify     GDPRRequestType = "rectification"
    GDPRErasure     GDPRRequestType = "erasure"
    GDPRPortability GDPRRequestType = "portability"
    GDPRRestriction GDPRRequestType = "restriction"
    GDPRObjection   GDPRRequestType = "objection"
)
```

---

## 5. Weitere wichtige Konvertierungen

### 5.1 AUTO_INCREMENT zu INTEGER PRIMARY KEY

```sql
-- MySQL
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL
);

-- SQLite
CREATE TABLE users (
    id INTEGER PRIMARY KEY,  -- AUTOINCREMENT optional
    name TEXT NOT NULL
);
```

**Hinweis:** In SQLite ist `INTEGER PRIMARY KEY` automatisch auto-incrementing. `AUTOINCREMENT` erzwingt strikt steigende IDs (langsamer).

### 5.2 ON UPDATE CURRENT_TIMESTAMP

```sql
-- MySQL (automatisch)
`updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP

-- SQLite (benötigt Trigger)
CREATE TABLE example (
    id INTEGER PRIMARY KEY,
    data TEXT,
    updated_at TEXT DEFAULT (datetime('now'))
);

CREATE TRIGGER example_update_timestamp
AFTER UPDATE ON example
FOR EACH ROW
BEGIN
    UPDATE example SET updated_at = datetime('now') WHERE id = NEW.id;
END;
```

### 5.3 FULLTEXT Index zu FTS5

```sql
-- MySQL
CREATE FULLTEXT INDEX idx_customers_search ON customers(companyname, firstname, lastname, email);

SELECT * FROM customers WHERE MATCH(companyname, firstname, lastname, email) AGAINST('Smith');

-- SQLite (FTS5 Virtual Table)
CREATE VIRTUAL TABLE customers_fts USING fts5(
    customerID,
    companyname,
    firstname,
    lastname,
    email,
    content='customers',
    content_rowid='customerID'
);

-- Trigger um FTS synchron zu halten
CREATE TRIGGER customers_ai AFTER INSERT ON customers BEGIN
    INSERT INTO customers_fts(rowid, customerID, companyname, firstname, lastname, email)
    VALUES (NEW.customerID, NEW.customerID, NEW.companyname, NEW.firstname, NEW.lastname, NEW.email);
END;

CREATE TRIGGER customers_ad AFTER DELETE ON customers BEGIN
    INSERT INTO customers_fts(customers_fts, rowid, customerID, companyname, firstname, lastname, email)
    VALUES ('delete', OLD.customerID, OLD.customerID, OLD.companyname, OLD.firstname, OLD.lastname, OLD.email);
END;

CREATE TRIGGER customers_au AFTER UPDATE ON customers BEGIN
    INSERT INTO customers_fts(customers_fts, rowid, customerID, companyname, firstname, lastname, email)
    VALUES ('delete', OLD.customerID, OLD.customerID, OLD.companyname, OLD.firstname, OLD.lastname, OLD.email);
    INSERT INTO customers_fts(rowid, customerID, companyname, firstname, lastname, email)
    VALUES (NEW.customerID, NEW.customerID, NEW.companyname, NEW.firstname, NEW.lastname, NEW.email);
END;

-- Suche
SELECT c.* FROM customers c
JOIN customers_fts fts ON c.customerID = fts.customerID
WHERE customers_fts MATCH 'Smith';
```

### 5.4 GROUP_CONCAT Unterschiede

```sql
-- MySQL
SELECT GROUP_CONCAT(name SEPARATOR ', ') FROM devices;
SELECT GROUP_CONCAT(DISTINCT name ORDER BY name SEPARATOR '; ') FROM devices;

-- SQLite (Separator mit group_concat)
SELECT group_concat(name, ', ') FROM devices;
-- DISTINCT und ORDER BY: Subquery verwenden
SELECT group_concat(name, '; ') FROM (
    SELECT DISTINCT name FROM devices ORDER BY name
);
```

### 5.5 LIMIT/OFFSET

```sql
-- MySQL (beide Syntax funktionieren)
SELECT * FROM devices LIMIT 10, 20;  -- offset 10, limit 20
SELECT * FROM devices LIMIT 20 OFFSET 10;

-- SQLite (nur diese Syntax)
SELECT * FROM devices LIMIT 20 OFFSET 10;
```

### 5.6 Boolean Handling

```sql
-- MySQL
SELECT * FROM settings WHERE is_active = TRUE;
SELECT * FROM settings WHERE is_active = FALSE;

-- SQLite
SELECT * FROM settings WHERE is_active = 1;
SELECT * FROM settings WHERE is_active = 0;
-- Oder auch
SELECT * FROM settings WHERE is_active;      -- truthy
SELECT * FROM settings WHERE NOT is_active;  -- falsy
```

---

## 📝 Checkliste für die Konvertierung

- [ ] Alle `NOW()` durch `datetime('now')` ersetzen
- [ ] Alle `CURRENT_TIMESTAMP ON UPDATE` durch Trigger ersetzen
- [ ] ENUM-Spalten zu TEXT + CHECK konvertieren
- [ ] MySQL-Trigger in Go-Code verschieben
- [ ] FULLTEXT-Indizes zu FTS5 migrieren
- [ ] `ON DUPLICATE KEY UPDATE` zu `ON CONFLICT DO UPDATE` ändern
- [ ] `VALUES(col)` zu `excluded.col` ändern
- [ ] `CAST(... AS UNSIGNED)` zu `CAST(... AS INTEGER)` ändern
- [ ] Go-Hilfsfunktionen erstellen und testen
- [ ] Schema-Migrations-Dateien erstellen

---

*Dokumentation erstellt von Horst 🏆*
