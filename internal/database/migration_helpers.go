// Package database provides GORM migration helpers for SQLite
// Diese Datei enthält Hilfsfunktionen für Schema-Migrationen
package database

import (
	"fmt"
	"log"
	"strings"
	"time"

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

// =============================================================================
// CHECK-Constraints (Ersatz für MySQL ENUM)
// =============================================================================

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

// AddCheckConstraintViaTrigger fügt Validierung via Trigger hinzu
// SQLite unterstützt kein ALTER TABLE ADD CONSTRAINT für bestehende Tabellen
func (m *MigrationHelper) AddCheckConstraintViaTrigger(tableName, columnName string, allowedValues []string) error {
	quotedValues := make([]string, len(allowedValues))
	for i, v := range allowedValues {
		quotedValues[i] = fmt.Sprintf("'%s'", v)
	}
	valueList := strings.Join(quotedValues, ", ")

	// Insert Trigger
	insertTrigger := fmt.Sprintf(`
		CREATE TRIGGER IF NOT EXISTS check_%s_%s_insert
		BEFORE INSERT ON %s
		FOR EACH ROW
		BEGIN
			SELECT CASE 
				WHEN NEW.%s NOT IN (%s) 
				THEN RAISE(ABORT, 'Invalid value for %s')
			END;
		END
	`, tableName, columnName, tableName, columnName, valueList, columnName)

	if err := m.db.Exec(insertTrigger).Error; err != nil {
		return fmt.Errorf("failed to create insert trigger: %w", err)
	}

	// Update Trigger
	updateTrigger := fmt.Sprintf(`
		CREATE TRIGGER IF NOT EXISTS check_%s_%s_update
		BEFORE UPDATE ON %s
		FOR EACH ROW
		BEGIN
			SELECT CASE 
				WHEN NEW.%s NOT IN (%s) 
				THEN RAISE(ABORT, 'Invalid value for %s')
			END;
		END
	`, tableName, columnName, tableName, columnName, valueList, columnName)

	if err := m.db.Exec(updateTrigger).Error; err != nil {
		return fmt.Errorf("failed to create update trigger: %w", err)
	}

	log.Printf("Created CHECK triggers for %s.%s with values: %v", tableName, columnName, allowedValues)
	return nil
}

// MigrateEnumToCheck erstellt Trigger für ENUM-Validierung
// Wrapper für AddCheckConstraintViaTrigger mit besserem Namen
func (m *MigrationHelper) MigrateEnumToCheck(tableName, columnName string, enumValues []string) error {
	return m.AddCheckConstraintViaTrigger(tableName, columnName, enumValues)
}

// =============================================================================
// Index-Management
// =============================================================================

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

// DropIndex löscht einen Index
func (m *MigrationHelper) DropIndex(indexName string) error {
	return m.db.Exec(fmt.Sprintf("DROP INDEX IF EXISTS %s", indexName)).Error
}

// IndexExists prüft ob ein Index existiert
func (m *MigrationHelper) IndexExists(indexName string) (bool, error) {
	var count int64
	err := m.db.Raw("SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name=?", indexName).Scan(&count).Error
	return count > 0, err
}

// =============================================================================
// Foreign Keys
// =============================================================================

// EnableForeignKeys aktiviert Foreign Key Constraints
func (m *MigrationHelper) EnableForeignKeys() error {
	return m.db.Exec("PRAGMA foreign_keys = ON").Error
}

// DisableForeignKeys deaktiviert Foreign Key Constraints (für Migrationen)
func (m *MigrationHelper) DisableForeignKeys() error {
	return m.db.Exec("PRAGMA foreign_keys = OFF").Error
}

// CheckForeignKeys prüft auf Foreign Key Verletzungen
func (m *MigrationHelper) CheckForeignKeys() ([]ForeignKeyViolation, error) {
	var violations []ForeignKeyViolation
	rows, err := m.db.Raw("PRAGMA foreign_key_check").Rows()
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	for rows.Next() {
		var v ForeignKeyViolation
		if err := rows.Scan(&v.Table, &v.RowID, &v.Parent, &v.FKIndex); err != nil {
			return nil, err
		}
		violations = append(violations, v)
	}
	return violations, nil
}

// ForeignKeyViolation beschreibt eine FK-Verletzung
type ForeignKeyViolation struct {
	Table   string
	RowID   int64
	Parent  string
	FKIndex int
}

// =============================================================================
// Table-Rebuilding (für Schema-Änderungen)
// =============================================================================

// RebuildTableWithNewSchema erstellt eine Tabelle mit neuem Schema neu
// Dies ist nötig, da SQLite kein vollständiges ALTER TABLE unterstützt
func (m *MigrationHelper) RebuildTableWithNewSchema(tableName, newSchema string, columnMapping map[string]string) error {
	return m.db.Transaction(func(tx *gorm.DB) error {
		// 1. Disable FK
		if err := tx.Exec("PRAGMA foreign_keys = OFF").Error; err != nil {
			return err
		}

		// 2. Rename old table
		tempName := tableName + "_old_" + fmt.Sprintf("%d", time.Now().Unix())
		if err := tx.Exec(fmt.Sprintf("ALTER TABLE %s RENAME TO %s", tableName, tempName)).Error; err != nil {
			return err
		}

		// 3. Create new table
		if err := tx.Exec(newSchema).Error; err != nil {
			// Rollback: rename back
			tx.Exec(fmt.Sprintf("ALTER TABLE %s RENAME TO %s", tempName, tableName))
			return err
		}

		// 4. Copy data
		if columnMapping != nil && len(columnMapping) > 0 {
			var oldCols, newCols []string
			for old, new := range columnMapping {
				oldCols = append(oldCols, old)
				newCols = append(newCols, new)
			}
			copySQL := fmt.Sprintf("INSERT INTO %s (%s) SELECT %s FROM %s",
				tableName,
				strings.Join(newCols, ", "),
				strings.Join(oldCols, ", "),
				tempName)
			if err := tx.Exec(copySQL).Error; err != nil {
				return err
			}
		}

		// 5. Drop old table
		if err := tx.Exec(fmt.Sprintf("DROP TABLE %s", tempName)).Error; err != nil {
			return err
		}

		// 6. Re-enable FK
		if err := tx.Exec("PRAGMA foreign_keys = ON").Error; err != nil {
			return err
		}

		return nil
	})
}

// =============================================================================
// Table-Informationen
// =============================================================================

// TableColumn beschreibt eine Tabellenspalte
type TableColumn struct {
	CID          int
	Name         string
	Type         string
	NotNull      bool
	DefaultValue *string
	PK           bool
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

// GetTableSQL gibt das CREATE TABLE Statement zurück
func (m *MigrationHelper) GetTableSQL(tableName string) (string, error) {
	var sql string
	err := m.db.Raw("SELECT sql FROM sqlite_master WHERE type='table' AND name=?", tableName).Scan(&sql).Error
	return sql, err
}

// ListTables gibt alle Tabellennamen zurück
func (m *MigrationHelper) ListTables() ([]string, error) {
	var tables []string
	rows, err := m.db.Raw("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name").Rows()
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	for rows.Next() {
		var name string
		if err := rows.Scan(&name); err != nil {
			return nil, err
		}
		tables = append(tables, name)
	}
	return tables, nil
}

// =============================================================================
// Database-Wartung
// =============================================================================

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

// QuickCheck führt eine schnelle Integritätsprüfung durch
func (m *MigrationHelper) QuickCheck() ([]string, error) {
	var results []string
	rows, err := m.db.Raw("PRAGMA quick_check").Rows()
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

// Vacuum optimiert die Datenbank
func (m *MigrationHelper) Vacuum() error {
	return m.db.Exec("VACUUM").Error
}

// Analyze aktualisiert die Statistiken
func (m *MigrationHelper) Analyze() error {
	return m.db.Exec("ANALYZE").Error
}

// Checkpoint führt einen WAL-Checkpoint durch
func (m *MigrationHelper) Checkpoint() error {
	return m.db.Exec("PRAGMA wal_checkpoint(TRUNCATE)").Error
}

// Optimize führt SQLite-Optimierungen durch
func (m *MigrationHelper) Optimize() error {
	return m.db.Exec("PRAGMA optimize").Error
}
