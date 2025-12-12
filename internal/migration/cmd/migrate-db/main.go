// CLI-Tool für MySQL zu SQLite Migration
// Erstellt von: Wolfgang (Daten-Migrations-Experte)
// Datum: 12. Dezember 2025
package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"cores/internal/migration"
)

const version = "1.0.0"

func main() {
	// Banner
	fmt.Println(`
╔══════════════════════════════════════════════════════════════════╗
║     🗄️  MySQL → SQLite Migration Tool v` + version + `                     ║
║     Erstellt von Wolfgang - Daten-Migrations-Experte            ║
╚══════════════════════════════════════════════════════════════════╝
`)

	// Flags definieren
	source := flag.String("source", "", "MySQL DSN (user:pass@tcp(host:port)/database)")
	target := flag.String("target", "./data.db", "SQLite Datenbankpfad")
	dryRun := flag.Bool("dry-run", false, "Nur analysieren, nichts schreiben")
	verbose := flag.Bool("verbose", false, "Ausführliche Ausgabe")
	batchSize := flag.Int("batch-size", 1000, "Zeilen pro Batch")
	skipTables := flag.String("skip", "", "Tabellen überspringen (komma-getrennt)")
	onlyTables := flag.String("only", "", "Nur diese Tabellen (komma-getrennt)")
	validate := flag.Bool("validate", true, "Nach Migration validieren")
	continueOnErr := flag.Bool("continue-on-error", false, "Bei Fehlern weitermachen")
	exportOrder := flag.String("export-order", "", "Tabellen-Reihenfolge exportieren (JSON)")
	showHelp := flag.Bool("help", false, "Hilfe anzeigen")
	showVersion := flag.Bool("version", false, "Version anzeigen")

	// Hilfe-Beispiele
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, `Verwendung: migrate-db [Optionen]

Optionen:
`)
		flag.PrintDefaults()
		fmt.Fprintf(os.Stderr, `
Beispiele:
  # Vollständige Migration
  migrate-db --source "user:password@tcp(localhost:3306)/RentalCore" --target "./data.db"

  # Dry-Run (nur analysieren)
  migrate-db --source "user:pass@tcp(localhost)/db" --target "./data.db" --dry-run

  # Nur bestimmte Tabellen
  migrate-db --source "..." --target "..." --only "users,customers,products"

  # Tabellen überspringen
  migrate-db --source "..." --target "..." --skip "audit_log,audit_logs"

  # Tabellen-Reihenfolge exportieren
  migrate-db --source "..." --export-order "./table_order.json"

Umgebungsvariablen:
  MYSQL_DSN        MySQL-Verbindung (alternativ zu --source)
  SQLITE_PATH      SQLite-Pfad (alternativ zu --target)

MySQL DSN Format:
  user:password@tcp(host:port)/database?parseTime=true&charset=utf8mb4
  user:password@tcp(localhost:3306)/RentalCore
  root:@tcp(127.0.0.1:3306)/mydb

`)
	}

	flag.Parse()

	if *showVersion {
		fmt.Printf("migrate-db version %s\n", version)
		os.Exit(0)
	}

	if *showHelp {
		flag.Usage()
		os.Exit(0)
	}

	// Umgebungsvariablen als Fallback
	if *source == "" {
		*source = os.Getenv("MYSQL_DSN")
	}
	if *target == "./data.db" {
		if envTarget := os.Getenv("SQLITE_PATH"); envTarget != "" {
			*target = envTarget
		}
	}

	// Validierung
	if *source == "" {
		fmt.Println("❌ Fehler: --source ist erforderlich")
		fmt.Println("   Beispiel: --source \"user:pass@tcp(localhost:3306)/database\"")
		os.Exit(1)
	}

	// DSN normalisieren (mysql:// Prefix entfernen wenn vorhanden)
	mysqlDSN := *source
	if strings.HasPrefix(mysqlDSN, "mysql://") {
		mysqlDSN = strings.TrimPrefix(mysqlDSN, "mysql://")
	}

	// parseTime hinzufügen wenn nicht vorhanden
	if !strings.Contains(mysqlDSN, "parseTime") {
		if strings.Contains(mysqlDSN, "?") {
			mysqlDSN += "&parseTime=true"
		} else {
			mysqlDSN += "?parseTime=true"
		}
	}

	// Konfiguration erstellen
	config := migration.MigrationConfig{
		SourceDSN:     mysqlDSN,
		TargetPath:    *target,
		DryRun:        *dryRun,
		Verbose:       *verbose,
		BatchSize:     *batchSize,
		Validate:      *validate,
		ContinueOnErr: *continueOnErr,
	}

	if *skipTables != "" {
		config.SkipTables = strings.Split(*skipTables, ",")
		for i, t := range config.SkipTables {
			config.SkipTables[i] = strings.TrimSpace(t)
		}
	}

	if *onlyTables != "" {
		config.OnlyTables = strings.Split(*onlyTables, ",")
		for i, t := range config.OnlyTables {
			config.OnlyTables[i] = strings.TrimSpace(t)
		}
	}

	// Status ausgeben
	fmt.Printf("📋 Konfiguration:\n")
	fmt.Printf("   MySQL:    %s\n", maskPassword(mysqlDSN))
	fmt.Printf("   SQLite:   %s\n", *target)
	fmt.Printf("   Dry-Run:  %v\n", *dryRun)
	fmt.Printf("   Validate: %v\n", *validate)
	if len(config.SkipTables) > 0 {
		fmt.Printf("   Skip:     %v\n", config.SkipTables)
	}
	if len(config.OnlyTables) > 0 {
		fmt.Printf("   Only:     %v\n", config.OnlyTables)
	}
	fmt.Println()

	// Migrator erstellen
	migrator := migration.NewMigrator(config)

	// Fortschritts-Callback
	migrator.SetProgressCallback(func(table string, current, total int64) {
		percent := float64(current) / float64(total) * 100
		fmt.Printf("\r   %s: %.1f%% (%d/%d)", table, percent, current, total)
	})

	// Verbinden
	log.Println("🔌 Verbinde zu Datenbanken...")
	if err := migrator.Connect(); err != nil {
		log.Fatalf("❌ Verbindungsfehler: %v", err)
	}
	defer migrator.Close()
	log.Println("✅ Verbindung hergestellt")

	// Tabellen analysieren
	log.Println("🔍 Analysiere Tabellen...")
	startTime := time.Now()
	if err := migrator.AnalyzeTables(); err != nil {
		log.Fatalf("❌ Analysefehler: %v", err)
	}
	log.Printf("✅ Analyse abgeschlossen in %v", time.Since(startTime).Round(time.Millisecond))

	// Reihenfolge exportieren wenn gewünscht
	if *exportOrder != "" {
		if err := migrator.ExportTableOrder(*exportOrder); err != nil {
			log.Printf("⚠️  Export fehlgeschlagen: %v", err)
		} else {
			log.Printf("✅ Tabellen-Reihenfolge exportiert nach %s", *exportOrder)
		}
		if *dryRun {
			return
		}
	}

	// Schema erstellen
	log.Println("🏗️  Erstelle SQLite Schema...")
	if err := migrator.CreateSQLiteSchema(); err != nil {
		log.Fatalf("❌ Schema-Fehler: %v", err)
	}
	log.Println("✅ Schema erstellt")

	// Daten migrieren
	log.Println("📦 Migriere Daten...")
	if err := migrator.MigrateData(); err != nil {
		log.Fatalf("❌ Migrationsfehler: %v", err)
	}

	// Validieren
	if *validate && !*dryRun {
		results, err := migrator.Validate()
		if err != nil {
			log.Printf("⚠️  Validierungsfehler: %v", err)
		}

		// Fehler zählen
		issues := 0
		for _, r := range results {
			if !r.Match {
				issues++
			}
		}
		if issues > 0 {
			log.Printf("⚠️  %d Tabellen mit Abweichungen", issues)
		} else {
			log.Println("✅ Alle Tabellen validiert")
		}
	}

	// Zusammenfassung
	migrator.PrintSummary()

	if *dryRun {
		fmt.Println("\n💡 Dies war ein DRY-RUN. Keine Daten wurden geschrieben.")
		fmt.Println("   Führen Sie ohne --dry-run aus, um die Migration durchzuführen.")
	} else {
		fmt.Println("\n🎉 Migration erfolgreich abgeschlossen!")
		fmt.Printf("   Datenbank gespeichert unter: %s\n", *target)
	}
}

// maskPassword versteckt das Passwort im DSN für die Ausgabe
func maskPassword(dsn string) string {
	// Format: user:password@tcp(...
	atIdx := strings.Index(dsn, "@")
	if atIdx < 0 {
		return dsn
	}

	colonIdx := strings.Index(dsn, ":")
	if colonIdx < 0 || colonIdx > atIdx {
		return dsn
	}

	return dsn[:colonIdx+1] + "****" + dsn[atIdx:]
}
