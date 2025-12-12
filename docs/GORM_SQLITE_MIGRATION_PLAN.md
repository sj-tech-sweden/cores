# GORM SQLite Migration Plan 🚀

**Erstellt von:** Siegfried (Go/GORM-Spezialist)  
**Datum:** 12. Dezember 2025  
**Status:** Migrations-Plan

---

## 📋 Übersicht

Dieses Dokument beschreibt die komplette Migration von GORM mit MySQL-Treiber zu SQLite mit dem CGO-freien `modernc.org/sqlite` Treiber.

### Aktuelle Konfiguration

| Projekt | GORM Version | MySQL Treiber |
|---------|--------------|---------------|
| RentalCore | v1.25.4 | gorm.io/driver/mysql v1.5.1 |
| WarehouseCore | v1.31.0 | gorm.io/driver/mysql v1.6.0 |

### Ziel-Konfiguration

| Projekt | GORM Version | SQLite Treiber |
|---------|--------------|----------------|
| RentalCore | v1.25.4+ | gorm.io/driver/sqlite (modernc) |
| WarehouseCore | v1.31.0+ | gorm.io/driver/sqlite (modernc) |

---

## 1️⃣ Dependency-Änderungen

### go.mod Anpassungen

**Entfernen:**
```go
gorm.io/driver/mysql v1.x.x
github.com/go-sql-driver/mysql v1.x.x
```

**Hinzufügen:**
```go
gorm.io/driver/sqlite v1.5.7
modernc.org/sqlite v1.35.0
```

### Installation
```bash
# In beiden Projekten ausführen:
go get gorm.io/driver/sqlite@latest
go get modernc.org/sqlite@latest
go mod tidy
```

---

## 2️⃣ Connection-String-Änderungen

### MySQL (Aktuell)
```go
// RentalCore - internal/repository/database.go
dsn := fmt.Sprintf("%s:%s@tcp(%s:%d)/%s?charset=utf8mb4&parseTime=True&loc=Local",
    cfg.Username,
    cfg.Password,
    cfg.Host,
    cfg.Port,
    cfg.Database,
)
db, err := gorm.Open(mysql.Open(dsn), &gorm.Config{...})

// WarehouseCore - internal/repository/database.go  
dsn := cfg.Database.DSN()
db, err := gorm.Open(mysql.Open(dsn), &gorm.Config{...})
```

### SQLite (Neu)
```go
// SQLite Connection String Format
// Basis: "path/to/database.db"
// Mit Parametern: "file:database.db?_pragma=journal_mode(WAL)&_pragma=foreign_keys(1)"

dsn := fmt.Sprintf("file:%s?_pragma=journal_mode(WAL)&_pragma=foreign_keys(1)&_pragma=busy_timeout(5000)&_pragma=synchronous(NORMAL)&_pragma=cache_size(-64000)&_pragma=temp_store(MEMORY)",
    cfg.DatabasePath,
)
db, err := gorm.Open(sqlite.Open(dsn), &gorm.Config{...})
```

---

## 3️⃣ GORM-Tag-Änderungen

### Übersicht der nötigen Anpassungen

| MySQL GORM Tag | SQLite GORM Tag | Aktion |
|----------------|-----------------|--------|
| `AUTO_INCREMENT` | `autoIncrement` | Automatisch (GORM) |
| `type:enum('a','b')` | Entfernen + CHECK | Manuell |
| `type:json` | `type:text` | Manuell |
| `type:datetime` | `type:datetime` | Kompatibel ✓ |
| `type:date` | `type:date` | Kompatibel ✓ |
| `type:decimal(10,2)` | `type:real` | Optional |
| `default:CURRENT_TIMESTAMP` | `default:CURRENT_TIMESTAMP` | Kompatibel ✓ |

### Keine Änderungen nötig bei euren Models! 🎉

Nach Analyse der Models in `/rentalcore/internal/models/` und `/warehousecore/internal/models/`:
- Keine `type:enum` Tags gefunden
- Keine `type:json` Tags gefunden  
- Alle verwendeten GORM Tags sind SQLite-kompatibel

---

## 4️⃣ Neue Database-Konfiguration

### Empfohlene Config-Struktur

```go
// internal/config/database_config.go

type DatabaseConfig struct {
    // SQLite-spezifische Konfiguration
    DatabasePath    string        `json:"database_path" env:"DB_PATH"`
    
    // WAL Mode Einstellungen
    JournalMode     string        `json:"journal_mode" env:"DB_JOURNAL_MODE"`     // WAL, DELETE, TRUNCATE
    Synchronous     string        `json:"synchronous" env:"DB_SYNCHRONOUS"`       // OFF, NORMAL, FULL
    
    // Performance-Einstellungen
    CacheSize       int           `json:"cache_size" env:"DB_CACHE_SIZE"`         // in KB (negativ für KB)
    BusyTimeout     int           `json:"busy_timeout" env:"DB_BUSY_TIMEOUT"`     // ms
    
    // Connection Pool (SQLite-angepasst)
    MaxOpenConns    int           `json:"max_open_conns" env:"DB_MAX_OPEN_CONNS"` // Empfohlen: 1 für Write
    
    // GORM Einstellungen
    LogLevel              string        `json:"log_level" env:"DB_LOG_LEVEL"`
    SlowQueryThreshold    time.Duration `json:"slow_query_threshold"`
    PrepareStmt           bool          `json:"prepare_stmt"`
}

func GetDefaultSQLiteConfig() *DatabaseConfig {
    return &DatabaseConfig{
        DatabasePath:       "./data/rentalcore.db",
        JournalMode:        "WAL",
        Synchronous:        "NORMAL",
        CacheSize:          -64000,      // 64MB
        BusyTimeout:        5000,        // 5 Sekunden
        MaxOpenConns:       1,           // Für Writes wichtig!
        LogLevel:           "warn",
        SlowQueryThreshold: 500 * time.Millisecond,
        PrepareStmt:        true,
    }
}
```

---

## 5️⃣ Code-Beispiele

### 5.1 Neue database.go für RentalCore

```go
// internal/repository/database.go
package repository

import (
    "fmt"
    "log"
    "os"
    "path/filepath"
    "time"

    "go-barcode-webapp/internal/config"

    "gorm.io/driver/sqlite"
    "gorm.io/gorm"
    "gorm.io/gorm/logger"
    "gorm.io/gorm/schema"
)

type Database struct {
    *gorm.DB
}

// NewDatabase erstellt eine neue SQLite-Datenbankverbindung
func NewDatabase(cfg *config.DatabaseConfig) (*Database, error) {
    // Stelle sicher, dass das Verzeichnis existiert
    dbDir := filepath.Dir(cfg.DatabasePath)
    if err := os.MkdirAll(dbDir, 0755); err != nil {
        return nil, fmt.Errorf("failed to create database directory: %w", err)
    }

    // Baue DSN mit SQLite Pragmas
    dsn := buildSQLiteDSN(cfg)

    db, err := gorm.Open(sqlite.Open(dsn), &gorm.Config{
        Logger: logger.Default.LogMode(logger.Warn),
        PrepareStmt: cfg.PrepareStmt,
        SkipDefaultTransaction: true,
        CreateBatchSize: 100, // Reduziert für SQLite
        NamingStrategy: schema.NamingStrategy{
            SingularTable: true,
        },
        // Wichtig für SQLite: Keine FK-Constraints beim Migrieren
        DisableForeignKeyConstraintWhenMigrating: true,
    })
    if err != nil {
        return nil, fmt.Errorf("failed to connect to database: %w", err)
    }

    sqlDB, err := db.DB()
    if err != nil {
        return nil, fmt.Errorf("failed to get sql.DB: %w", err)
    }

    // SQLite-optimierte Connection Pool Einstellungen
    // WICHTIG: SQLite unterstützt nur eine Write-Connection!
    sqlDB.SetMaxOpenConns(cfg.MaxOpenConns)
    sqlDB.SetMaxIdleConns(1)
    sqlDB.SetConnMaxLifetime(time.Hour)
    sqlDB.SetConnMaxIdleTime(30 * time.Minute)

    // Setze zusätzliche Pragmas nach der Verbindung
    if err := configureSQLitePragmas(db, cfg); err != nil {
        return nil, fmt.Errorf("failed to configure SQLite pragmas: %w", err)
    }

    log.Printf("SQLite database connected: %s", cfg.DatabasePath)
    return &Database{db}, nil
}

// buildSQLiteDSN erstellt den SQLite Connection String
func buildSQLiteDSN(cfg *config.DatabaseConfig) string {
    // Basis-DSN
    if cfg.DatabasePath == ":memory:" {
        return "file::memory:?cache=shared"
    }
    
    return fmt.Sprintf("file:%s?_pragma=busy_timeout(%d)&_pragma=foreign_keys(1)",
        cfg.DatabasePath,
        cfg.BusyTimeout,
    )
}

// configureSQLitePragmas setzt wichtige SQLite Pragmas
func configureSQLitePragmas(db *gorm.DB, cfg *config.DatabaseConfig) error {
    pragmas := []struct {
        name  string
        value interface{}
    }{
        {"journal_mode", cfg.JournalMode},
        {"synchronous", cfg.Synchronous},
        {"cache_size", cfg.CacheSize},
        {"temp_store", "MEMORY"},
        {"mmap_size", 268435456}, // 256MB memory-mapped I/O
    }

    for _, p := range pragmas {
        sql := fmt.Sprintf("PRAGMA %s = %v", p.name, p.value)
        if err := db.Exec(sql).Error; err != nil {
            return fmt.Errorf("failed to set pragma %s: %w", p.name, err)
        }
    }

    // Verifiziere WAL-Mode
    var journalMode string
    db.Raw("PRAGMA journal_mode").Scan(&journalMode)
    log.Printf("SQLite journal_mode: %s", journalMode)

    return nil
}

func (db *Database) Close() error {
    sqlDB, err := db.DB.DB()
    if err != nil {
        return err
    }
    return sqlDB.Close()
}

func (db *Database) Ping() error {
    sqlDB, err := db.DB.DB()
    if err != nil {
        return err
    }
    return sqlDB.Ping()
}

// Checkpoint führt einen WAL-Checkpoint durch
func (db *Database) Checkpoint() error {
    return db.Exec("PRAGMA wal_checkpoint(TRUNCATE)").Error
}

// Vacuum optimiert die Datenbank
func (db *Database) Vacuum() error {
    return db.Exec("VACUUM").Error
}

// Optimize führt SQLite-Optimierungen durch
func (db *Database) Optimize() error {
    return db.Exec("PRAGMA optimize").Error
}
```

### 5.2 Neue database.go für WarehouseCore

```go
// internal/repository/database.go
package repository

import (
    "crypto/sha256"
    "database/sql"
    "encoding/hex"
    "errors"
    "fmt"
    "log"
    "os"
    "path/filepath"
    "time"

    "gorm.io/driver/sqlite"
    "gorm.io/gorm"
    "warehousecore/config"
)

// Common errors
var (
    ErrNotFound = errors.New("not found")
)

// DB holds the database connection pool
var DB *sql.DB

// GormDB holds the GORM database connection for auth and models
var GormDB *gorm.DB

// InitDatabase initializes the SQLite database connection
func InitDatabase(cfg *config.Config) error {
    // Stelle sicher, dass das Verzeichnis existiert
    dbDir := filepath.Dir(cfg.Database.Path)
    if err := os.MkdirAll(dbDir, 0755); err != nil {
        return fmt.Errorf("failed to create database directory: %w", err)
    }

    // SQLite DSN
    dsn := buildSQLiteDSN(cfg.Database.Path)

    // Öffne sql.DB für direkte SQL-Queries
    sqlDB, err := sql.Open("sqlite", dsn)
    if err != nil {
        return fmt.Errorf("failed to open database: %w", err)
    }

    // SQLite-optimierte Pool-Einstellungen
    sqlDB.SetMaxOpenConns(1) // Wichtig für SQLite Writes!
    sqlDB.SetMaxIdleConns(1)
    sqlDB.SetConnMaxLifetime(time.Hour)
    sqlDB.SetConnMaxIdleTime(30 * time.Minute)

    // Test connection
    if err := sqlDB.Ping(); err != nil {
        return fmt.Errorf("failed to ping database: %w", err)
    }

    DB = sqlDB
    log.Printf("SQLite database connection established: %s", cfg.Database.Path)

    // Initialize GORM
    gormDB, err := gorm.Open(sqlite.Open(dsn), &gorm.Config{
        SkipDefaultTransaction: true,
        PrepareStmt:            true,
        CreateBatchSize:        100,
        DisableForeignKeyConstraintWhenMigrating: true,
    })
    if err != nil {
        return fmt.Errorf("failed to initialize GORM: %w", err)
    }

    // Setze SQLite Pragmas
    if err := configurePragmas(gormDB); err != nil {
        return fmt.Errorf("failed to configure pragmas: %w", err)
    }

    GormDB = gormDB
    log.Println("GORM SQLite connection established successfully")

    return nil
}

func buildSQLiteDSN(path string) string {
    if path == ":memory:" {
        return "file::memory:?cache=shared"
    }
    return fmt.Sprintf("file:%s?_pragma=busy_timeout(5000)&_pragma=foreign_keys(1)", path)
}

func configurePragmas(db *gorm.DB) error {
    pragmas := []string{
        "PRAGMA journal_mode = WAL",
        "PRAGMA synchronous = NORMAL",
        "PRAGMA cache_size = -64000",
        "PRAGMA temp_store = MEMORY",
        "PRAGMA mmap_size = 268435456",
    }
    
    for _, pragma := range pragmas {
        if err := db.Exec(pragma).Error; err != nil {
            return err
        }
    }
    return nil
}

// CloseDatabase closes the database connection
func CloseDatabase() error {
    if GormDB != nil {
        sqlDB, _ := GormDB.DB()
        if sqlDB != nil {
            // WAL Checkpoint vor dem Schließen
            GormDB.Exec("PRAGMA wal_checkpoint(TRUNCATE)")
        }
    }
    if DB != nil {
        return DB.Close()
    }
    return nil
}

// GetDB returns the GORM database connection
func GetDB() *gorm.DB {
    return GormDB
}

// GetSQLDB returns the raw SQL database connection
func GetSQLDB() *sql.DB {
    return DB
}

// HashAPIKey creates a stable SHA-256 hex hash of an API key.
func HashAPIKey(key string) string {
    sum := sha256.Sum256([]byte(key))
    return hex.EncodeToString(sum[:])
}
```

### 5.3 JSON Column Handler für SQLite

```go
// internal/database/json_type.go
package database

import (
    "database/sql/driver"
    "encoding/json"
    "errors"
    "fmt"
)

// JSONMap ist ein GORM-kompatibler Typ für JSON-Spalten in SQLite
// Wird als TEXT gespeichert und beim Lesen/Schreiben (de)serialisiert
type JSONMap map[string]interface{}

// Value implementiert driver.Valuer für Datenbank-Writes
func (j JSONMap) Value() (driver.Value, error) {
    if j == nil {
        return nil, nil
    }
    return json.Marshal(j)
}

// Scan implementiert sql.Scanner für Datenbank-Reads
func (j *JSONMap) Scan(value interface{}) error {
    if value == nil {
        *j = nil
        return nil
    }

    var bytes []byte
    switch v := value.(type) {
    case []byte:
        bytes = v
    case string:
        bytes = []byte(v)
    default:
        return errors.New(fmt.Sprintf("failed to unmarshal JSON: unsupported type %T", value))
    }

    result := make(map[string]interface{})
    if err := json.Unmarshal(bytes, &result); err != nil {
        return err
    }
    *j = result
    return nil
}

// GormDataType gibt den GORM-Datentyp zurück
func (JSONMap) GormDataType() string {
    return "text"
}

// JSONArray ist ein GORM-kompatibler Typ für JSON-Arrays in SQLite
type JSONArray []interface{}

// Value implementiert driver.Valuer
func (j JSONArray) Value() (driver.Value, error) {
    if j == nil {
        return nil, nil
    }
    return json.Marshal(j)
}

// Scan implementiert sql.Scanner
func (j *JSONArray) Scan(value interface{}) error {
    if value == nil {
        *j = nil
        return nil
    }

    var bytes []byte
    switch v := value.(type) {
    case []byte:
        bytes = v
    case string:
        bytes = []byte(v)
    default:
        return errors.New(fmt.Sprintf("failed to unmarshal JSON array: unsupported type %T", value))
    }

    var result []interface{}
    if err := json.Unmarshal(bytes, &result); err != nil {
        return err
    }
    *j = result
    return nil
}

// GormDataType gibt den GORM-Datentyp zurück
func (JSONArray) GormDataType() string {
    return "text"
}

// JSONString ist für typisierte JSON-Strings (z.B. für Settings)
type JSONString[T any] struct {
    Data T
}

// Value implementiert driver.Valuer
func (j JSONString[T]) Value() (driver.Value, error) {
    return json.Marshal(j.Data)
}

// Scan implementiert sql.Scanner
func (j *JSONString[T]) Scan(value interface{}) error {
    if value == nil {
        return nil
    }

    var bytes []byte
    switch v := value.(type) {
    case []byte:
        bytes = v
    case string:
        bytes = []byte(v)
    default:
        return fmt.Errorf("unsupported type: %T", value)
    }

    return json.Unmarshal(bytes, &j.Data)
}

// GormDataType gibt den GORM-Datentyp zurück
func (JSONString[T]) GormDataType() string {
    return "text"
}
```

### 5.4 Migrations-Helper-Funktionen

```go
// internal/database/migration_helpers.go
package database

import (
    "fmt"
    "log"
    "strings"

    "gorm.io/gorm"
)

// MigrationHelper bietet SQLite-spezifische Migrations-Unterstützung
type MigrationHelper struct {
    db *gorm.DB
}

// NewMigrationHelper erstellt einen neuen Migration Helper
func NewMigrationHelper(db *gorm.DB) *MigrationHelper {
    return &MigrationHelper{db: db}
}

// CreateTableWithCheck erstellt eine Tabelle mit CHECK-Constraints
// als Ersatz für MySQL ENUM
func (m *MigrationHelper) CreateTableWithCheck(tableName string, columns []ColumnDef, checks []CheckConstraint) error {
    var colDefs []string
    for _, col := range columns {
        colDefs = append(colDefs, fmt.Sprintf("%s %s", col.Name, col.Definition))
    }
    
    var checkDefs []string
    for _, check := range checks {
        checkDefs = append(checkDefs, fmt.Sprintf("CHECK(%s)", check.Expression))
    }
    
    allDefs := append(colDefs, checkDefs...)
    sql := fmt.Sprintf("CREATE TABLE IF NOT EXISTS %s (\n  %s\n)", 
        tableName, 
        strings.Join(allDefs, ",\n  "))
    
    return m.db.Exec(sql).Error
}

// ColumnDef beschreibt eine Spaltendefinition
type ColumnDef struct {
    Name       string
    Definition string
}

// CheckConstraint beschreibt einen CHECK-Constraint
type CheckConstraint struct {
    Name       string
    Expression string
}

// AddCheckConstraint fügt einen CHECK-Constraint zu einer bestehenden Tabelle hinzu
// Hinweis: SQLite unterstützt kein ALTER TABLE ADD CONSTRAINT,
// daher muss die Tabelle neu erstellt werden
func (m *MigrationHelper) AddCheckConstraint(tableName, columnName string, allowedValues []string) error {
    // Für bestehende Tabellen: Validierung nur via Trigger möglich
    quotedValues := make([]string, len(allowedValues))
    for i, v := range allowedValues {
        quotedValues[i] = fmt.Sprintf("'%s'", v)
    }
    
    triggerSQL := fmt.Sprintf(`
        CREATE TRIGGER IF NOT EXISTS check_%s_%s_insert
        BEFORE INSERT ON %s
        FOR EACH ROW
        BEGIN
            SELECT CASE 
                WHEN NEW.%s NOT IN (%s) 
                THEN RAISE(ABORT, 'Invalid value for %s')
            END;
        END;
        
        CREATE TRIGGER IF NOT EXISTS check_%s_%s_update
        BEFORE UPDATE ON %s
        FOR EACH ROW
        BEGIN
            SELECT CASE 
                WHEN NEW.%s NOT IN (%s) 
                THEN RAISE(ABORT, 'Invalid value for %s')
            END;
        END;
    `, tableName, columnName, tableName, columnName, strings.Join(quotedValues, ", "), columnName,
       tableName, columnName, tableName, columnName, strings.Join(quotedValues, ", "), columnName)
    
    return m.db.Exec(triggerSQL).Error
}

// MigrateEnumToCheck erstellt Trigger für ENUM-Validierung
func (m *MigrationHelper) MigrateEnumToCheck(tableName, columnName string, enumValues []string) error {
    log.Printf("Creating CHECK trigger for %s.%s with values: %v", tableName, columnName, enumValues)
    return m.AddCheckConstraint(tableName, columnName, enumValues)
}

// CreateIndex erstellt einen Index mit SQLite-Syntax
func (m *MigrationHelper) CreateIndex(tableName, indexName string, columns []string, unique bool) error {
    uniqueStr := ""
    if unique {
        uniqueStr = "UNIQUE "
    }
    
    sql := fmt.Sprintf("CREATE %sINDEX IF NOT EXISTS %s ON %s (%s)",
        uniqueStr, indexName, tableName, strings.Join(columns, ", "))
    
    return m.db.Exec(sql).Error
}

// EnableForeignKeys aktiviert Foreign Key Constraints
func (m *MigrationHelper) EnableForeignKeys() error {
    return m.db.Exec("PRAGMA foreign_keys = ON").Error
}

// DisableForeignKeys deaktiviert Foreign Key Constraints (für Migrationen)
func (m *MigrationHelper) DisableForeignKeys() error {
    return m.db.Exec("PRAGMA foreign_keys = OFF").Error
}

// RebuildTable erstellt eine Tabelle neu (für Schema-Änderungen in SQLite)
// Dies ist nötig, da SQLite kein vollständiges ALTER TABLE unterstützt
func (m *MigrationHelper) RebuildTable(tableName string, newSchema string) error {
    return m.db.Transaction(func(tx *gorm.DB) error {
        // 1. Disable FK
        if err := tx.Exec("PRAGMA foreign_keys = OFF").Error; err != nil {
            return err
        }
        
        // 2. Rename old table
        oldName := tableName + "_old"
        if err := tx.Exec(fmt.Sprintf("ALTER TABLE %s RENAME TO %s", tableName, oldName)).Error; err != nil {
            return err
        }
        
        // 3. Create new table
        if err := tx.Exec(newSchema).Error; err != nil {
            return err
        }
        
        // 4. Copy data (user must specify columns)
        // Dies muss vom Aufrufer angepasst werden
        
        // 5. Drop old table
        if err := tx.Exec(fmt.Sprintf("DROP TABLE %s", oldName)).Error; err != nil {
            return err
        }
        
        // 6. Re-enable FK
        if err := tx.Exec("PRAGMA foreign_keys = ON").Error; err != nil {
            return err
        }
        
        return nil
    })
}

// CheckTableExists prüft ob eine Tabelle existiert
func (m *MigrationHelper) CheckTableExists(tableName string) (bool, error) {
    var count int64
    err := m.db.Raw("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name=?", tableName).Scan(&count).Error
    return count > 0, err
}

// GetTableInfo gibt Informationen über eine Tabelle zurück
func (m *MigrationHelper) GetTableInfo(tableName string) ([]TableColumn, error) {
    var columns []TableColumn
    rows, err := m.db.Raw(fmt.Sprintf("PRAGMA table_info(%s)", tableName)).Rows()
    if err != nil {
        return nil, err
    }
    defer rows.Close()
    
    for rows.Next() {
        var col TableColumn
        var dflt interface{}
        if err := rows.Scan(&col.CID, &col.Name, &col.Type, &col.NotNull, &dflt, &col.PK); err != nil {
            return nil, err
        }
        if dflt != nil {
            s := fmt.Sprintf("%v", dflt)
            col.DefaultValue = &s
        }
        columns = append(columns, col)
    }
    return columns, nil
}

// TableColumn beschreibt eine Tabellenspalte
type TableColumn struct {
    CID          int
    Name         string
    Type         string
    NotNull      bool
    DefaultValue *string
    PK           bool
}

// IntegrityCheck führt eine Integritätsprüfung durch
func (m *MigrationHelper) IntegrityCheck() ([]string, error) {
    var results []string
    rows, err := m.db.Raw("PRAGMA integrity_check").Rows()
    if err != nil {
        return nil, err
    }
    defer rows.Close()
    
    for rows.Next() {
        var result string
        if err := rows.Scan(&result); err != nil {
            return nil, err
        }
        results = append(results, result)
    }
    return results, nil
}
```

---

## 6️⃣ Wichtige SQLite-Unterschiede zu beachten

### 6.1 Connection Pool

```go
// MySQL - Mehrere Connections möglich
sqlDB.SetMaxOpenConns(50)
sqlDB.SetMaxIdleConns(10)

// SQLite - NUR EINE Write-Connection!
sqlDB.SetMaxOpenConns(1)  // WICHTIG!
sqlDB.SetMaxIdleConns(1)
```

### 6.2 Transaktionen

SQLite sperrt die gesamte Datenbank bei Writes. Mit WAL-Mode sind parallele Reads möglich.

```go
// GORM-Einstellung bereits korrekt:
SkipDefaultTransaction: true  // Verhindert unnötige Transaktions-Overhead
```

### 6.3 AUTO_INCREMENT

```go
// MySQL
`gorm:"primaryKey;autoIncrement"`

// SQLite - GORM handhabt das automatisch!
// INTEGER PRIMARY KEY ist automatisch ROWID alias
`gorm:"primaryKey"` // Reicht für SQLite
```

### 6.4 Keine ENUM-Typen

SQLite hat keine ENUM-Typen. Verwende stattdessen:

1. **CHECK-Constraints** (bei Tabellen-Erstellung)
2. **Trigger** (für bestehende Tabellen)
3. **Applikations-Validierung** (empfohlen für Go)

```go
// Statt ENUM in Model:
type Status string

const (
    StatusFree     Status = "free"
    StatusRented   Status = "rented"
    StatusRepair   Status = "repair"
)

// Validierung in Go:
func (s Status) IsValid() bool {
    switch s {
    case StatusFree, StatusRented, StatusRepair:
        return true
    }
    return false
}
```

---

## 7️⃣ Environment-Variable-Änderungen

### Alt (MySQL)
```env
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=rentalcore
DB_USERNAME=rentalcore_user
DB_PASSWORD=secret
```

### Neu (SQLite)
```env
DB_PATH=./data/rentalcore.db
DB_JOURNAL_MODE=WAL
DB_SYNCHRONOUS=NORMAL
DB_CACHE_SIZE=-64000
DB_BUSY_TIMEOUT=5000
```

---

## 8️⃣ Checkliste für die Migration

### Pre-Migration
- [ ] Backup der MySQL-Datenbank erstellen
- [ ] go.mod Dependencies aktualisieren
- [ ] SQLite-Datenbankdatei-Pfad festlegen
- [ ] Datenverzeichnis erstellen

### Code-Änderungen
- [ ] database.go in RentalCore anpassen
- [ ] database.go in WarehouseCore anpassen
- [ ] Config-Structs aktualisieren
- [ ] Environment-Variablen anpassen
- [ ] Import-Statements ändern

### Post-Migration
- [ ] Tests ausführen
- [ ] Performance-Tests durchführen
- [ ] WAL-Mode verifizieren
- [ ] Foreign Keys verifizieren

---

## 9️⃣ Referenzen

- [gorm.io/driver/sqlite](https://github.com/go-gorm/sqlite)
- [modernc.org/sqlite](https://pkg.go.dev/modernc.org/sqlite)
- [SQLite Pragmas](https://www.sqlite.org/pragma.html)
- [SQLite WAL Mode](https://www.sqlite.org/wal.html)

---

**Nächste Schritte:**
1. Führe die Dependency-Updates durch
2. Erstelle die neuen database.go Dateien
3. Migriere die Daten von MySQL zu SQLite
4. Teste gründlich!

*Siegfried, dein Go/GORM-Spezialist* 💪
