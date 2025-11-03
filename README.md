# Tsunami Events - Core Management Systems

**Integrated Docker deployment for RentalCore and WarehouseCore**

A complete equipment rental and warehouse management solution built for professional event technology companies.

---

## 📋 Table of Contents

- [Overview](#-overview)
- [System Architecture](#-system-architecture)
- [Quick Start](#-quick-start)
- [Configuration](#-configuration)
- [Deployment Scenarios](#-deployment-scenarios)
- [Service Management](#-service-management)
- [Updates & Maintenance](#-updates--maintenance)
- [Troubleshooting](#-troubleshooting)
- [Project Links](#-project-links)

---

## 🎯 Overview

This repository contains the **deployment configuration** for the Tsunami Events core management systems:

### **RentalCore** - Job & Customer Management
- Equipment rental management
- Job tracking and scheduling
- Customer database
- Invoice generation
- Device assignment and tracking
- Revenue analytics

**Repository:** [git.server-nt.de/ntielmann/rentalcore](https://git.server-nt.de/ntielmann/rentalcore)
**Docker Image:** `nobentie/rentalcore:1.55` (`latest`)
**Port:** 8081

### **WarehouseCore** - Warehouse Management
- Physical warehouse management
- Device location tracking
- Storage zone mapping
- LED bin highlighting (MQTT-based)
- Device movement history
- Real-time inventory status

**Repository:** [git.server-nt.de/ntielmann/warehousecore](https://git.server-nt.de/ntielmann/warehousecore)
**Docker Image:** `nobentie/warehousecore:2.51` (`latest`)
**Port:** 8082

### **MySQL Database** - Shared Data Layer
- MySQL 8.0 containerized database
- Automatic schema initialization from `RentalCore.sql`
- Shared between both applications
- Persistent data storage with Docker volumes
- Health checks and automatic recovery

**Docker Image:** `mysql:8.0`
**Port:** 3306

### **Mosquitto MQTT Broker** - LED Control
- Self-hosted MQTT broker for LED warehouse bin highlighting
- Automatic configuration and user management
- Supports both plain and TLS connections
- WebSocket support for browser-based LED control

**Docker Image:** `eclipse-mosquitto:2.0`
**Ports:** 1883 (MQTT), 8883 (MQTT/TLS), 9001 (WebSocket)

---

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Tsunami Events Stack                      │
└─────────────────────────────────────────────────────────────┘

┌──────────────────┐      ┌──────────────────┐      ┌─────────┐
│   RentalCore     │◄────►│  WarehouseCore   │◄────►│ Mosquito│
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
         │  MySQL 8.0       │
         │  (Port 3306)     │
         │                  │
         │  Containerized   │
         │  Auto-Init DB    │
         └──────────────────┘

         SSO Cookie Domain: .example.com
         Auto Cross-Navigation Between Apps
         All Services in Docker Compose
```

**Key Features:**
- **Complete Stack**: Includes MySQL database, MQTT broker, and both applications
- **Automatic Database Setup**: Schema automatically initialized on first start
- **Shared Database Schema**: Both systems use the same MySQL database
- **Single Sign-On (SSO)**: Seamless authentication across both applications
- **Cross-Navigation**: Click to switch between RentalCore and WarehouseCore
- **MQTT Integration**: Real-time LED control for physical warehouse bins
- **Docker-Based**: One-command deployment with docker-compose
- **No External Dependencies**: Everything runs in containers

---

## 🚀 Quick Start

### Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+

**That's all you need!** The stack includes everything: MySQL database, MQTT broker, and both applications.

### Installation

1. **Clone this repository:**
```bash
git clone https://git.server-nt.de/ntielmann/cores.git
cd cores
```

2. **Copy environment configuration:**
```bash
cp .env.example .env
# Optional: Edit .env to change database passwords (recommended for production)
```

3. **Start the complete stack:**
```bash
docker compose up -d
```

The first start will:
- Download all Docker images
- Create and initialize the MySQL database with the schema
- Start all services with health checks
- This may take 1-2 minutes

4. **Access the applications:**
   - **RentalCore**: http://localhost:8081
   - **WarehouseCore**: http://localhost:8082

   **Default Admin Credentials (auto-provisioned on first DB init):**
   - **Username**: `admin`
   - **Password**: `admin`
   - **Roles**: `super_admin`, `admin`, `warehouse_admin`

   ⚠️ **IMPORTANT**: The `admin` user is now forced to change their password on the very first login before accessing the system.

   **Default Roles Created:**
   - **RentalCore**:
     - `super_admin` - Full access across both core systems
     - `admin` - Full RentalCore administration
     - `manager` - Job, device & customer management
     - `operator` - Operational work incl. scanning
     - `viewer` - Read-only insights
   - **WarehouseCore**:
     - `warehouse_admin` - Full warehouse administration
     - `warehouse_manager` - Warehouse operations + reporting
     - `warehouse_worker` - Daily warehouse tasks & scans
     - `warehouse_viewer` - Read-only warehouse access

5. **Check service status:**
```bash
docker compose ps
```

**That's it!** The complete system is now running with a fresh database, ready to use.

---

## ⚙️ Configuration

### Environment Variables (`.env`)

The `.env` file controls database credentials, cross-navigation domains, SSO, and MQTT settings.

#### **Database Configuration**

The included MySQL container is configured via these variables:

```env
DB_ROOT_PASSWORD=change_me_root_password_123
DB_NAME=RentalCore
DB_USER=rentalcore_user
DB_PASSWORD=change_me_user_password_456
```

**Important:**
- Change these passwords in production!
- The database schema (`RentalCore.sql`) is automatically imported on first start
- Data is persisted in Docker volume `mysql-data`

#### **Cross-Navigation Domains**

For **production with subdomains** (recommended):
```env
RENTALCORE_DOMAIN=rent.example.com
WAREHOUSECORE_DOMAIN=warehouse.example.com
COOKIE_DOMAIN=.example.com
```

For **local development**:
```env
# Leave empty - auto-detection uses localhost:8081 and localhost:8082
RENTALCORE_DOMAIN=
WAREHOUSECORE_DOMAIN=
COOKIE_DOMAIN=
```

#### **LED MQTT Configuration (WarehouseCore)**

For **self-hosted Mosquitto** (included in stack):
```env
LED_MQTT_HOST=mosquitto
LED_MQTT_PORT=1883
LED_MQTT_TLS=false
LED_MQTT_USER=leduser
LED_MQTT_PASS=ledpassword123
LED_MQTT_TOPIC_PREFIX=warehouse
LED_WAREHOUSE_ID=WH1
```

For **cloud MQTT broker** (EMQX, HiveMQ, etc.):
```env
LED_MQTT_HOST=your-broker.emqxsl.com
LED_MQTT_PORT=8883
LED_MQTT_TLS=true
LED_MQTT_USER=your_cloud_username
LED_MQTT_PASS=your_cloud_password
```

**Important:** The same MQTT credentials must be used in ESP32 firmware (`secrets.h`) for LED control.

---

## 🌐 Deployment Scenarios

### **Recommended: Subdomain Setup with nginx Reverse Proxy**

This is the **best setup for production** with clean URLs and SSL support.

#### 1. Create DNS Records

```
rent.example.com        A    123.45.67.89
warehouse.example.com   A    123.45.67.89
```

#### 2. Configure nginx Reverse Proxy

Use the included `nginx-reverse-proxy.conf` as a template:

```bash
# Copy and edit nginx configuration
sudo cp nginx-reverse-proxy.conf /etc/nginx/sites-available/cores.conf
# Edit the file to match your domains
sudo nano /etc/nginx/sites-available/cores.conf
sudo ln -s /etc/nginx/sites-available/cores.conf /etc/nginx/sites-enabled/

# Test and reload nginx
sudo nginx -t
sudo systemctl reload nginx
```

#### 3. Add SSL with Let's Encrypt (Optional)

```bash
sudo certbot --nginx -d rent.example.com -d warehouse.example.com
```

#### 4. Configure Environment

```env
RENTALCORE_DOMAIN=rent.example.com
WAREHOUSECORE_DOMAIN=warehouse.example.com
COOKIE_DOMAIN=.example.com
```

#### Benefits:
- ✅ No port numbers in URLs
- ✅ Clean URLs (https://rent.example.com)
- ✅ Automatic cross-navigation
- ✅ SSL/HTTPS support
- ✅ Professional appearance
- ✅ Single Sign-On (SSO) works seamlessly

---

### **Alternative: Local Development**

No configuration needed! The apps auto-detect localhost:

```bash
docker compose up -d
# RentalCore: http://localhost:8081
# WarehouseCore: http://localhost:8082
```

Cross-navigation works automatically between ports.

---

### **Alternative: VPS with Public IP and Ports**

For simple deployments without a domain:

```env
RENTALCORE_DOMAIN=123.45.67.89:8081
WAREHOUSECORE_DOMAIN=123.45.67.89:8082
```

**Drawback:** Port numbers must be specified in URLs.

---

### **Alternative: Internal Network**

For private network deployments:

```env
RENTALCORE_DOMAIN=192.168.1.100:8081
WAREHOUSECORE_DOMAIN=192.168.1.100:8082
```

---

## 🔧 Service Management

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f rentalcore
docker compose logs -f warehousecore
docker compose logs -f mosquitto

# Last 100 lines
docker compose logs --tail=100 rentalcore
```

### Restart Services

```bash
# Restart all
docker compose restart

# Restart specific service
docker compose restart rentalcore
docker compose restart warehousecore
```

### Stop Services

```bash
# Stop all (keeps data)
docker compose down

# Stop all and remove volumes (WARNING: deletes data)
docker compose down -v
```

### Check Service Health

```bash
docker compose ps

# Or check health endpoint directly
curl http://localhost:8081/health
curl http://localhost:8082/health
```

---

## 🔄 Updates & Maintenance

### Latest Release (2025-11-01)

- **RentalCore 1.55**  
  - Product-first job builder now shared between create/edit flows with availability awareness.  
  - Device write APIs respond with `410 Gone`, guiding users to WarehouseCore for inventory changes.
- **WarehouseCore 2.51**  
  - Includes the latest device catalog endpoints consumed by RentalCore’s product assignment workflow.

### Update Docker Images

```bash
# Pull latest images
docker compose pull

# Restart services with new images
docker compose up -d
```

This will download the latest versions from Docker Hub and restart the services.

### Update Specific Service

```bash
# Pull specific service
docker compose pull rentalcore

# Restart only that service
docker compose up -d rentalcore
```

### Force Recreate Containers

```bash
# Useful when configuration changes
docker compose up -d --force-recreate
```

### Backup Volumes

```bash
# MySQL database backup (IMPORTANT!)
docker run --rm -v lager_weidelbach_mysql-data:/data -v $(pwd):/backup alpine \
  tar czf /backup/mysql-backup-$(date +%Y%m%d).tar.gz /data

# LED mapping backup
docker run --rm -v lager_weidelbach_led-mapping:/data -v $(pwd):/backup alpine \
  tar czf /backup/led-mapping-backup.tar.gz /data

# Mosquitto data backup
docker run --rm -v lager_weidelbach_mosquitto-data:/data -v $(pwd):/backup alpine \
  tar czf /backup/mosquitto-backup.tar.gz /data
```

**Alternative: MySQL dump**
```bash
docker compose exec mysql mysqldump -u root -p${DB_ROOT_PASSWORD} RentalCore > backup-$(date +%Y%m%d).sql
```

---

## 🛠️ Troubleshooting

### ⚠️ Common Issues on Fresh Deployment

**1. Services in Restart Loop (First Start)**

This is **NORMAL** during first deployment! MySQL needs 60-90 seconds to import the database.

```bash
# Monitor MySQL initialization
docker compose logs -f mysql

# Wait for this message:
# "MySQL init process done. Ready for start up."
# "mysqld: ready for connections"
```

**Solution:** Wait 2-3 minutes. Services will start automatically once MySQL is healthy.

**2. Cannot Login with admin/admin**

This happens when you have an existing MySQL volume from a previous install.

```bash
# Check if admin user exists
docker compose exec mysql mysql -u root -p${DB_ROOT_PASSWORD} ${DB_NAME} \
  -e "SELECT username FROM users WHERE username='admin';"

# If empty, reset the database:
docker compose down -v  # ⚠️ DELETES ALL DATA!
docker compose up -d    # Triggers fresh database init
```

**Wait 2-3 minutes** after the reset for complete initialization.

**3. Services Start But Still Restart**

Check healthcheck status:

```bash
docker compose ps

# If unhealthy, check specific service logs
docker compose logs rentalcore
docker compose logs warehousecore
```

Common causes:
- Database connection refused (wait for MySQL to be fully ready)
- Wrong database credentials in `.env`
- Network issues between containers

**📖 Detailed Troubleshooting Guide:** See [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) for complete troubleshooting steps and solutions.

---

### Service Won't Start

**1. Check logs:**
```bash
docker compose logs [service-name]
```

**2. Check if ports are already in use:**
```bash
sudo lsof -i :8081
sudo lsof -i :8082
sudo lsof -i :1883
```

**3. Force recreate:**
```bash
docker compose up -d --force-recreate [service-name]
```

### Port Already in Use

Edit `docker-compose.yml` to change external ports:

```yaml
ports:
  - "9081:8081"  # External port 9081 instead of 8081
```

### Cross-Navigation Not Working

**1. Check environment variables:**
```bash
cat .env
```

**2. Verify domain configuration:**
```bash
docker compose exec rentalcore printenv | grep DOMAIN
docker compose exec warehousecore printenv | grep DOMAIN
```

**3. Restart services:**
```bash
docker compose up -d --force-recreate
```

### Database Connection Issues

**1. Check if MySQL container is healthy:**
```bash
docker compose ps mysql
docker compose logs mysql
```

**2. Test database connection:**
```bash
docker compose exec mysql mysql -u root -p${DB_ROOT_PASSWORD} -e "SHOW DATABASES;"
```

**3. Verify applications can connect:**
```bash
docker compose exec rentalcore wget -qO- http://localhost:8081/health
docker compose exec warehousecore wget -qO- http://localhost:8082/health
```

**4. If database initialization failed:**
```bash
# Stop and remove all containers and volumes
docker compose down -v

# Start fresh (will reinitialize database)
docker compose up -d
```

**5. Check database credentials in `.env` file**

### Mosquitto MQTT Not Connecting

**1. Check Mosquitto logs:**
```bash
docker compose logs mosquitto
```

**2. Verify MQTT credentials:**
```bash
docker compose exec mosquitto cat /mosquitto/config/passwd
```

**3. Test MQTT connection:**
```bash
docker compose exec mosquitto mosquitto_sub -h localhost -p 1883 \
  -u leduser -P ledpassword123 -t 'warehouse/#' -v
```

### LED Mapping File Issues

**1. Check LED mapping volume:**
```bash
docker volume inspect cores_led-mapping
```

**2. View current mapping:**
```bash
docker compose exec warehousecore cat /var/lib/warehousecore/led/led_mapping.json
```

**3. Reset to defaults:**
```bash
docker volume rm cores_led-mapping
docker compose restart warehousecore
```

---

## 📚 Project Links

### Repositories

- **This Deployment Repository**: [git.server-nt.de/ntielmann/cores](https://git.server-nt.de/ntielmann/cores)
- **RentalCore**: [git.server-nt.de/ntielmann/rentalcore](https://git.server-nt.de/ntielmann/rentalcore)
- **WarehouseCore**: [git.server-nt.de/ntielmann/warehousecore](https://git.server-nt.de/ntielmann/warehousecore)

### Docker Images

- **RentalCore**: [nobentie/rentalcore](https://hub.docker.com/r/nobentie/rentalcore)
- **WarehouseCore**: [nobentie/warehousecore](https://hub.docker.com/r/nobentie/warehousecore)

### Documentation

- **RentalCore README**: See rentalcore repository
- **WarehouseCore README**: See warehousecore repository
- **Development Guide**: See `CLAUDE.md` in this repository
- **Database Schema**: `RentalCore.sql`

---

## 🔐 Security Notes

- **Default Admin User**: A default admin account (username: `admin`, password: `admin`) is created automatically on first startup. **Change this password immediately!**
- The `.env` file contains **no database credentials** (safe to commit)
- Database credentials are in `docker-compose.yml` (for demo/testing only)
- **For production**: Use Docker Secrets or external secret management
- **MQTT Credentials**: Must match ESP32 firmware settings
- **SSO**: Cookie domain must start with `.` for subdomain sharing (e.g., `.example.com`)

---

## 📝 System Requirements

- **Docker Engine**: 20.10 or higher
- **Docker Compose**: 2.0 or higher
- **RAM**: 4GB minimum (8GB recommended for production)
- **CPU**: 2 cores minimum (4 cores recommended)
- **Disk**: 20GB minimum for images, database, and volumes
- **Network**: Internet connection to pull Docker images

**Note:** MySQL database is included in the stack - no external database required!

---

## 🌟 Features

### RentalCore
- Advanced job management
- Customer database
- Device inventory tracking
- Invoice generation
- Revenue analytics
- Real-time device availability
- Category-based organization
- Job status tracking

### WarehouseCore
- Physical warehouse mapping
- Storage zone management
- Device location tracking
- LED bin highlighting via MQTT
- Real-time device movements
- Integration with RentalCore jobs
- ESP32-based LED control
- Maintenance tracking

### Integrated Features
- **Single Sign-On (SSO)**: Login once, access both systems
- **Cross-Navigation**: Seamless switching between apps
- **Shared Database**: Synchronized data across systems
- **Real-time Updates**: Changes reflect immediately
- **Mobile-Friendly**: Responsive design for tablets and phones

---

## 📞 Support

For issues, questions, or feature requests:

- **RentalCore Issues**: [git.server-nt.de/ntielmann/rentalcore/issues](https://git.server-nt.de/ntielmann/rentalcore/issues)
- **WarehouseCore Issues**: [git.server-nt.de/ntielmann/warehousecore/issues](https://git.server-nt.de/ntielmann/warehousecore/issues)
- **Deployment Issues**: [git.server-nt.de/ntielmann/cores/issues](https://git.server-nt.de/ntielmann/cores/issues)

---

## 📄 License

This deployment configuration is part of the Tsunami Events management system.

Individual licenses for RentalCore and WarehouseCore are specified in their respective repositories.

---

**Tsunami Events** - Professional Equipment Rental and Warehouse Management System
