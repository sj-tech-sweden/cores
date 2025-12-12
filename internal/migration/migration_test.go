// Package migration - Tests für das Migrations-Tool
package migration

import (
	"testing"
)

func TestMysqlTypeToSQLite(t *testing.T) {
	tests := []struct {
		mysqlType string
		expected  string
	}{
		// Integer-Typen
		{"int", "INTEGER"},
		{"INT(11)", "INTEGER"},
		{"int(11) unsigned", "INTEGER"},
		{"bigint", "INTEGER"},
		{"bigint(20) unsigned", "INTEGER"},
		{"smallint", "INTEGER"},
		{"mediumint", "INTEGER"},
		{"tinyint", "INTEGER"},
		{"tinyint(1)", "INTEGER"},

		// Dezimal-Typen
		{"decimal(10,2)", "REAL"},
		{"DECIMAL(15,4)", "REAL"},
		{"float", "REAL"},
		{"double", "REAL"},

		// String-Typen
		{"varchar(255)", "TEXT"},
		{"VARCHAR(100)", "TEXT"},
		{"char(10)", "TEXT"},
		{"text", "TEXT"},
		{"mediumtext", "TEXT"},
		{"longtext", "TEXT"},
		{"tinytext", "TEXT"},

		// ENUM und SET
		{"enum('a','b','c')", "TEXT"},
		{"ENUM('active','inactive')", "TEXT"},
		{"set('x','y','z')", "TEXT"},

		// JSON
		{"json", "TEXT"},
		{"JSON", "TEXT"},

		// Datum/Zeit
		{"date", "TEXT"},
		{"datetime", "TEXT"},
		{"datetime(3)", "TEXT"},
		{"timestamp", "TEXT"},
		{"time", "TEXT"},
		{"year", "TEXT"},

		// Binär
		{"blob", "BLOB"},
		{"mediumblob", "BLOB"},
		{"longblob", "BLOB"},
		{"binary(16)", "BLOB"},
		{"varbinary(255)", "BLOB"},
	}

	for _, tt := range tests {
		t.Run(tt.mysqlType, func(t *testing.T) {
			result := mysqlTypeToSQLite(tt.mysqlType)
			if result != tt.expected {
				t.Errorf("mysqlTypeToSQLite(%q) = %q, want %q", tt.mysqlType, result, tt.expected)
			}
		})
	}
}

func TestTransformDefaultValue(t *testing.T) {
	tests := []struct {
		value     string
		mysqlType string
		expected  string
	}{
		{"NULL", "varchar(255)", "NULL"},
		{"null", "int", "NULL"},
		{"CURRENT_TIMESTAMP", "timestamp", "CURRENT_TIMESTAMP"},
		{"current_timestamp", "datetime", "CURRENT_TIMESTAMP"},
		{"NOW()", "datetime", "(datetime('now'))"},
		{"0", "int(11)", "0"},
		{"1", "tinyint(1)", "1"},
		{"0", "tinyint(1)", "0"},
		{"default_value", "varchar(255)", "'default_value'"},
		{"'quoted'", "varchar(255)", "'quoted'"},
	}

	for _, tt := range tests {
		t.Run(tt.value, func(t *testing.T) {
			result := transformDefaultValue(tt.value, tt.mysqlType)
			if result != tt.expected {
				t.Errorf("transformDefaultValue(%q, %q) = %q, want %q", 
					tt.value, tt.mysqlType, result, tt.expected)
			}
		})
	}
}

func TestExtractEnumValues(t *testing.T) {
	tests := []struct {
		enumType string
		expected []string
	}{
		{
			"enum('active','inactive','pending')",
			[]string{"active", "inactive", "pending"},
		},
		{
			"ENUM('daily','weekly','monthly','yearly')",
			[]string{"daily", "weekly", "monthly", "yearly"},
		},
		{
			"enum('yes','no')",
			[]string{"yes", "no"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.enumType, func(t *testing.T) {
			result := extractEnumValues(tt.enumType)
			if len(result) != len(tt.expected) {
				t.Errorf("extractEnumValues(%q) length = %d, want %d", 
					tt.enumType, len(result), len(tt.expected))
				return
			}
			for i, v := range result {
				if v != tt.expected[i] {
					t.Errorf("extractEnumValues(%q)[%d] = %q, want %q", 
						tt.enumType, i, v, tt.expected[i])
				}
			}
		})
	}
}

func TestQuoteName(t *testing.T) {
	tests := []struct {
		name     string
		expected string
	}{
		{"users", "`users`"},
		{"user_roles", "`user_roles`"},
		{"table`name", "`table``name`"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := quoteName(tt.name)
			if result != tt.expected {
				t.Errorf("quoteName(%q) = %q, want %q", tt.name, result, tt.expected)
			}
		})
	}
}

func TestGetMigrationOrder(t *testing.T) {
	order := GetMigrationOrder()

	// Prüfen, dass Basis-Tabellen vor abhängigen kommen
	checkBefore := []struct {
		parent string
		child  string
	}{
		{"users", "audit_log"},
		{"users", "user_profiles"},
		{"users", "sessions"},
		{"customers", "jobs"},
		{"products", "devices"},
		{"devices", "jobdevices"},
		{"jobs", "jobdevices"},
		{"jobs", "job_history"},
		{"insuranceprovider", "insurances"},
		{"insurances", "devices"},
		{"manufacturer", "brands"},
		{"categories", "subcategories"},
		{"status", "jobs"},
		{"jobCategory", "jobs"},
	}

	indexOf := func(slice []string, item string) int {
		for i, s := range slice {
			if s == item {
				return i
			}
		}
		return -1
	}

	for _, tc := range checkBefore {
		parentIdx := indexOf(order, tc.parent)
		childIdx := indexOf(order, tc.child)

		if parentIdx < 0 {
			t.Logf("Warnung: %s nicht in Reihenfolge", tc.parent)
			continue
		}
		if childIdx < 0 {
			t.Logf("Warnung: %s nicht in Reihenfolge", tc.child)
			continue
		}

		if parentIdx >= childIdx {
			t.Errorf("%s (Index %d) sollte vor %s (Index %d) kommen", 
				tc.parent, parentIdx, tc.child, childIdx)
		}
	}
}

func TestTopologicalSort(t *testing.T) {
	tables := []TableInfo{
		{Name: "users", Dependencies: nil},
		{Name: "posts", Dependencies: []string{"users"}},
		{Name: "comments", Dependencies: []string{"users", "posts"}},
		{Name: "categories", Dependencies: nil},
	}

	sorted, err := TopologicalSort(tables)
	if err != nil {
		t.Fatalf("TopologicalSort error: %v", err)
	}

	if len(sorted) != len(tables) {
		t.Fatalf("Expected %d tables, got %d", len(tables), len(sorted))
	}

	// Prüfen, dass Abhängigkeiten erfüllt sind
	seen := make(map[string]bool)
	for _, table := range sorted {
		for _, dep := range table.Dependencies {
			if !seen[dep] {
				t.Errorf("Tabelle %s kommt vor ihrer Abhängigkeit %s", table.Name, dep)
			}
		}
		seen[table.Name] = true
	}
}

func TestContains(t *testing.T) {
	slice := []string{"a", "b", "c"}

	if !contains(slice, "a") {
		t.Error("contains should return true for 'a'")
	}
	if !contains(slice, "b") {
		t.Error("contains should return true for 'b'")
	}
	if contains(slice, "d") {
		t.Error("contains should return false for 'd'")
	}
	if contains(nil, "a") {
		t.Error("contains should return false for nil slice")
	}
}

func TestContainsTable(t *testing.T) {
	tables := []TableInfo{
		{Name: "users"},
		{Name: "posts"},
	}

	if !containsTable(tables, "users") {
		t.Error("containsTable should return true for 'users'")
	}
	if containsTable(tables, "comments") {
		t.Error("containsTable should return false for 'comments'")
	}
}
