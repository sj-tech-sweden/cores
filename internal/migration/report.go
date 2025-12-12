// Package migration - Statistiken und Berichte
package migration

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"time"
)

// MigrationReport enthält den vollständigen Migrationsbericht
type MigrationReport struct {
	StartTime       time.Time              `json:"start_time"`
	EndTime         time.Time              `json:"end_time"`
	Duration        string                 `json:"duration"`
	SourceDSN       string                 `json:"source_dsn"`
	TargetPath      string                 `json:"target_path"`
	TotalTables     int                    `json:"total_tables"`
	SuccessfulTables int                   `json:"successful_tables"`
	FailedTables    int                    `json:"failed_tables"`
	TotalRows       int64                  `json:"total_rows"`
	SkippedRows     int64                  `json:"skipped_rows"`
	FileSize        int64                  `json:"file_size_bytes"`
	FileSizeHuman   string                 `json:"file_size_human"`
	Throughput      float64                `json:"throughput_rows_per_sec"`
	Tables          []TableMigrationReport `json:"tables"`
	Validation      *ValidationReport      `json:"validation,omitempty"`
}

// TableMigrationReport enthält den Bericht für eine Tabelle
type TableMigrationReport struct {
	Name          string        `json:"name"`
	RowsMigrated  int64         `json:"rows_migrated"`
	RowsSkipped   int64         `json:"rows_skipped"`
	Duration      string        `json:"duration"`
	DurationMs    int64         `json:"duration_ms"`
	Success       bool          `json:"success"`
	Error         string        `json:"error,omitempty"`
	Warnings      []string      `json:"warnings,omitempty"`
}

// ValidationReport enthält den Validierungsbericht
type ValidationReport struct {
	TablesChecked   int                 `json:"tables_checked"`
	TablesMatch     int                 `json:"tables_match"`
	TablesMismatch  int                 `json:"tables_mismatch"`
	JSONValid       int                 `json:"json_valid"`
	JSONInvalid     int                 `json:"json_invalid"`
	FKIntegrity     bool                `json:"fk_integrity"`
	Details         []ValidateResult    `json:"details"`
}

// GenerateReport erstellt einen vollständigen Migrationsbericht
func (m *Migrator) GenerateReport() MigrationReport {
	report := MigrationReport{
		StartTime:   m.startTime,
		EndTime:     time.Now(),
		SourceDSN:   maskDSN(m.config.SourceDSN),
		TargetPath:  m.config.TargetPath,
		TotalTables: len(m.results),
	}

	report.Duration = report.EndTime.Sub(report.StartTime).Round(time.Second).String()

	for _, r := range m.results {
		tr := TableMigrationReport{
			Name:         r.TableName,
			RowsMigrated: r.RowsMigrated,
			RowsSkipped:  r.RowsSkipped,
			Duration:     r.Duration.Round(time.Millisecond).String(),
			DurationMs:   r.Duration.Milliseconds(),
			Success:      r.Error == nil,
			Warnings:     r.Warnings,
		}

		if r.Error != nil {
			tr.Error = r.Error.Error()
			report.FailedTables++
		} else {
			report.SuccessfulTables++
		}

		report.TotalRows += r.RowsMigrated
		report.SkippedRows += r.RowsSkipped
		report.Tables = append(report.Tables, tr)
	}

	// Dateigröße
	if fi, err := os.Stat(m.config.TargetPath); err == nil {
		report.FileSize = fi.Size()
		report.FileSizeHuman = humanizeBytes(fi.Size())
	}

	// Durchsatz
	duration := report.EndTime.Sub(report.StartTime).Seconds()
	if duration > 0 {
		report.Throughput = float64(report.TotalRows) / duration
	}

	return report
}

// SaveReport speichert den Bericht als JSON
func (m *Migrator) SaveReport(filename string) error {
	report := m.GenerateReport()
	data, err := json.MarshalIndent(report, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(filename, data, 0644)
}

// PrintDetailedReport gibt einen detaillierten Bericht aus
func (m *Migrator) PrintDetailedReport() {
	report := m.GenerateReport()

	fmt.Println()
	fmt.Println(strings.Repeat("═", 70))
	fmt.Println("📊 DETAILLIERTER MIGRATIONSBERICHT")
	fmt.Println(strings.Repeat("═", 70))
	fmt.Println()

	fmt.Printf("📅 Start:        %s\n", report.StartTime.Format("2006-01-02 15:04:05"))
	fmt.Printf("📅 Ende:         %s\n", report.EndTime.Format("2006-01-02 15:04:05"))
	fmt.Printf("⏱️  Dauer:        %s\n", report.Duration)
	fmt.Println()

	fmt.Printf("📦 Tabellen:     %d gesamt\n", report.TotalTables)
	fmt.Printf("   ✅ Erfolg:    %d\n", report.SuccessfulTables)
	fmt.Printf("   ❌ Fehler:    %d\n", report.FailedTables)
	fmt.Println()

	fmt.Printf("📝 Zeilen:       %s migriert\n", formatNumber(report.TotalRows))
	fmt.Printf("   ⏭️  Übersprungen: %s\n", formatNumber(report.SkippedRows))
	fmt.Printf("🚀 Durchsatz:    %.0f Zeilen/Sek\n", report.Throughput)
	fmt.Println()

	fmt.Printf("💾 Dateigröße:   %s\n", report.FileSizeHuman)
	fmt.Printf("📁 Pfad:         %s\n", report.TargetPath)
	fmt.Println()

	// Top 10 größte Tabellen
	fmt.Println("📈 Top 10 Tabellen (nach Zeilen):")
	fmt.Println(strings.Repeat("-", 50))

	// Sortieren nach Zeilen
	sorted := make([]TableMigrationReport, len(report.Tables))
	copy(sorted, report.Tables)
	for i := 0; i < len(sorted)-1; i++ {
		for j := i + 1; j < len(sorted); j++ {
			if sorted[j].RowsMigrated > sorted[i].RowsMigrated {
				sorted[i], sorted[j] = sorted[j], sorted[i]
			}
		}
	}

	for i := 0; i < 10 && i < len(sorted); i++ {
		t := sorted[i]
		status := "✅"
		if !t.Success {
			status = "❌"
		}
		fmt.Printf("%s %-30s %10s Zeilen (%s)\n",
			status, t.Name, formatNumber(t.RowsMigrated), t.Duration)
	}

	// Fehler anzeigen
	if report.FailedTables > 0 {
		fmt.Println()
		fmt.Println("❌ FEHLER:")
		fmt.Println(strings.Repeat("-", 50))
		for _, t := range report.Tables {
			if !t.Success {
				fmt.Printf("   %s: %s\n", t.Name, t.Error)
			}
		}
	}

	// Warnungen anzeigen
	hasWarnings := false
	for _, t := range report.Tables {
		if len(t.Warnings) > 0 {
			hasWarnings = true
			break
		}
	}
	if hasWarnings {
		fmt.Println()
		fmt.Println("⚠️  WARNUNGEN:")
		fmt.Println(strings.Repeat("-", 50))
		for _, t := range report.Tables {
			for _, w := range t.Warnings {
				fmt.Printf("   %s: %s\n", t.Name, w)
			}
		}
	}

	fmt.Println()
	fmt.Println(strings.Repeat("═", 70))
}

// =============================================================================
// Hilfsfunktionen
// =============================================================================

func maskDSN(dsn string) string {
	// Passwort maskieren: user:password@... -> user:****@...
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

func humanizeBytes(bytes int64) string {
	const unit = 1024
	if bytes < unit {
		return fmt.Sprintf("%d B", bytes)
	}
	div, exp := int64(unit), 0
	for n := bytes / unit; n >= unit; n /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.2f %cB", float64(bytes)/float64(div), "KMGTPE"[exp])
}

func formatNumber(n int64) string {
	if n < 1000 {
		return fmt.Sprintf("%d", n)
	}
	if n < 1000000 {
		return fmt.Sprintf("%.1fK", float64(n)/1000)
	}
	return fmt.Sprintf("%.1fM", float64(n)/1000000)
}

// =============================================================================
// Progressbar
// =============================================================================

// ProgressBar zeigt einen Fortschrittsbalken
type ProgressBar struct {
	total    int64
	current  int64
	width    int
	label    string
	lastDraw time.Time
}

// NewProgressBar erstellt eine neue ProgressBar
func NewProgressBar(total int64, label string) *ProgressBar {
	return &ProgressBar{
		total: total,
		width: 40,
		label: label,
	}
}

// Update aktualisiert den Fortschritt
func (pb *ProgressBar) Update(current int64) {
	pb.current = current

	// Nicht zu oft zeichnen
	if time.Since(pb.lastDraw) < 100*time.Millisecond && current < pb.total {
		return
	}
	pb.lastDraw = time.Now()

	pb.Draw()
}

// Draw zeichnet die ProgressBar
func (pb *ProgressBar) Draw() {
	percent := float64(pb.current) / float64(pb.total)
	filled := int(percent * float64(pb.width))

	bar := strings.Repeat("█", filled) + strings.Repeat("░", pb.width-filled)
	fmt.Printf("\r%s [%s] %.1f%% (%d/%d)",
		pb.label, bar, percent*100, pb.current, pb.total)
}

// Finish beendet die ProgressBar
func (pb *ProgressBar) Finish() {
	pb.Update(pb.total)
	fmt.Println(" ✅")
}

// =============================================================================
// Dependency Graph Visualisierung (für Debugging)
// =============================================================================

// PrintDependencyGraph gibt den Abhängigkeitsgraphen aus
func PrintDependencyGraph(tables []TableInfo) {
	fmt.Println("📊 Abhängigkeitsgraph:")
	fmt.Println(strings.Repeat("-", 50))

	for _, t := range tables {
		if len(t.Dependencies) == 0 {
			fmt.Printf("  %s (keine Abhängigkeiten)\n", t.Name)
		} else {
			deps := strings.Join(t.Dependencies, ", ")
			fmt.Printf("  %s → [%s]\n", t.Name, deps)
		}
	}
}

// ExportDependencyDOT exportiert den Graphen im DOT-Format (für Graphviz)
func ExportDependencyDOT(tables []TableInfo, filename string) error {
	var sb strings.Builder
	sb.WriteString("digraph MigrationDependencies {\n")
	sb.WriteString("  rankdir=LR;\n")
	sb.WriteString("  node [shape=box];\n\n")

	for _, t := range tables {
		for _, dep := range t.Dependencies {
			sb.WriteString(fmt.Sprintf("  \"%s\" -> \"%s\";\n", dep, t.Name))
		}
	}

	sb.WriteString("}\n")
	return os.WriteFile(filename, []byte(sb.String()), 0644)
}
