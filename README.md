# 🎯 Tsunami Events - Core Management Systems

Fork from [https://git.server-nt.de/ntielmann/cores](https://git.server-nt.de/ntielmann/cores)

**Complete Docker-based deployment for RentalCore and WarehouseCore**

An integrated equipment rental and warehouse management solution for professional event technology companies.

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Quick Start](#-quick-start)
- [System Architecture](#-system-architecture)
- [Configuration](#-configuration)
- [Deployment Scenarios](#-deployment-scenarios)
- [Default User & Roles](#-default-user--roles)
- [Service Management](#-service-management)
- [Updates & Maintenance](#-updates--maintenance)
- [Troubleshooting](#-troubleshooting)
- [Project Links](#-project-links)

---

## 🎯 Overview

This repository contains the **deployment configuration** for the Tsunami Events core management systems.
Deploy both applications on any server with a single `docker compose up -d` command.

### **RentalCore** - Job & Customer Management
- Equipment rental management and job tracking
- Customer database with complete history
- Invoice generation and revenue analytics
- Device assignment and availability tracking
- PDF processing with OCR and intelligent product mapping

**Repository:** [git.server-nt.de/ntielmann/rentalcore](https://git.server-nt.de/ntielmann/rentalcore)
**Docker Image:** `nobentie/rentalcore:5.3.0` (`latest`)
**Port:** 8081

### **WarehouseCore** - Warehouse Management
- Physical warehouse mapping with zone management
- Device location tracking and movement history
- LED bin highlighting via MQTT (ESP32-based)
- Real-time inventory status and barcode scanning
- Case and cable management

**Repository:** [git.server-nt.de/ntielmann/warehousecore](https://git.server-nt.de/ntielmann/warehousecore)
**Docker Image:** `nobentie/warehousecore:5.8.0` (`latest`)
**Port:** 8082

### **Shared Components**
- **PostgreSQL 16** - Shared database (auto-initialized)
- **Mosquitto MQTT** - LED control broker (included)
- **Automatic Backups** - Daily database backups with retention

---

## 🚀 Quick Start

### Prerequisites

- Docker Engine 20.10+
- Docker Compose V2

**That's all you need!** Everything else is included.

### Installation (3 Steps)

1. **Clone this repository:**
```bash
git clone https://git.server-nt.de/ntielmann/cores.git
cd cores
```

2. **Create configuration file:**
```bash
cp .env.example .env
# Optional: Edit .env to change passwords (recommended for production)
```

3. **Start the complete stack:**
```bash
docker compose up -d
```

**Wait 1-2 minutes** for the database to initialize, then access:
- **RentalCore**: http://localhost:8081
- **WarehouseCore**: http://localhost:8082

### Default Login

| Username | Password | Notes |
|----------|----------|-------|
| `admin`  | `admin`  | **You will be forced to change the password on first login!** |

---

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Tsunami Events Stack                      │
└─────────────────────────────────────────────────────────────┘

┌──────────────────┐      ┌──────────────────┐      ┌─────────┐
│   RentalCore     │◄────►│  WarehouseCore   │◄────►│Mosquitto│
│   (Port 8081)    │      │   (Port 8082)    │      │  MQTT   │
│                  │      │                  │      │ Broker  │
│ • Jobs           │      │ • Zones          │      │         │
│ • Customers      │      │ • Locations      │      │ LED Ctrl│
│ • Devices        │      │ • Movements      │      │         │
│ • Invoices       │      │ • LED Control    │      │         │
└────────┬─────────┘      └────────┬─────────┘      └─────────┘
         │                         │
         └────────┬────────────────┘
                  │
         ┌────────▼─────────┐
         │  PostgreSQL 16   │
         │  (Port 5432)     │
         │                  │
         │  Auto-Init DB    │
         │  Daily Backups   │
         └──────────────────┘

         SSO Cookie Domain: Configured via .env
         Cross-Navigation: Automatic switching between apps
```

### Key Features

- ✅ **Complete Stack** - PostgreSQL, MQTT, and both applications included
- ✅ **Automatic Database Setup** - Schema auto-initialized on first start
- ✅ **Single Sign-On (SSO)** - One login for both applications
- ✅ **Cross-Navigation** - Seamless switching between apps
- ✅ **Daily Backups** - Automatic PostgreSQL backups with 7-day retention
- ✅ **LED Integration** - MQTT-based warehouse bin highlighting
- ✅ **No External Dependencies** - Everything runs in containers

---

## ⚙️ Configuration

### Environment Variables (`.env`)

Copy `.env.example` to `.env` and adjust:

#### Database

```env
POSTGRES_DB=rentalcore
POSTGRES_USER=rentalcore
POSTGRES_PASSWORD=rentalcore123  # CHANGE IN PRODUCTION!
```

#### Cross-Navigation (Production)

```env
# For subdomains (recommended):
RENTALCORE_DOMAIN=rent.example.com
WAREHOUSECORE_DOMAIN=warehouse.example.com
COOKIE_DOMAIN=.example.com

# For localhost development: Leave empty
RENTALCORE_DOMAIN=
WAREHOUSECORE_DOMAIN=
COOKIE_DOMAIN=
```

#### LED MQTT

```env
LED_MQTT_HOST=mosquitto
LED_MQTT_PORT=1883
LED_MQTT_USER=leduser
LED_MQTT_PASS=ledpassword123
```

---

## 🌐 Deployment Scenarios

### Local Development

```bash
docker compose up -d
# RentalCore: http://localhost:8081
# WarehouseCore: http://localhost:8082
```

### Production with Subdomains

1. Configure DNS:
   - `rent.example.com` → Your Server IP
   - `warehouse.example.com` → Your Server IP

2. Set `.env`:
```env
RENTALCORE_DOMAIN=rent.example.com
WAREHOUSECORE_DOMAIN=warehouse.example.com
COOKIE_DOMAIN=.example.com
```

3. Use nginx reverse proxy (see `nginx-reverse-proxy.conf`)

4. Add SSL with Let's Encrypt:
```bash
sudo certbot --nginx -d rent.example.com -d warehouse.example.com
```

---

## 👤 Default User & Roles

### Default Admin User

Created automatically on first database initialization:

| Field | Value |
|-------|-------|
| Username | `admin` |
| Password | `admin` |
| Email | `admin@example.com` |
| Roles | `super_admin`, `admin`, `warehouse_admin` |

**⚠️ IMPORTANT:** Password change is enforced on first login!

### Role Hierarchy

| Role | Scope | Description |
|------|-------|-------------|
| `super_admin` | Global | Full access to both systems |
| `admin` | RentalCore | RentalCore administration |
| `manager` | RentalCore | Jobs, customers, devices management |
| `operator` | RentalCore | Operational flows with scanning |
| `viewer` | RentalCore | Read-only access |
| `warehouse_admin` | WarehouseCore | Warehouse administration |
| `warehouse_manager` | WarehouseCore | Warehouse operations + reports |
| `warehouse_worker` | WarehouseCore | Daily warehouse tasks |
| `warehouse_viewer` | WarehouseCore | Read-only warehouse access |

---

## 🔧 Service Management

### View Logs

```bash
docker compose logs -f              # All services
docker compose logs -f rentalcore   # Specific service
docker compose logs --tail=100 postgres  # Last 100 lines
```

### Restart Services

```bash
docker compose restart              # All services
docker compose restart rentalcore   # Specific service
```

### Stop Services

```bash
docker compose down                 # Stop (keeps data)
docker compose down -v              # Stop and DELETE ALL DATA
```

### Health Check

```bash
docker compose ps
curl http://localhost:8081/health
curl http://localhost:8082/health
```

---

## 🔄 Updates & Maintenance

### Current Versions

- **RentalCore:** 5.3.0 (January 2026)
- **WarehouseCore:** 5.8.0 (January 2026)

### Update to Latest

```bash
docker compose pull
docker compose up -d
```

### Database Backup

```bash
# Manual backup
docker compose exec postgres pg_dump -U rentalcore rentalcore > backup-$(date +%Y%m%d).sql

# Automated backups are stored in the postgres-backups volume
docker run --rm -v cores_postgres-backups:/backups alpine ls -la /backups
```

### Restore Database

```bash
docker compose exec -T postgres psql -U rentalcore rentalcore < backup.sql
```

### Unified Migration Image (GHCR)

This repository now ships a dedicated migration image that runs all SQL files in
`migrations/postgresql` exactly once, tracked in `schema_migrations`.

- Docker build file: `Dockerfile.migrations`
- Runtime script: `scripts/k8s/run_migrations.sh`
- Release workflow: `.github/workflows/release-migrations-on-merge-label.yml`
- Label check workflow: `.github/workflows/require-release-label.yml`

Release behavior:

- Merged PR with label `patch`, `minor`, or `major` creates a new semantic tag.
- A GitHub Release is created from that tag.
- Migration image is pushed to GHCR as:
   - `ghcr.io/<owner>/cores-migrations:<version>`
   - `ghcr.io/<owner>/cores-migrations:latest`

Manual local build example:

```bash
docker build -f Dockerfile.migrations -t ghcr.io/<owner>/cores-migrations:local .
```

Manual run example:

```bash
docker run --rm \
   -e DB_HOST=localhost \
   -e DB_PORT=5432 \
   -e DB_NAME=rentalcore \
   -e DB_USER=rentalcore \
   -e DB_PASSWORD=rentalcore123 \
   ghcr.io/<owner>/cores-migrations:local
```

Kubernetes example job:

- `k8s/examples/migrations-job.yaml`

---

## 🛠️ Troubleshooting

### First Start Issues

**1. Services restarting continuously?**
- Normal during first start! PostgreSQL needs 30-60 seconds to initialize.
- Monitor: `docker compose logs -f postgres`
- Wait for: "database system is ready to accept connections"

**2. Can't login with admin/admin?**
- Existing volume won't reinitialize. Reset with:
```bash
docker compose down -v  # ⚠️ DELETES ALL DATA!
docker compose up -d
```

**3. Port already in use?**
```bash
sudo lsof -i :8081
sudo lsof -i :8082
```

### Common Solutions

```bash
# Complete reset
docker compose down -v
docker compose up -d

# Force recreate containers
docker compose up -d --force-recreate

# Pull fresh images
docker compose pull
```

---

## 📚 Project Links

### Repositories

- **This Deployment Repo**: [git.server-nt.de/ntielmann/cores](https://git.server-nt.de/ntielmann/cores)
- **RentalCore**: [git.server-nt.de/ntielmann/rentalcore](https://git.server-nt.de/ntielmann/rentalcore)
- **WarehouseCore**: [git.server-nt.de/ntielmann/warehousecore](https://git.server-nt.de/ntielmann/warehousecore)

### Docker Images

- **RentalCore**: [hub.docker.com/r/nobentie/rentalcore](https://hub.docker.com/r/nobentie/rentalcore)
- **WarehouseCore**: [hub.docker.com/r/nobentie/warehousecore](https://hub.docker.com/r/nobentie/warehousecore)

### Documentation

- **Database Schema**: `migrations/postgresql/000_combined_init.sql`
- **Nginx Config**: `nginx-reverse-proxy.conf`
- **Development Guide**: `CLAUDE.md`

---

## 📝 System Requirements

- **Docker Engine**: 20.10+
- **Docker Compose**: V2
- **RAM**: 4GB minimum (8GB recommended)
- **CPU**: 2 cores minimum
- **Disk**: 20GB minimum

---

## 🔐 Security Notes

- Default admin password must be changed on first login
- Change database passwords in production!
- Use HTTPS with a reverse proxy for production
- MQTT credentials must match ESP32 firmware

---

**Tsunami Events** - Professional Equipment Rental and Warehouse Management

*Last updated: January 2026*
