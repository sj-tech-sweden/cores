// Package database provides JSON type handlers for GORM with SQLite
// SQLite speichert JSON als TEXT, diese Typen handhaben die Serialisierung
package database

import (
	"database/sql/driver"
	"encoding/json"
	"errors"
	"fmt"
)

// =============================================================================
// JSONMap - Für map[string]interface{} Spalten
// =============================================================================

// JSONMap ist ein GORM-kompatibler Typ für JSON-Object-Spalten in SQLite
// Wird als TEXT gespeichert und beim Lesen/Schreiben (de)serialisiert
type JSONMap map[string]interface{}

// Value implementiert driver.Valuer für Datenbank-Writes
func (j JSONMap) Value() (driver.Value, error) {
	if j == nil {
		return nil, nil
	}
	data, err := json.Marshal(j)
	if err != nil {
		return nil, fmt.Errorf("JSONMap.Value: %w", err)
	}
	return string(data), nil
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
		return fmt.Errorf("JSONMap.Scan: unsupported type %T", value)
	}

	if len(bytes) == 0 {
		*j = nil
		return nil
	}

	result := make(map[string]interface{})
	if err := json.Unmarshal(bytes, &result); err != nil {
		return fmt.Errorf("JSONMap.Scan: %w", err)
	}
	*j = result
	return nil
}

// GormDataType gibt den GORM-Datentyp zurück
func (JSONMap) GormDataType() string {
	return "text"
}

// Get gibt einen Wert aus der Map zurück
func (j JSONMap) Get(key string) (interface{}, bool) {
	if j == nil {
		return nil, false
	}
	val, ok := j[key]
	return val, ok
}

// GetString gibt einen String-Wert zurück
func (j JSONMap) GetString(key string) string {
	if val, ok := j[key]; ok {
		if s, ok := val.(string); ok {
			return s
		}
	}
	return ""
}

// GetInt gibt einen Int-Wert zurück
func (j JSONMap) GetInt(key string) int {
	if val, ok := j[key]; ok {
		switch v := val.(type) {
		case float64:
			return int(v)
		case int:
			return v
		case int64:
			return int(v)
		}
	}
	return 0
}

// GetBool gibt einen Bool-Wert zurück
func (j JSONMap) GetBool(key string) bool {
	if val, ok := j[key]; ok {
		if b, ok := val.(bool); ok {
			return b
		}
	}
	return false
}

// =============================================================================
// JSONArray - Für []interface{} Spalten
// =============================================================================

// JSONArray ist ein GORM-kompatibler Typ für JSON-Array-Spalten in SQLite
type JSONArray []interface{}

// Value implementiert driver.Valuer
func (j JSONArray) Value() (driver.Value, error) {
	if j == nil {
		return nil, nil
	}
	data, err := json.Marshal(j)
	if err != nil {
		return nil, fmt.Errorf("JSONArray.Value: %w", err)
	}
	return string(data), nil
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
		return fmt.Errorf("JSONArray.Scan: unsupported type %T", value)
	}

	if len(bytes) == 0 {
		*j = nil
		return nil
	}

	var result []interface{}
	if err := json.Unmarshal(bytes, &result); err != nil {
		return fmt.Errorf("JSONArray.Scan: %w", err)
	}
	*j = result
	return nil
}

// GormDataType gibt den GORM-Datentyp zurück
func (JSONArray) GormDataType() string {
	return "text"
}

// Len gibt die Länge des Arrays zurück
func (j JSONArray) Len() int {
	return len(j)
}

// =============================================================================
// JSONStringSlice - Für []string Spalten
// =============================================================================

// JSONStringSlice ist ein GORM-kompatibler Typ für JSON String-Arrays
type JSONStringSlice []string

// Value implementiert driver.Valuer
func (j JSONStringSlice) Value() (driver.Value, error) {
	if j == nil {
		return nil, nil
	}
	data, err := json.Marshal(j)
	if err != nil {
		return nil, fmt.Errorf("JSONStringSlice.Value: %w", err)
	}
	return string(data), nil
}

// Scan implementiert sql.Scanner
func (j *JSONStringSlice) Scan(value interface{}) error {
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
		return fmt.Errorf("JSONStringSlice.Scan: unsupported type %T", value)
	}

	if len(bytes) == 0 {
		*j = nil
		return nil
	}

	var result []string
	if err := json.Unmarshal(bytes, &result); err != nil {
		return fmt.Errorf("JSONStringSlice.Scan: %w", err)
	}
	*j = result
	return nil
}

// GormDataType gibt den GORM-Datentyp zurück
func (JSONStringSlice) GormDataType() string {
	return "text"
}

// Contains prüft ob ein String im Slice enthalten ist
func (j JSONStringSlice) Contains(s string) bool {
	for _, v := range j {
		if v == s {
			return true
		}
	}
	return false
}

// =============================================================================
// JSONIntSlice - Für []int Spalten
// =============================================================================

// JSONIntSlice ist ein GORM-kompatibler Typ für JSON Int-Arrays
type JSONIntSlice []int

// Value implementiert driver.Valuer
func (j JSONIntSlice) Value() (driver.Value, error) {
	if j == nil {
		return nil, nil
	}
	data, err := json.Marshal(j)
	if err != nil {
		return nil, fmt.Errorf("JSONIntSlice.Value: %w", err)
	}
	return string(data), nil
}

// Scan implementiert sql.Scanner
func (j *JSONIntSlice) Scan(value interface{}) error {
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
		return fmt.Errorf("JSONIntSlice.Scan: unsupported type %T", value)
	}

	if len(bytes) == 0 {
		*j = nil
		return nil
	}

	var result []int
	if err := json.Unmarshal(bytes, &result); err != nil {
		// Versuche float64 array (JSON numbers)
		var floats []float64
		if err2 := json.Unmarshal(bytes, &floats); err2 != nil {
			return fmt.Errorf("JSONIntSlice.Scan: %w", err)
		}
		result = make([]int, len(floats))
		for i, f := range floats {
			result[i] = int(f)
		}
	}
	*j = result
	return nil
}

// GormDataType gibt den GORM-Datentyp zurück
func (JSONIntSlice) GormDataType() string {
	return "text"
}

// =============================================================================
// JSONTyped - Generischer typisierter JSON Handler
// =============================================================================

// JSONTyped ist ein generischer GORM-kompatibler Typ für typisierte JSON-Daten
type JSONTyped[T any] struct {
	Data  T
	Valid bool
}

// Value implementiert driver.Valuer
func (j JSONTyped[T]) Value() (driver.Value, error) {
	if !j.Valid {
		return nil, nil
	}
	data, err := json.Marshal(j.Data)
	if err != nil {
		return nil, fmt.Errorf("JSONTyped.Value: %w", err)
	}
	return string(data), nil
}

// Scan implementiert sql.Scanner
func (j *JSONTyped[T]) Scan(value interface{}) error {
	if value == nil {
		j.Valid = false
		return nil
	}

	var bytes []byte
	switch v := value.(type) {
	case []byte:
		bytes = v
	case string:
		bytes = []byte(v)
	default:
		return fmt.Errorf("JSONTyped.Scan: unsupported type %T", value)
	}

	if len(bytes) == 0 {
		j.Valid = false
		return nil
	}

	if err := json.Unmarshal(bytes, &j.Data); err != nil {
		return fmt.Errorf("JSONTyped.Scan: %w", err)
	}
	j.Valid = true
	return nil
}

// GormDataType gibt den GORM-Datentyp zurück
func (JSONTyped[T]) GormDataType() string {
	return "text"
}

// NewJSONTyped erstellt einen neuen JSONTyped Wert
func NewJSONTyped[T any](data T) JSONTyped[T] {
	return JSONTyped[T]{Data: data, Valid: true}
}

// =============================================================================
// Hilfsfunktionen
// =============================================================================

// MarshalJSON ist ein Helper zum sicheren Marshalling
func MarshalJSON(v interface{}) (string, error) {
	if v == nil {
		return "null", nil
	}
	data, err := json.Marshal(v)
	if err != nil {
		return "", err
	}
	return string(data), nil
}

// UnmarshalJSON ist ein Helper zum sicheren Unmarshalling
func UnmarshalJSON[T any](data string) (T, error) {
	var result T
	if data == "" || data == "null" {
		return result, nil
	}
	err := json.Unmarshal([]byte(data), &result)
	return result, err
}

// IsValidJSON prüft ob ein String valides JSON ist
func IsValidJSON(s string) bool {
	if s == "" {
		return false
	}
	var js interface{}
	return json.Unmarshal([]byte(s), &js) == nil
}

// PrettyJSON formatiert JSON für Debugging
func PrettyJSON(v interface{}) string {
	data, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return fmt.Sprintf("error: %v", err)
	}
	return string(data)
}

// CompactJSON entfernt Whitespace aus JSON
func CompactJSON(s string) (string, error) {
	if s == "" {
		return "", errors.New("empty input")
	}
	var v interface{}
	if err := json.Unmarshal([]byte(s), &v); err != nil {
		return "", err
	}
	data, err := json.Marshal(v)
	if err != nil {
		return "", err
	}
	return string(data), nil
}
