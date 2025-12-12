// Package migration bietet MySQL zu SQLite Daten-Migration
// Erstellt von: Wolfgang (Daten-Migrations-Experte)
// Datum: 12. Dezember 2025
package migration

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"

	_ "github.com/go-sql-driver/mysql"
	_ "github.com/mattn/go-sqlite3"
)

// =============================================================================
// Typen und Strukturen
// =============================================================================

// MigrationConfig enthält die Konfiguration für die Migration
type MigrationConfig struct {
	SourceDSN     string // MySQL DSN
	TargetPath    string // SQLite Datenbankpfad
	DryRun        bool   // Nur simulieren
	Verbose       bool   // Ausführliche Ausgabe
	BatchSize     int    // Anzahl Zeilen pro Batch
	SkipTables    []string // Tabellen überspringen
	OnlyTables    []string // Nur diese Tabellen migrieren
	Validate      bool   // Validierung nach Migration
	ContinueOnErr bool   // Bei Fehlern weitermachen
}

// TableInfo enthält Metadaten einer Tabelle
type TableInfo struct {
	Name         string
	Columns      []ColumnInfo
	PrimaryKey   []string
	ForeignKeys  []ForeignKeyInfo
	Indexes      []IndexInfo
	RowCount     int64
	Dependencies []string // Tabellen von denen diese abhängt
}

// ColumnInfo enthält Spalteninformationen
type ColumnInfo struct {
	Name         string
	MySQLType    string
	SQLiteType   string
	IsNullable   bool
	DefaultValue sql.NullString
	IsPrimaryKey bool
	IsAutoInc    bool
	EnumValues   []string // Für ENUM-Typen
}

// ForeignKeyInfo enthält Foreign Key Informationen
type ForeignKeyInfo struct {
	Name           string
	Column         string
	RefTable       string
	RefColumn      string
	OnDelete       string
	OnUpdate       string
}

// IndexInfo enthält Index-Informationen
type IndexInfo struct {
	Name     string
	Columns  []string
	IsUnique bool
}

// MigrationResult enthält das Ergebnis der Migration
type MigrationResult struct {
	TableName     string
	RowsMigrated  int64
	RowsSkipped   int64
	Duration      time.Duration
	Error         error
	Warnings      []string
}

// Migrator führt die Migration durch
type Migrator struct {
	config      MigrationConfig
	sourceDB    *sql.DB
	targetDB    *sql.DB
	tables      []TableInfo
	results     []MigrationResult
	mu          sync.Mutex
	startTime   time.Time
	progressCB  func(table string, current, total int64)
}

// =============================================================================
// Migrations-Reihenfolge (topologisch sortiert)
// =============================================================================

// GetMigrationOrder gibt die Tabellen in korrekter Reihenfolge zurück
// Eltern-Tabellen zuerst, dann abhängige Tabellen
func GetMigrationOrder() []string {
	return []string{
		// ===== Stufe 0: Basis-Tabellen ohne Abhängigkeiten =====
		"status",
		"roles",
		"count_types",
		"cable_types",
		"cable_connectors",
		"manufacturer",
		"insuranceprovider",
		"categories",
		"subcategories",
		"subbiercategories",
		"package_categories",
		"zone_types",
		"storage_zones",
		"jobCategory",
		"retention_policies",
		"email_templates",
		"label_templates",
		"company_settings",
		"app_settings",
		"invoice_settings",

		// ===== Stufe 1: Benutzer und Kunden =====
		"users",
		"customers",
		"employee",

		// ===== Stufe 2: Benutzer-abhängige Tabellen =====
		"user_profiles",
		"user_preferences",
		"user_dashboard_widgets",
		"user_2fa",
		"user_passkeys",
		"user_roles",
		"user_roles_wh",
		"sessions",
		"user_sessions",
		"webauthn_sessions",
		"push_subscriptions",
		"saved_searches",
		"search_history",
		"offline_sync_queue",
		"authentication_attempts",

		// ===== Stufe 3: Produkte und Versicherungen =====
		"insurances",
		"brands",
		"products",

		// ===== Stufe 4: Produkt-abhängige Tabellen =====
		"product_images",
		"product_locations",
		"product_accessories",
		"product_consumables",
		"product_dependencies",
		"product_packages",
		"product_package_items",
		"product_package_aliases",
		"cables",
		"rental_equipment",

		// ===== Stufe 5: Geräte =====
		"devices",
		"cases",

		// ===== Stufe 6: Geräte-abhängige Tabellen =====
		"devicescases",
		"devicestatushistory",
		"device_movements",
		"maintenanceLogs",
		"defect_reports",
		"equipment_packages",
		"package_devices",
		"led_controllers",
		"led_controller_zone_types",
		"inventory_transactions",

		// ===== Stufe 7: Dokumente =====
		"documents",
		"digital_signatures",
		"document_signatures",
		"invoice_templates",

		// ===== Stufe 8: Jobs =====
		"jobs",

		// ===== Stufe 9: Job-abhängige Tabellen =====
		"jobdevices",
		"employeejob",
		"job_history",
		"job_attachments",
		"job_device_events",
		"job_edit_sessions",
		"job_packages",
		"job_package_reservations",
		"job_accessories",
		"job_consumables",
		"job_rental_equipment",
		"equipment_usage_logs",

		// ===== Stufe 10: Rechnungen =====
		"invoices",
		"invoice_line_items",
		"invoice_payments",
		"financial_transactions",

		// ===== Stufe 11: PDF-Verarbeitung =====
		"pdf_uploads",
		"pdf_extractions",
		"pdf_extraction_items",
		"pdf_product_mappings",
		"pdf_package_mappings",
		"pdf_mapping_events",

		// ===== Stufe 12: Audit und Compliance =====
		"audit_log",
		"audit_logs",
		"audit_events",
		"gobd_records",
		"consent_records",
		"data_processing_records",
		"data_subject_requests",
		"encrypted_personal_data",
		"archived_documents",

		// ===== Stufe 13: Analytics und Sonstiges =====
		"analytics_cache",
		"scan_events",
		"inspection_schedules",
	}
}

// =============================================================================
// Konstruktor und Initialisierung
// =============================================================================

// NewMigrator erstellt einen neuen Migrator
func NewMigrator(config MigrationConfig) *Migrator {
	if config.BatchSize <= 0 {
		config.BatchSize = 1000
	}
	return &Migrator{
		config: config,
	}
}

// SetProgressCallback setzt die Fortschritts-Callback-Funktion
func (m *Migrator) SetProgressCallback(cb func(table string, current, total int64)) {
	m.progressCB = cb
}

// =============================================================================
// Verbindungen
// =============================================================================

// Connect stellt die Verbindungen her
func (m *Migrator) Connect() error {
	var err error

	// MySQL Verbindung
	m.sourceDB, err = sql.Open("mysql", m.config.SourceDSN)
	if err != nil {
		return fmt.Errorf("MySQL Verbindungsfehler: %w", err)
	}

	// Verbindung testen
	if err = m.sourceDB.Ping(); err != nil {
		return fmt.Errorf("MySQL Ping fehlgeschlagen: %w", err)
	}

	// MySQL Timeout und Limits setzen
	m.sourceDB.SetMaxOpenConns(10)
	m.sourceDB.SetMaxIdleConns(5)
	m.sourceDB.SetConnMaxLifetime(5 * time.Minute)

	if m.config.DryRun {
		log.Println("🔍 DRY-RUN Modus: SQLite wird nicht erstellt")
		return nil
	}

	// SQLite Datei erstellen (Verzeichnis sicherstellen)
	targetDir := filepath.Dir(m.config.TargetPath)
	if err = os.MkdirAll(targetDir, 0755); err != nil {
		return fmt.Errorf("SQLite Verzeichnis erstellen: %w", err)
	}

	// SQLite Verbindung
	dsn := fmt.Sprintf("%s?_foreign_keys=off&_journal_mode=WAL&_synchronous=NORMAL&_cache_size=-64000", m.config.TargetPath)
	m.targetDB, err = sql.Open("sqlite3", dsn)
	if err != nil {
		return fmt.Errorf("SQLite Verbindungsfehler: %w", err)
	}

	// SQLite optimieren für Bulk-Import
	pragmas := []string{
		"PRAGMA foreign_keys = OFF",
		"PRAGMA synchronous = OFF",
		"PRAGMA journal_mode = MEMORY",
		"PRAGMA temp_store = MEMORY",
		"PRAGMA cache_size = -64000",
		"PRAGMA mmap_size = 268435456",
	}
	for _, pragma := range pragmas {
		if _, err = m.targetDB.Exec(pragma); err != nil {
			return fmt.Errorf("SQLite PRAGMA %s: %w", pragma, err)
		}
	}

	return nil
}

// Close schließt alle Verbindungen
func (m *Migrator) Close() {
	if m.sourceDB != nil {
		m.sourceDB.Close()
	}
	if m.targetDB != nil {
		// Foreign Keys wieder aktivieren
		m.targetDB.Exec("PRAGMA foreign_keys = ON")
		m.targetDB.Exec("PRAGMA synchronous = NORMAL")
		m.targetDB.Exec("PRAGMA journal_mode = WAL")
		m.targetDB.Close()
	}
}

// =============================================================================
// Tabellen-Analyse
// =============================================================================

// AnalyzeTables analysiert alle Tabellen in der MySQL-Datenbank
func (m *Migrator) AnalyzeTables() error {
	// Alle Tabellen abrufen
	rows, err := m.sourceDB.Query("SHOW TABLES")
	if err != nil {
		return fmt.Errorf("SHOW TABLES: %w", err)
	}
	defer rows.Close()

	var tableNames []string
	for rows.Next() {
		var name string
		if err := rows.Scan(&name); err != nil {
			return err
		}
		tableNames = append(tableNames, name)
	}

	// Migrations-Reihenfolge verwenden
	orderedTables := GetMigrationOrder()

	// Prüfen, welche Tabellen vorhanden sind
	tableExists := make(map[string]bool)
	for _, t := range tableNames {
		tableExists[t] = true
	}

	// Tabellen in Reihenfolge analysieren
	for _, tableName := range orderedTables {
		if !tableExists[tableName] {
			if m.config.Verbose {
				log.Printf("⚠️  Tabelle %s nicht in Datenbank vorhanden, überspringe", tableName)
			}
			continue
		}

		// Filter prüfen
		if len(m.config.OnlyTables) > 0 && !contains(m.config.OnlyTables, tableName) {
			continue
		}
		if contains(m.config.SkipTables, tableName) {
			continue
		}

		tableInfo, err := m.analyzeTable(tableName)
		if err != nil {
			if m.config.ContinueOnErr {
				log.Printf("⚠️  Tabelle %s analysieren fehlgeschlagen: %v", tableName, err)
				continue
			}
			return err
		}
		m.tables = append(m.tables, tableInfo)
	}

	// Tabellen die nicht in der Reihenfolge sind, am Ende hinzufügen
	for _, tableName := range tableNames {
		if !containsTable(m.tables, tableName) && 
		   !contains(m.config.SkipTables, tableName) &&
		   (len(m.config.OnlyTables) == 0 || contains(m.config.OnlyTables, tableName)) {
			tableInfo, err := m.analyzeTable(tableName)
			if err != nil {
				if m.config.ContinueOnErr {
					log.Printf("⚠️  Tabelle %s analysieren fehlgeschlagen: %v", tableName, err)
					continue
				}
				return err
			}
			m.tables = append(m.tables, tableInfo)
			log.Printf("ℹ️  Tabelle %s nicht in Migrations-Reihenfolge, am Ende hinzugefügt", tableName)
		}
	}

	return nil
}

func (m *Migrator) analyzeTable(tableName string) (TableInfo, error) {
	info := TableInfo{Name: tableName}

	// Spalten abrufen
	columnsQuery := `
		SELECT 
			COLUMN_NAME,
			COLUMN_TYPE,
			IS_NULLABLE,
			COLUMN_DEFAULT,
			COLUMN_KEY,
			EXTRA
		FROM INFORMATION_SCHEMA.COLUMNS
		WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?
		ORDER BY ORDINAL_POSITION
	`
	rows, err := m.sourceDB.Query(columnsQuery, tableName)
	if err != nil {
		return info, fmt.Errorf("Spalten abrufen für %s: %w", tableName, err)
	}
	defer rows.Close()

	for rows.Next() {
		var col ColumnInfo
		var columnType, isNullable, columnKey, extra string
		var columnDefault sql.NullString

		if err := rows.Scan(&col.Name, &columnType, &isNullable, &columnDefault, &columnKey, &extra); err != nil {
			return info, err
		}

		col.MySQLType = columnType
		col.SQLiteType = mysqlTypeToSQLite(columnType)
		col.IsNullable = isNullable == "YES"
		col.DefaultValue = columnDefault
		col.IsPrimaryKey = columnKey == "PRI"
		col.IsAutoInc = strings.Contains(extra, "auto_increment")

		// ENUM-Werte extrahieren
		if strings.HasPrefix(columnType, "enum(") {
			col.EnumValues = extractEnumValues(columnType)
		}

		info.Columns = append(info.Columns, col)

		if col.IsPrimaryKey {
			info.PrimaryKey = append(info.PrimaryKey, col.Name)
		}
	}

	// Foreign Keys abrufen
	fkQuery := `
		SELECT
			CONSTRAINT_NAME,
			COLUMN_NAME,
			REFERENCED_TABLE_NAME,
			REFERENCED_COLUMN_NAME
		FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
		WHERE TABLE_SCHEMA = DATABASE() 
		  AND TABLE_NAME = ?
		  AND REFERENCED_TABLE_NAME IS NOT NULL
	`
	fkRows, err := m.sourceDB.Query(fkQuery, tableName)
	if err != nil {
		return info, fmt.Errorf("Foreign Keys abrufen für %s: %w", tableName, err)
	}
	defer fkRows.Close()

	for fkRows.Next() {
		var fk ForeignKeyInfo
		if err := fkRows.Scan(&fk.Name, &fk.Column, &fk.RefTable, &fk.RefColumn); err != nil {
			return info, err
		}
		info.ForeignKeys = append(info.ForeignKeys, fk)
		info.Dependencies = append(info.Dependencies, fk.RefTable)
	}

	// Indices abrufen
	idxQuery := `SHOW INDEX FROM ` + quoteName(tableName)
	idxRows, err := m.sourceDB.Query(idxQuery)
	if err != nil {
		return info, fmt.Errorf("Indices abrufen für %s: %w", tableName, err)
	}
	defer idxRows.Close()

	indexMap := make(map[string]*IndexInfo)
	for idxRows.Next() {
		var table, keyName, columnName, indexType string
		var nonUnique int
		var seqInIndex int
		var collation, cardinality, subPart, packed, null, comment, indexComment, visible, expression sql.NullString

		if err := idxRows.Scan(&table, &nonUnique, &keyName, &seqInIndex, &columnName, &collation, 
			&cardinality, &subPart, &packed, &null, &indexType, &comment, &indexComment, &visible, &expression); err != nil {
			// Weniger Spalten versuchen (ältere MySQL-Versionen)
			idxRows.Close()
			break
		}

		if keyName == "PRIMARY" {
			continue // Primary Key separat behandelt
		}

		if _, exists := indexMap[keyName]; !exists {
			indexMap[keyName] = &IndexInfo{
				Name:     keyName,
				IsUnique: nonUnique == 0,
			}
		}
		indexMap[keyName].Columns = append(indexMap[keyName].Columns, columnName)
	}

	for _, idx := range indexMap {
		info.Indexes = append(info.Indexes, *idx)
	}

	// Zeilenanzahl
	countQuery := fmt.Sprintf("SELECT COUNT(*) FROM %s", quoteName(tableName))
	if err := m.sourceDB.QueryRow(countQuery).Scan(&info.RowCount); err != nil {
		log.Printf("⚠️  Zeilenanzahl für %s: %v", tableName, err)
	}

	return info, nil
}

// =============================================================================
// Schema-Erstellung in SQLite
// =============================================================================

// CreateSQLiteSchema erstellt das Schema in SQLite
func (m *Migrator) CreateSQLiteSchema() error {
	if m.config.DryRun {
		log.Println("🔍 DRY-RUN: Schema würde erstellt werden")
		return nil
	}

	for _, table := range m.tables {
		if err := m.createTable(table); err != nil {
			if m.config.ContinueOnErr {
				log.Printf("⚠️  Tabelle %s erstellen: %v", table.Name, err)
				continue
			}
			return err
		}
		if m.config.Verbose {
			log.Printf("✅ Schema für %s erstellt", table.Name)
		}
	}

	return nil
}

func (m *Migrator) createTable(table TableInfo) error {
	var columns []string

	for _, col := range table.Columns {
		colDef := fmt.Sprintf("%s %s", quoteName(col.Name), col.SQLiteType)

		if col.IsPrimaryKey && col.IsAutoInc && len(table.PrimaryKey) == 1 {
			colDef += " PRIMARY KEY AUTOINCREMENT"
		} else if !col.IsNullable {
			colDef += " NOT NULL"
		}

		// Default-Wert (transformiert)
		if col.DefaultValue.Valid && !col.IsAutoInc {
			defaultVal := transformDefaultValue(col.DefaultValue.String, col.MySQLType)
			if defaultVal != "" {
				colDef += " DEFAULT " + defaultVal
			}
		}

		columns = append(columns, colDef)
	}

	// Composite Primary Key
	if len(table.PrimaryKey) > 1 || (len(table.PrimaryKey) == 1 && !hasAutoIncPK(table)) {
		pkCols := make([]string, len(table.PrimaryKey))
		for i, pk := range table.PrimaryKey {
			pkCols[i] = quoteName(pk)
		}
		columns = append(columns, fmt.Sprintf("PRIMARY KEY (%s)", strings.Join(pkCols, ", ")))
	}

	// Foreign Keys
	for _, fk := range table.ForeignKeys {
		fkDef := fmt.Sprintf("FOREIGN KEY (%s) REFERENCES %s(%s)",
			quoteName(fk.Column), quoteName(fk.RefTable), quoteName(fk.RefColumn))
		if fk.OnDelete != "" {
			fkDef += " ON DELETE " + fk.OnDelete
		}
		if fk.OnUpdate != "" {
			fkDef += " ON UPDATE " + fk.OnUpdate
		}
		columns = append(columns, fkDef)
	}

	createSQL := fmt.Sprintf("CREATE TABLE IF NOT EXISTS %s (\n  %s\n)",
		quoteName(table.Name), strings.Join(columns, ",\n  "))

	if _, err := m.targetDB.Exec(createSQL); err != nil {
		return fmt.Errorf("CREATE TABLE %s: %w\nSQL: %s", table.Name, err, createSQL)
	}

	// Indices erstellen
	for _, idx := range table.Indexes {
		idxCols := make([]string, len(idx.Columns))
		for i, c := range idx.Columns {
			idxCols[i] = quoteName(c)
		}

		unique := ""
		if idx.IsUnique {
			unique = "UNIQUE "
		}

		idxSQL := fmt.Sprintf("CREATE %sINDEX IF NOT EXISTS %s ON %s (%s)",
			unique, quoteName(idx.Name), quoteName(table.Name), strings.Join(idxCols, ", "))

		if _, err := m.targetDB.Exec(idxSQL); err != nil {
			log.Printf("⚠️  Index %s erstellen: %v", idx.Name, err)
		}
	}

	return nil
}

// =============================================================================
// Daten-Migration
// =============================================================================

// MigrateData migriert alle Daten
func (m *Migrator) MigrateData() error {
	m.startTime = time.Now()
	totalTables := len(m.tables)

	log.Printf("🚀 Starte Migration von %d Tabellen...", totalTables)

	for i, table := range m.tables {
		log.Printf("📦 [%d/%d] Migriere %s (%d Zeilen)...", 
			i+1, totalTables, table.Name, table.RowCount)

		result := m.migrateTable(table)
		m.mu.Lock()
		m.results = append(m.results, result)
		m.mu.Unlock()

		if result.Error != nil {
			log.Printf("❌ %s: %v", table.Name, result.Error)
			if !m.config.ContinueOnErr {
				return result.Error
			}
		} else {
			log.Printf("✅ %s: %d Zeilen in %v", 
				table.Name, result.RowsMigrated, result.Duration.Round(time.Millisecond))
		}
	}

	return nil
}

func (m *Migrator) migrateTable(table TableInfo) MigrationResult {
	result := MigrationResult{TableName: table.Name}
	startTime := time.Now()

	if m.config.DryRun {
		result.RowsMigrated = table.RowCount
		result.Duration = time.Since(startTime)
		return result
	}

	if table.RowCount == 0 {
		result.Duration = time.Since(startTime)
		return result
	}

	// Spalten-Namen für SELECT und INSERT
	colNames := make([]string, len(table.Columns))
	placeholders := make([]string, len(table.Columns))
	for i, col := range table.Columns {
		colNames[i] = quoteName(col.Name)
		placeholders[i] = "?"
	}

	selectSQL := fmt.Sprintf("SELECT %s FROM %s", 
		strings.Join(colNames, ", "), quoteName(table.Name))
	insertSQL := fmt.Sprintf("INSERT INTO %s (%s) VALUES (%s)",
		quoteName(table.Name), strings.Join(colNames, ", "), strings.Join(placeholders, ", "))

	// Daten abrufen
	rows, err := m.sourceDB.Query(selectSQL)
	if err != nil {
		result.Error = fmt.Errorf("SELECT: %w", err)
		result.Duration = time.Since(startTime)
		return result
	}
	defer rows.Close()

	// Transaktion starten
	tx, err := m.targetDB.Begin()
	if err != nil {
		result.Error = fmt.Errorf("BEGIN: %w", err)
		result.Duration = time.Since(startTime)
		return result
	}
	defer func() {
		if result.Error != nil {
			tx.Rollback()
		}
	}()

	stmt, err := tx.Prepare(insertSQL)
	if err != nil {
		result.Error = fmt.Errorf("PREPARE: %w", err)
		result.Duration = time.Since(startTime)
		return result
	}
	defer stmt.Close()

	// Zeilen verarbeiten
	values := make([]interface{}, len(table.Columns))
	valuePtrs := make([]interface{}, len(table.Columns))
	for i := range values {
		valuePtrs[i] = &values[i]
	}

	batchCount := 0
	for rows.Next() {
		if err := rows.Scan(valuePtrs...); err != nil {
			result.Error = fmt.Errorf("SCAN: %w", err)
			result.Duration = time.Since(startTime)
			return result
		}

		// Werte transformieren
		transformedValues := make([]interface{}, len(values))
		for i, v := range values {
			transformedValues[i] = transformValue(v, table.Columns[i])
		}

		if _, err := stmt.Exec(transformedValues...); err != nil {
			result.Warnings = append(result.Warnings, 
				fmt.Sprintf("Zeile übersprungen: %v", err))
			result.RowsSkipped++
			if !m.config.ContinueOnErr {
				result.Error = fmt.Errorf("INSERT: %w", err)
				result.Duration = time.Since(startTime)
				return result
			}
			continue
		}

		result.RowsMigrated++
		batchCount++

		// Fortschritt melden
		if m.progressCB != nil && batchCount%1000 == 0 {
			m.progressCB(table.Name, result.RowsMigrated, table.RowCount)
		}

		// Batch commit für sehr große Tabellen
		if batchCount >= m.config.BatchSize*10 {
			if err := tx.Commit(); err != nil {
				result.Error = fmt.Errorf("COMMIT: %w", err)
				result.Duration = time.Since(startTime)
				return result
			}
			tx, err = m.targetDB.Begin()
			if err != nil {
				result.Error = fmt.Errorf("BEGIN: %w", err)
				result.Duration = time.Since(startTime)
				return result
			}
			stmt, err = tx.Prepare(insertSQL)
			if err != nil {
				result.Error = fmt.Errorf("PREPARE: %w", err)
				result.Duration = time.Since(startTime)
				return result
			}
			batchCount = 0
		}
	}

	if err := tx.Commit(); err != nil {
		result.Error = fmt.Errorf("COMMIT: %w", err)
	}

	result.Duration = time.Since(startTime)
	return result
}

// =============================================================================
// Validierung
// =============================================================================

// ValidateResult enthält das Validierungsergebnis
type ValidateResult struct {
	TableName       string
	SourceRows      int64
	TargetRows      int64
	Match           bool
	FKIntegrity     bool
	JSONValid       bool
	Issues          []string
}

// Validate prüft die Migration
func (m *Migrator) Validate() ([]ValidateResult, error) {
	if m.config.DryRun {
		log.Println("🔍 DRY-RUN: Validierung übersprungen")
		return nil, nil
	}

	log.Println("🔍 Starte Validierung...")
	var results []ValidateResult

	for _, table := range m.tables {
		result := ValidateResult{TableName: table.Name}

		// Zeilenanzahl vergleichen
		result.SourceRows = table.RowCount
		
		countQuery := fmt.Sprintf("SELECT COUNT(*) FROM %s", quoteName(table.Name))
		if err := m.targetDB.QueryRow(countQuery).Scan(&result.TargetRows); err != nil {
			result.Issues = append(result.Issues, fmt.Sprintf("Zählung fehlgeschlagen: %v", err))
		}

		result.Match = result.SourceRows == result.TargetRows

		// JSON-Spalten validieren
		result.JSONValid = true
		for _, col := range table.Columns {
			if strings.Contains(strings.ToLower(col.MySQLType), "json") {
				if !m.validateJSONColumn(table.Name, col.Name) {
					result.JSONValid = false
					result.Issues = append(result.Issues, 
						fmt.Sprintf("JSON-Spalte %s enthält ungültige Daten", col.Name))
				}
			}
		}

		results = append(results, result)

		status := "✅"
		if !result.Match {
			status = "❌"
		}
		log.Printf("%s %s: Quelle=%d, Ziel=%d", 
			status, table.Name, result.SourceRows, result.TargetRows)
	}

	// Foreign Key Integrität prüfen
	log.Println("🔗 Prüfe Foreign Key Integrität...")
	if _, err := m.targetDB.Exec("PRAGMA foreign_key_check"); err != nil {
		log.Printf("⚠️  FK-Prüfung: %v", err)
	}

	return results, nil
}

func (m *Migrator) validateJSONColumn(tableName, colName string) bool {
	query := fmt.Sprintf("SELECT %s FROM %s WHERE %s IS NOT NULL LIMIT 100",
		quoteName(colName), quoteName(tableName), quoteName(colName))
	
	rows, err := m.targetDB.Query(query)
	if err != nil {
		return false
	}
	defer rows.Close()

	for rows.Next() {
		var value sql.NullString
		if err := rows.Scan(&value); err != nil {
			return false
		}
		if value.Valid && value.String != "" {
			var js interface{}
			if err := json.Unmarshal([]byte(value.String), &js); err != nil {
				return false
			}
		}
	}
	return true
}

// =============================================================================
// Berichte
// =============================================================================

// PrintSummary gibt eine Zusammenfassung aus
func (m *Migrator) PrintSummary() {
	totalRows := int64(0)
	totalSkipped := int64(0)
	totalDuration := time.Duration(0)
	errors := 0

	fmt.Println("\n" + strings.Repeat("=", 60))
	fmt.Println("📊 MIGRATIONS-ZUSAMMENFASSUNG")
	fmt.Println(strings.Repeat("=", 60))

	for _, r := range m.results {
		totalRows += r.RowsMigrated
		totalSkipped += r.RowsSkipped
		totalDuration += r.Duration
		if r.Error != nil {
			errors++
		}
	}

	fmt.Printf("📦 Tabellen migriert:  %d\n", len(m.results))
	fmt.Printf("📝 Zeilen migriert:    %d\n", totalRows)
	fmt.Printf("⏭️  Zeilen übersprungen: %d\n", totalSkipped)
	fmt.Printf("❌ Fehler:             %d\n", errors)
	fmt.Printf("⏱️  Gesamtdauer:        %v\n", time.Since(m.startTime).Round(time.Second))
	fmt.Printf("🚀 Durchsatz:          %.0f Zeilen/Sek\n", 
		float64(totalRows)/time.Since(m.startTime).Seconds())

	if m.config.TargetPath != "" {
		if fi, err := os.Stat(m.config.TargetPath); err == nil {
			fmt.Printf("💾 Dateigröße:         %.2f MB\n", float64(fi.Size())/1024/1024)
		}
	}

	fmt.Println(strings.Repeat("=", 60))
}

// ExportTableOrder exportiert die Tabellen-Reihenfolge
func (m *Migrator) ExportTableOrder(filename string) error {
	order := GetMigrationOrder()
	
	// Mit Abhängigkeits-Info
	type TableOrder struct {
		Order        int      `json:"order"`
		TableName    string   `json:"table_name"`
		Dependencies []string `json:"dependencies,omitempty"`
		RowCount     int64    `json:"row_count,omitempty"`
	}

	var tables []TableOrder
	for i, name := range order {
		to := TableOrder{
			Order:     i + 1,
			TableName: name,
		}
		// Finde Info wenn vorhanden
		for _, t := range m.tables {
			if t.Name == name {
				to.Dependencies = t.Dependencies
				to.RowCount = t.RowCount
				break
			}
		}
		tables = append(tables, to)
	}

	data, err := json.MarshalIndent(tables, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(filename, data, 0644)
}

// =============================================================================
// Hilfsfunktionen
// =============================================================================

// mysqlTypeToSQLite konvertiert MySQL-Typen zu SQLite
func mysqlTypeToSQLite(mysqlType string) string {
	mysqlType = strings.ToLower(mysqlType)

	// Unsigned entfernen
	mysqlType = strings.ReplaceAll(mysqlType, " unsigned", "")

	switch {
	case strings.HasPrefix(mysqlType, "tinyint(1)"):
		return "INTEGER" // Boolean
	case strings.HasPrefix(mysqlType, "int"),
		strings.HasPrefix(mysqlType, "bigint"),
		strings.HasPrefix(mysqlType, "smallint"),
		strings.HasPrefix(mysqlType, "mediumint"),
		strings.HasPrefix(mysqlType, "tinyint"):
		return "INTEGER"
	case strings.HasPrefix(mysqlType, "decimal"),
		strings.HasPrefix(mysqlType, "float"),
		strings.HasPrefix(mysqlType, "double"),
		strings.HasPrefix(mysqlType, "real"):
		return "REAL"
	case strings.HasPrefix(mysqlType, "varchar"),
		strings.HasPrefix(mysqlType, "char"),
		strings.HasPrefix(mysqlType, "text"),
		strings.HasPrefix(mysqlType, "mediumtext"),
		strings.HasPrefix(mysqlType, "longtext"),
		strings.HasPrefix(mysqlType, "tinytext"):
		return "TEXT"
	case strings.HasPrefix(mysqlType, "enum"):
		return "TEXT" // ENUM als TEXT
	case strings.HasPrefix(mysqlType, "set"):
		return "TEXT" // SET als TEXT
	case strings.HasPrefix(mysqlType, "json"):
		return "TEXT" // JSON als TEXT
	case strings.HasPrefix(mysqlType, "date"),
		strings.HasPrefix(mysqlType, "datetime"),
		strings.HasPrefix(mysqlType, "timestamp"),
		strings.HasPrefix(mysqlType, "time"),
		strings.HasPrefix(mysqlType, "year"):
		return "TEXT" // Datetime als TEXT (ISO 8601)
	case strings.HasPrefix(mysqlType, "blob"),
		strings.HasPrefix(mysqlType, "binary"),
		strings.HasPrefix(mysqlType, "varbinary"),
		strings.HasPrefix(mysqlType, "mediumblob"),
		strings.HasPrefix(mysqlType, "longblob"),
		strings.HasPrefix(mysqlType, "tinyblob"):
		return "BLOB"
	default:
		return "TEXT"
	}
}

// transformDefaultValue transformiert MySQL-Default-Werte zu SQLite
func transformDefaultValue(val, mysqlType string) string {
	if val == "" {
		return ""
	}

	valLower := strings.ToLower(val)

	// NULL
	if valLower == "null" {
		return "NULL"
	}

	// CURRENT_TIMESTAMP
	if strings.Contains(valLower, "current_timestamp") {
		return "CURRENT_TIMESTAMP"
	}

	// NOW()
	if valLower == "now()" {
		return "(datetime('now'))"
	}

	// Numerische Werte
	if strings.HasPrefix(strings.ToLower(mysqlType), "int") ||
		strings.HasPrefix(strings.ToLower(mysqlType), "decimal") ||
		strings.HasPrefix(strings.ToLower(mysqlType), "float") {
		return val
	}

	// Boolean
	if strings.HasPrefix(strings.ToLower(mysqlType), "tinyint(1)") {
		if val == "1" || valLower == "true" {
			return "1"
		}
		return "0"
	}

	// String-Werte quoten wenn nötig
	if !strings.HasPrefix(val, "'") && !strings.HasPrefix(val, "\"") {
		return fmt.Sprintf("'%s'", strings.ReplaceAll(val, "'", "''"))
	}

	return val
}

// transformValue transformiert einen Datenwert
func transformValue(v interface{}, col ColumnInfo) interface{} {
	if v == nil {
		return nil
	}

	switch val := v.(type) {
	case []byte:
		strVal := string(val)

		// JSON validieren
		if strings.Contains(strings.ToLower(col.MySQLType), "json") {
			if strVal == "" {
				return nil
			}
			// Prüfen ob valides JSON
			var js interface{}
			if err := json.Unmarshal(val, &js); err != nil {
				// Ungültiges JSON, als String speichern
				return strVal
			}
			return strVal
		}

		// Timestamps im ISO-Format
		if strings.Contains(strings.ToLower(col.MySQLType), "datetime") ||
			strings.Contains(strings.ToLower(col.MySQLType), "timestamp") {
			if t, err := time.Parse("2006-01-02 15:04:05", strVal); err == nil {
				return t.Format("2006-01-02T15:04:05Z")
			}
			if t, err := time.Parse("2006-01-02 15:04:05.000000", strVal); err == nil {
				return t.Format("2006-01-02T15:04:05.000000Z")
			}
		}

		return strVal

	case time.Time:
		return val.Format("2006-01-02T15:04:05Z")

	case bool:
		if val {
			return 1
		}
		return 0

	default:
		return val
	}
}

// extractEnumValues extrahiert Werte aus ENUM-Definition
func extractEnumValues(enumType string) []string {
	// enum('val1','val2','val3')
	start := strings.Index(enumType, "(")
	end := strings.LastIndex(enumType, ")")
	if start < 0 || end < 0 {
		return nil
	}

	valuesStr := enumType[start+1 : end]
	var values []string
	for _, v := range strings.Split(valuesStr, ",") {
		v = strings.TrimSpace(v)
		v = strings.Trim(v, "'\"")
		values = append(values, v)
	}
	return values
}

// quoteName quoted einen Bezeichner für SQL
func quoteName(name string) string {
	return fmt.Sprintf("`%s`", strings.ReplaceAll(name, "`", "``"))
}

func contains(slice []string, item string) bool {
	for _, s := range slice {
		if s == item {
			return true
		}
	}
	return false
}

func containsTable(tables []TableInfo, name string) bool {
	for _, t := range tables {
		if t.Name == name {
			return true
		}
	}
	return false
}

func hasAutoIncPK(table TableInfo) bool {
	for _, col := range table.Columns {
		if col.IsPrimaryKey && col.IsAutoInc {
			return true
		}
	}
	return false
}

// =============================================================================
// Topologische Sortierung (für automatische Reihenfolge)
// =============================================================================

// TopologicalSort sortiert Tabellen nach Abhängigkeiten
func TopologicalSort(tables []TableInfo) ([]TableInfo, error) {
	// Graph erstellen
	inDegree := make(map[string]int)
	graph := make(map[string][]string)
	tableMap := make(map[string]TableInfo)

	for _, t := range tables {
		tableMap[t.Name] = t
		if _, exists := inDegree[t.Name]; !exists {
			inDegree[t.Name] = 0
		}

		for _, dep := range t.Dependencies {
			if dep == t.Name {
				continue // Selbstreferenz ignorieren
			}
			graph[dep] = append(graph[dep], t.Name)
			inDegree[t.Name]++
		}
	}

	// BFS für topologische Sortierung
	var queue []string
	for name, degree := range inDegree {
		if degree == 0 {
			queue = append(queue, name)
		}
	}

	sort.Strings(queue) // Deterministisch

	var sorted []TableInfo
	for len(queue) > 0 {
		name := queue[0]
		queue = queue[1:]

		if t, exists := tableMap[name]; exists {
			sorted = append(sorted, t)
		}

		for _, dependent := range graph[name] {
			inDegree[dependent]--
			if inDegree[dependent] == 0 {
				queue = append(queue, dependent)
				sort.Strings(queue)
			}
		}
	}

	if len(sorted) != len(tables) {
		return nil, fmt.Errorf("zirkuläre Abhängigkeit erkannt")
	}

	return sorted, nil
}
