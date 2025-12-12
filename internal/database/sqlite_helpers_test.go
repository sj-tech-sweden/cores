package database

import (
	"testing"
	"time"
)

func TestSubstringIndex(t *testing.T) {
	tests := []struct {
		name     string
		str      string
		delim    string
		count    int
		expected string
	}{
		{"positive count 1", "www.example.com", ".", 1, "www"},
		{"positive count 2", "www.example.com", ".", 2, "www.example"},
		{"positive count exceeds", "www.example.com", ".", 10, "www.example.com"},
		{"negative count -1", "www.example.com", ".", -1, "com"},
		{"negative count -2", "www.example.com", ".", -2, "example.com"},
		{"negative count exceeds", "www.example.com", ".", -10, "www.example.com"},
		{"count zero", "www.example.com", ".", 0, ""},
		{"empty string", "", ".", 1, ""},
		{"empty delimiter", "www.example.com", "", 1, ""},
		{"no delimiter found", "www-example-com", ".", 1, "www-example-com"},
		{"single part", "example", ".", 1, "example"},
		{"device id prefix", "CAM01001", "", 1, ""},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := SubstringIndex(tt.str, tt.delim, tt.count)
			if result != tt.expected {
				t.Errorf("SubstringIndex(%q, %q, %d) = %q, want %q",
					tt.str, tt.delim, tt.count, result, tt.expected)
			}
		})
	}
}

func TestLPad(t *testing.T) {
	tests := []struct {
		name     string
		str      string
		length   int
		padStr   string
		expected string
	}{
		{"basic zero pad", "42", 5, "0", "00042"},
		{"string longer than length", "hello", 3, "x", "hel"},
		{"multi-char pad", "hi", 5, "xy", "xyxhi"},
		{"empty pad string", "hi", 5, "", "   hi"},
		{"same length", "hello", 5, "x", "hello"},
		{"single char", "1", 3, "0", "001"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := LPad(tt.str, tt.length, tt.padStr)
			if result != tt.expected {
				t.Errorf("LPad(%q, %d, %q) = %q, want %q",
					tt.str, tt.length, tt.padStr, result, tt.expected)
			}
		})
	}
}

func TestRPad(t *testing.T) {
	tests := []struct {
		name     string
		str      string
		length   int
		padStr   string
		expected string
	}{
		{"basic zero pad", "42", 5, "0", "42000"},
		{"string longer than length", "hello", 3, "x", "hel"},
		{"multi-char pad", "hi", 5, "xy", "hixyx"},
		{"empty pad string", "hi", 5, "", "hi   "},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := RPad(tt.str, tt.length, tt.padStr)
			if result != tt.expected {
				t.Errorf("RPad(%q, %d, %q) = %q, want %q",
					tt.str, tt.length, tt.padStr, result, tt.expected)
			}
		})
	}
}

func TestConcatWS(t *testing.T) {
	tests := []struct {
		name      string
		separator string
		parts     []string
		expected  string
	}{
		{"basic concat", ", ", []string{"a", "b", "c"}, "a, b, c"},
		{"with empty values", ", ", []string{"a", "", "b", "", "c"}, "a, b, c"},
		{"all empty", ", ", []string{"", "", ""}, ""},
		{"single value", ", ", []string{"hello"}, "hello"},
		{"date format", "-", []string{"2025", "12", "01"}, "2025-12-01"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := ConcatWS(tt.separator, tt.parts...)
			if result != tt.expected {
				t.Errorf("ConcatWS(%q, %v) = %q, want %q",
					tt.separator, tt.parts, result, tt.expected)
			}
		})
	}
}

func TestDateAdd(t *testing.T) {
	baseDate := time.Date(2025, 1, 15, 12, 30, 45, 0, time.UTC)

	tests := []struct {
		name     string
		value    int
		unit     string
		expected time.Time
	}{
		{"add 30 days", 30, "days", time.Date(2025, 2, 14, 12, 30, 45, 0, time.UTC)},
		{"subtract 7 days", -7, "days", time.Date(2025, 1, 8, 12, 30, 45, 0, time.UTC)},
		{"add 1 month", 1, "month", time.Date(2025, 2, 15, 12, 30, 45, 0, time.UTC)},
		{"add 1 year", 1, "year", time.Date(2026, 1, 15, 12, 30, 45, 0, time.UTC)},
		{"add 2 hours", 2, "hours", time.Date(2025, 1, 15, 14, 30, 45, 0, time.UTC)},
		{"add 1 week", 1, "week", time.Date(2025, 1, 22, 12, 30, 45, 0, time.UTC)},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := DateAdd(baseDate, tt.value, tt.unit)
			if !result.Equal(tt.expected) {
				t.Errorf("DateAdd(%v, %d, %q) = %v, want %v",
					baseDate, tt.value, tt.unit, result, tt.expected)
			}
		})
	}
}

func TestDateDiff(t *testing.T) {
	tests := []struct {
		name     string
		date1    time.Time
		date2    time.Time
		expected int
	}{
		{
			"positive diff",
			time.Date(2025, 1, 15, 0, 0, 0, 0, time.UTC),
			time.Date(2025, 1, 10, 0, 0, 0, 0, time.UTC),
			5,
		},
		{
			"negative diff",
			time.Date(2025, 1, 10, 0, 0, 0, 0, time.UTC),
			time.Date(2025, 1, 15, 0, 0, 0, 0, time.UTC),
			-5,
		},
		{
			"same day different time",
			time.Date(2025, 1, 15, 23, 59, 59, 0, time.UTC),
			time.Date(2025, 1, 15, 0, 0, 0, 0, time.UTC),
			0,
		},
		{
			"year difference",
			time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
			time.Date(2025, 1, 1, 0, 0, 0, 0, time.UTC),
			365,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := DateDiff(tt.date1, tt.date2)
			if result != tt.expected {
				t.Errorf("DateDiff(%v, %v) = %d, want %d",
					tt.date1, tt.date2, result, tt.expected)
			}
		})
	}
}

func TestFormatDate(t *testing.T) {
	testDate := time.Date(2025, 12, 1, 14, 30, 45, 0, time.UTC)

	tests := []struct {
		name        string
		mysqlFormat string
		expected    string
	}{
		{"ISO date", "%Y-%m-%d", "2025-12-01"},
		{"German date", "%d.%m.%Y", "01.12.2025"},
		{"Time 24h", "%H:%i:%s", "14:30:45"},
		{"Full datetime", "%Y-%m-%d %H:%i:%s", "2025-12-01 14:30:45"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := FormatDate(testDate, tt.mysqlFormat)
			if result != tt.expected {
				t.Errorf("FormatDate(%v, %q) = %q, want %q",
					testDate, tt.mysqlFormat, result, tt.expected)
			}
		})
	}
}

func TestIfNull(t *testing.T) {
	tests := []struct {
		name     string
		expr1    string
		expr2    string
		expected string
	}{
		{"expr1 not empty", "hello", "default", "hello"},
		{"expr1 empty", "", "default", "default"},
		{"both empty", "", "", ""},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := IfNull(tt.expr1, tt.expr2)
			if result != tt.expected {
				t.Errorf("IfNull(%q, %q) = %q, want %q",
					tt.expr1, tt.expr2, result, tt.expected)
			}
		})
	}
}

func TestCoalesceString(t *testing.T) {
	tests := []struct {
		name     string
		values   []string
		expected string
	}{
		{"first non-empty", []string{"", "", "hello", "world"}, "hello"},
		{"all empty", []string{"", "", ""}, ""},
		{"first value", []string{"hello", "world"}, "hello"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := CoalesceString(tt.values...)
			if result != tt.expected {
				t.Errorf("CoalesceString(%v) = %q, want %q",
					tt.values, result, tt.expected)
			}
		})
	}
}

func TestSQLiteDatetimeExpr(t *testing.T) {
	tests := []struct {
		name     string
		base     string
		value    int
		unit     string
		expected string
	}{
		{"positive days", "now", 30, "days", "datetime('now', '+30 days')"},
		{"negative days", "now", -7, "days", "datetime('now', '-7 days')"},
		{"zero days", "now", 0, "days", "datetime('now', '+0 days')"},
		{"months", "now", 3, "months", "datetime('now', '+3 months')"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := SQLiteDatetimeExpr(tt.base, tt.value, tt.unit)
			if result != tt.expected {
				t.Errorf("SQLiteDatetimeExpr(%q, %d, %q) = %q, want %q",
					tt.base, tt.value, tt.unit, result, tt.expected)
			}
		})
	}
}

func TestIsPackageDevice(t *testing.T) {
	tests := []struct {
		deviceID string
		expected bool
	}{
		{"PKG_001", true},
		{"PKG_CAMERA_SET", true},
		{"CAM01001", false},
		{"", false},
		{"pkg_001", false}, // Case sensitive
	}

	for _, tt := range tests {
		t.Run(tt.deviceID, func(t *testing.T) {
			result := IsPackageDevice(tt.deviceID)
			if result != tt.expected {
				t.Errorf("IsPackageDevice(%q) = %v, want %v",
					tt.deviceID, result, tt.expected)
			}
		})
	}
}

// Benchmark-Tests
func BenchmarkSubstringIndex(b *testing.B) {
	for i := 0; i < b.N; i++ {
		SubstringIndex("www.example.com", ".", 2)
	}
}

func BenchmarkLPad(b *testing.B) {
	for i := 0; i < b.N; i++ {
		LPad("42", 10, "0")
	}
}

func BenchmarkConcatWS(b *testing.B) {
	parts := []string{"a", "b", "c", "d", "e"}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		ConcatWS(", ", parts...)
	}
}

func BenchmarkDateAdd(b *testing.B) {
	date := time.Now()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		DateAdd(date, 30, "days")
	}
}
