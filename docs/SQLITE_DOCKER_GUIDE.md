# SQLite Docker Deployment Guide 🐳

Diese Anleitung beschreibt die SQLite-basierte Docker-Konfiguration für RentalCore und WarehouseCore.

## Übersicht

Die Architektur wurde von MySQL auf SQLite migriert:

```
┌─────────────────────────────────────────────────────────────────┐
│                    Docker Compose Stack                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │  db-init     │    │  RentalCore  │    │ WarehouseCore│      │
│  │  (init)      │    │  :8081       │    │  :8082       │      │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘      │
│         │                   │                   │               │
│         └───────────────────┼───────────────────┘               │
│                             │                                   │
│                    ┌────────▼────────┐                         │
│                    │  sqlite-data    │                         │
│                    │  (Volume)       │                         │
│                    │                 │                         │
│                    │ ├─ rentalcore.db│                         │
│                    │ └─ warehousecore│                         │
│                    └─────────────────┘                         │
│                                                                 │
│  ┌──────────────┐    ┌──────────────────────┐                  │
│  │  db-backup   │───►│  sqlite-backups      │                  │
│  │  (cron)      │    │  (Volume)            │                  │
│  └──────────────┘    └──────────────────────┘                  │
│                                                                 │
│  ┌──────────────┐                                              │
│  │  Mosquitto   │  MQTT für LED-System                         │
│  │  :1883       │                                              │
│  └──────────────┘                                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Quick Start

### 1. Environment vorbereiten

```bash
cd /opt/dev/cores
cp .env.sqlite.example .env
# Passe .env nach Bedarf an
```

### 2. Stack starten

```bash
docker compose up -d
```

### 3. Status prüfen

```bash
docker compose ps
docker compose logs -f
```

## Services

### db-init
- **Zweck**: Erstellt leere SQLite-Datenbanken beim ersten Start
- **Läuft nur einmal**: `condition: service_completed_successfully`
- **Erstellt**: `/data/rentalcore.db`, `/data/warehousecore.db`

### rentalcore
- **Port**: 8081
- **Datenbank**: `/data/rentalcore.db` (SQLite WAL-Modus)
- **Health Check**: `http://localhost:8081/health`

### warehousecore
- **Port**: 8082
- **Datenbank**: `/data/warehousecore.db` (SQLite WAL-Modus)
- **Health Check**: `http://localhost:8082/health`

### db-backup
- **Zweck**: Automatische tägliche Backups
- **Backup-Verzeichnis**: `/backups` Volume
- **Retention**: 7 Tage (konfigurierbar via `BACKUP_RETENTION_DAYS`)

### mosquitto
- **Port**: 1883 (MQTT), 9001 (WebSocket)
- **Zweck**: LED-System Kommunikation

## Volumes

| Volume | Pfad im Container | Beschreibung |
|--------|-------------------|--------------|
| `sqlite-data` | `/data` | SQLite Datenbanken |
| `sqlite-backups` | `/backups` | Automatische Backups |
| `led-mapping` | `/var/lib/warehousecore/led` | LED-Konfiguration |
| `mosquitto-*` | `/mosquitto/*` | MQTT Broker Daten |

## Backup & Restore

### Automatische Backups
Der `db-backup` Service erstellt automatisch tägliche Backups:
- `rentalcore_YYYYMMDD_HHMMSS.db`
- `warehousecore_YYYYMMDD_HHMMSS.db`

### Manuelles Backup

```bash
# Mit dem Backup-Script
docker exec db-backup /bin/sh -c 'sqlite3 /data/rentalcore.db ".backup /backups/manual_rentalcore.db"'

# Oder direkt auf dem Host
./scripts/sqlite-backup.sh -d ./data -b ./backups -v -c
```

### Restore

```bash
# 1. Stack stoppen
docker compose down

# 2. Backup wiederherstellen
docker run --rm -v sqlite-data:/data -v sqlite-backups:/backups alpine \
  cp /backups/rentalcore_20231201_120000.db /data/rentalcore.db

# 3. Stack neu starten
docker compose up -d
```

### Backup auf anderem Host wiederherstellen

```bash
# 1. Backup-Datei kopieren
scp backup-server:/backups/rentalcore_*.db ./

# 2. In Volume kopieren
docker cp ./rentalcore_20231201_120000.db rentalcore:/data/rentalcore.db

# 3. Container neu starten
docker compose restart rentalcore
```

## Migration von MySQL

Wenn du von einer MySQL-Installation migrierst:

1. **Daten exportieren** (auf dem alten System):
   ```bash
   go run ./internal/migration/cmd/migrate-db \
     --mysql-host=localhost \
     --mysql-db=RentalCore \
     --sqlite-path=./rentalcore.db
   ```

2. **SQLite-Datei ins Volume kopieren**:
   ```bash
   docker compose up db-init  # Erstellt Volume-Struktur
   docker cp ./rentalcore.db $(docker volume inspect sqlite-data --format '{{ .Mountpoint }}')/
   ```

3. **Stack starten**:
   ```bash
   docker compose up -d
   ```

## Troubleshooting

### Datenbank ist gesperrt
SQLite unterstützt nur eine gleichzeitige Schreib-Verbindung. Bei "database is locked":

```bash
# Prüfe ob mehrere Prozesse auf die DB zugreifen
docker exec rentalcore fuser /data/rentalcore.db

# WAL-Checkpoint erzwingen
docker exec rentalcore sqlite3 /data/rentalcore.db "PRAGMA wal_checkpoint(TRUNCATE);"
```

### Container startet nicht
```bash
# Logs prüfen
docker compose logs rentalcore

# Datenbank-Integrität prüfen
docker run --rm -v sqlite-data:/data alpine \
  apk add sqlite && sqlite3 /data/rentalcore.db "PRAGMA integrity_check;"
```

### Performance-Optimierung
Die SQLite-Pragmas sind bereits optimiert:
- `journal_mode = WAL` - Write-Ahead Logging für bessere Concurrency
- `synchronous = NORMAL` - Guter Kompromiss zwischen Speed und Safety
- `cache_size = -64000` - 64MB Cache im RAM

## Unterschiede zu MySQL-Setup

| Aspekt | MySQL | SQLite |
|--------|-------|--------|
| Externer DB-Service | ✅ Ja | ❌ Nein (embedded) |
| Netzwerk-Zugriff | TCP/IP | Dateisystem |
| Backup | mysqldump | .backup Befehl |
| Connection Pool | Viele Verbindungen | Max 1 Write-Connection |
| Start-Zeit | ~90s | ~5s |
| RAM-Verbrauch | ~500MB+ | ~50MB |
| Skalierbarkeit | Horizontal | Vertikal |

## Fazit

SQLite bietet für diesen Use-Case erhebliche Vorteile:
- ✅ **Einfacher**: Kein separater DB-Server nötig
- ✅ **Schneller**: Keine Netzwerk-Latenz
- ✅ **Ressourcenschonend**: Weniger RAM, keine eigene Container
- ✅ **Backup-freundlich**: Einfache Dateikopie
- ✅ **Portable**: DB-Datei ist alles was du brauchst

Viel Erfolg mit dem neuen Setup! 🎉
