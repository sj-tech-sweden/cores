# 🗄️ MySQL zu SQLite Migration Tool

**Erstellt von:** Wolfgang (Daten-Migrations-Experte)  
**Version:** 1.0.0  
**Datum:** 12. Dezember 2025

---

## 📋 Übersicht

Dieses Tool migriert alle Daten von einer MySQL-Datenbank zu SQLite. Es wurde speziell für RentalCore und WarehouseCore entwickelt und unterstützt:

- ✅ 102 Tabellen mit korrekter Reihenfolge
- ✅ Foreign Key Abhängigkeiten
- ✅ ENUM zu TEXT Konvertierung
- ✅ JSON-Validierung
- ✅ Timestamp-Transformation
- ✅ Fortschrittsanzeige
- ✅ Fehlerbehandlung mit Rollback
- ✅ Validierung nach Migration

---

## 🚀 Installation

### Voraussetzungen

- Go 1.21 oder höher
- Zugang zur MySQL-Datenbank
- CGO aktiviert (für SQLite)

### Kompilieren

```bash
cd /opt/dev/cores/internal/migration

# Direkt bauen
go build -o migrate-db ./cmd/migrate-db

# Oder mit Makefile
make build
```

### Als Teil des Projekts

```bash
# Im Hauptprojekt
cd /opt/dev/cores
go build -o bin/migrate-db ./internal/migration/cmd/migrate-db
```

---

## 📖 Verwendung

### Basis-Syntax

```bash
./migrate-db --source "user:pass@tcp(host:port)/database" --target "./data.db"
```

### Optionen

| Option | Beschreibung | Standard |
|--------|--------------|----------|
| `--source` | MySQL DSN (erforderlich) | - |
| `--target` | SQLite Datenbankpfad | `./data.db` |
| `--dry-run` | Nur analysieren, nichts schreiben | `false` |
| `--verbose` | Ausführliche Ausgabe | `false` |
| `--batch-size` | Zeilen pro Batch | `1000` |
| `--skip` | Tabellen überspringen (komma-getrennt) | - |
| `--only` | Nur diese Tabellen (komma-getrennt) | - |
| `--validate` | Nach Migration validieren | `true` |
| `--continue-on-error` | Bei Fehlern weitermachen | `false` |
| `--export-order` | Tabellen-Reihenfolge als JSON exportieren | - |

### MySQL DSN Format

```
user:password@tcp(host:port)/database?parseTime=true
```

**Beispiele:**
```bash
# Lokale Datenbank
root:@tcp(localhost:3306)/RentalCore

# Mit Passwort
admin:geheim123@tcp(192.168.1.100:3306)/production

# Mit allen Optionen
user:pass@tcp(host:3306)/db?parseTime=true&charset=utf8mb4&timeout=30s
```

---

## 💡 Beispiele

### 1. Vollständige Migration

```bash
./migrate-db \
  --source "rentalcore:password@tcp(localhost:3306)/RentalCore" \
  --target "/opt/dev/cores/rentalcore/data/rentalcore.db"
```

### 2. Dry-Run (Analyse ohne Änderungen)

```bash
./migrate-db \
  --source "user:pass@tcp(localhost)/db" \
  --target "./test.db" \
  --dry-run \
  --verbose
```

### 3. Nur bestimmte Tabellen migrieren

```bash
./migrate-db \
  --source "..." \
  --target "./partial.db" \
  --only "users,customers,products,devices"
```

### 4. Tabellen überspringen

```bash
./migrate-db \
  --source "..." \
  --target "./data.db" \
  --skip "audit_log,audit_logs,audit_events,analytics_cache"
```

### 5. Tabellen-Reihenfolge exportieren

```bash
./migrate-db \
  --source "..." \
  --export-order "./table_order.json" \
  --dry-run
```

### 6. Mit Umgebungsvariablen

```bash
export MYSQL_DSN="user:pass@tcp(localhost:3306)/RentalCore"
export SQLITE_PATH="/data/rentalcore.db"

./migrate-db --validate
```

---

## 📊 Migrations-Reihenfolge

Die Tabellen werden in dieser Reihenfolge migriert (Foreign Key Abhängigkeiten beachtend):

### Stufe 0: Basis-Tabellen (keine Abhängigkeiten)
1. `status`
2. `roles`
3. `count_types`
4. `cable_types`
5. `cable_connectors`
6. `manufacturer`
7. `insuranceprovider`
8. `categories`
9. `subcategories`
10. `subbiercategories`
11. `package_categories`
12. `zone_types`
13. `storage_zones`
14. `jobCategory`
15. `retention_policies`
16. `email_templates`
17. `label_templates`
18. `company_settings`
19. `app_settings`
20. `invoice_settings`

### Stufe 1: Benutzer und Kunden
21. `users`
22. `customers`
23. `employee`

### Stufe 2: Benutzer-abhängige Tabellen
24. `user_profiles`
25. `user_preferences`
26. `user_dashboard_widgets`
27. `user_2fa`
28. `user_passkeys`
29. `user_roles`
30. `user_roles_wh`
31. `sessions`
32. `user_sessions`
33. `webauthn_sessions`
34. `push_subscriptions`
35. `saved_searches`
36. `search_history`
37. `offline_sync_queue`
38. `authentication_attempts`

### Stufe 3: Produkte und Versicherungen
39. `insurances`
40. `brands`
41. `products`

### Stufe 4: Produkt-abhängige Tabellen
42. `product_images`
43. `product_locations`
44. `product_accessories`
45. `product_consumables`
46. `product_dependencies`
47. `product_packages`
48. `product_package_items`
49. `product_package_aliases`
50. `cables`
51. `rental_equipment`

### Stufe 5: Geräte
52. `devices`
53. `cases`

### Stufe 6: Geräte-abhängige Tabellen
54. `devicescases`
55. `devicestatushistory`
56. `device_movements`
57. `maintenanceLogs`
58. `defect_reports`
59. `equipment_packages`
60. `package_devices`
61. `led_controllers`
62. `led_controller_zone_types`
63. `inventory_transactions`

### Stufe 7: Dokumente
64. `documents`
65. `digital_signatures`
66. `document_signatures`
67. `invoice_templates`

### Stufe 8: Jobs
68. `jobs`

### Stufe 9: Job-abhängige Tabellen
69. `jobdevices`
70. `employeejob`
71. `job_history`
72. `job_attachments`
73. `job_device_events`
74. `job_edit_sessions`
75. `job_packages`
76. `job_package_reservations`
77. `job_accessories`
78. `job_consumables`
79. `job_rental_equipment`
80. `equipment_usage_logs`

### Stufe 10: Rechnungen
81. `invoices`
82. `invoice_line_items`
83. `invoice_payments`
84. `financial_transactions`

### Stufe 11: PDF-Verarbeitung
85. `pdf_uploads`
86. `pdf_extractions`
87. `pdf_extraction_items`
88. `pdf_product_mappings`
89. `pdf_package_mappings`
90. `pdf_mapping_events`

### Stufe 12: Audit und Compliance
91. `audit_log`
92. `audit_logs`
93. `audit_events`
94. `gobd_records`
95. `consent_records`
96. `data_processing_records`
97. `data_subject_requests`
98. `encrypted_personal_data`
99. `archived_documents`

### Stufe 13: Analytics und Sonstiges
100. `analytics_cache`
101. `scan_events`
102. `inspection_schedules`

---

## 🔄 Daten-Transformationen

### Typ-Konvertierungen

| MySQL Typ | SQLite Typ | Hinweis |
|-----------|------------|---------|
| `INT`, `BIGINT`, `SMALLINT` | `INTEGER` | Alle Integer-Varianten |
| `TINYINT(1)` | `INTEGER` | Boolean als 0/1 |
| `DECIMAL`, `FLOAT`, `DOUBLE` | `REAL` | Dezimalzahlen |
| `VARCHAR`, `TEXT`, `*TEXT` | `TEXT` | Alle String-Typen |
| `ENUM(...)` | `TEXT` | Werte bleiben erhalten |
| `SET(...)` | `TEXT` | Komma-getrennte Werte |
| `JSON` | `TEXT` | Validiertes JSON |
| `DATE`, `DATETIME`, `TIMESTAMP` | `TEXT` | ISO 8601 Format |
| `BLOB`, `*BLOB`, `BINARY` | `BLOB` | Binärdaten |

### Timestamp-Transformation

```
MySQL:  2025-12-12 14:30:00
SQLite: 2025-12-12T14:30:00Z
```

### JSON-Spalten

- Validierung bei der Migration
- Ungültige JSON-Werte werden als String gespeichert
- NULL-Werte bleiben NULL

### AUTO_INCREMENT

MySQL `AUTO_INCREMENT` wird zu SQLite `AUTOINCREMENT`:
- Nur bei einfachen Integer-Primary-Keys
- Composite Keys behalten manuelle ID-Verwaltung

---

## ✅ Validierung

Nach der Migration werden folgende Prüfungen durchgeführt:

1. **Zeilenanzahl-Vergleich**: Quelle vs. Ziel für jede Tabelle
2. **JSON-Validierung**: Prüfung aller JSON-Spalten auf gültiges Format
3. **Foreign Key Integrität**: `PRAGMA foreign_key_check`

### Validierungsergebnis

```
✅ users: Quelle=150, Ziel=150
✅ products: Quelle=1234, Ziel=1234
❌ devices: Quelle=5678, Ziel=5677  ⚠️ 1 Zeile fehlt
```

---

## 🛠️ Fehlerbehandlung

### Rollback bei Fehler

Standardmäßig wird bei einem Fehler die aktuelle Tabelle zurückgerollt:

```bash
❌ devices: UNIQUE constraint failed
# Alle Zeilen dieser Tabelle werden nicht übernommen
```

### Weitermachen bei Fehler

Mit `--continue-on-error` wird der Fehler protokolliert und die Migration fortgesetzt:

```bash
./migrate-db --source "..." --target "..." --continue-on-error
```

---

## 📈 Performance-Tipps

1. **Große Datenbanken**: Batch-Size erhöhen
   ```bash
   --batch-size 5000
   ```

2. **SSD empfohlen**: SQLite profitiert stark von schnellem Storage

3. **RAM**: Mehr RAM = größerer Cache = schnellere Migration

4. **Audit-Tabellen überspringen** für schnellere Tests:
   ```bash
   --skip "audit_log,audit_logs,audit_events"
   ```

---

## 🐛 Troubleshooting

### "MySQL connection refused"

```bash
# Prüfen ob MySQL läuft
systemctl status mysql
# Oder
docker ps | grep mysql
```

### "CGO required for SQLite"

```bash
# CGO aktivieren
export CGO_ENABLED=1

# Auf Linux ggf. GCC installieren
apt install gcc
```

### "Foreign key constraint failed"

Die Migrations-Reihenfolge sollte dies verhindern. Falls es dennoch auftritt:

```bash
# Foreign Keys deaktiviert lassen
# (wird standardmäßig gemacht)
```

### "Disk I/O error"

```bash
# Mehr Speicherplatz prüfen
df -h

# Schreibrechte prüfen
ls -la ./data/
```

---

## 📁 Projektstruktur

```
/opt/dev/cores/internal/migration/
├── migration.go          # Hauptlogik
├── migration_test.go     # Tests
├── README.md             # Diese Dokumentation
└── cmd/
    └── migrate-db/
        └── main.go       # CLI-Tool
```

---

## 🔧 Entwicklung

### Tests ausführen

```bash
cd /opt/dev/cores/internal/migration
go test -v ./...
```

### Neue Tabelle hinzufügen

1. In `GetMigrationOrder()` an richtiger Stelle einfügen
2. Abhängigkeiten beachten (Eltern vor Kindern)
3. Tests aktualisieren

---

## 📝 Lizenz

Internes Projekt - RentalCore/WarehouseCore

---

**🎉 Viel Erfolg bei der Migration!**
