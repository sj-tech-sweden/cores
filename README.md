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
**Docker Image:** `nobentie/rentalcore:latest`
**Port:** 8081

### **WarehouseCore** - Warehouse Management
- Physical warehouse management
- Device location tracking
- Storage zone mapping
- LED bin highlighting (MQTT-based)
- Device movement history
- Real-time inventory status

**Repository:** [git.server-nt.de/ntielmann/warehousecore](https://git.server-nt.de/ntielmann/warehousecore)
**Docker Image:** `nobentie/warehousecore:latest`
**Port:** 8082

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
         │  Shared MySQL    │
         │    Database      │
         │  (RentalCore)    │
         │ tsunami-events.de│
         └──────────────────┘

         SSO Cookie Domain: .server-nt.de
         Auto Cross-Navigation Between Apps
```

**Key Features:**
- **Shared Database Schema**: Both systems use the same MySQL database
- **Single Sign-On (SSO)**: Seamless authentication across both applications
- **Cross-Navigation**: Click to switch between RentalCore and WarehouseCore
- **MQTT Integration**: Real-time LED control for physical warehouse bins
- **Docker-Based**: Easy deployment with docker-compose

---

## 🚀 Quick Start

### Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- Access to the shared MySQL database (tsunami-events.de)

### Installation

1. **Clone this repository:**
```bash
git clone https://git.server-nt.de/ntielmann/cores.git
cd cores
```

2. **Copy environment configuration:**
```bash
cp .env.example .env
# Edit .env if needed (optional for localhost development)
```

3. **Pull the latest images:**
```bash
docker compose pull
```

4. **Start the stack:**
```bash
docker compose up -d
```

5. **Access the applications:**
   - **RentalCore**: http://localhost:8081
   - **WarehouseCore**: http://localhost:8082

6. **Check service status:**
```bash
docker compose ps
```

**That's it!** Both applications are now running and communicating with the shared database.

---

## ⚙️ Configuration

### Environment Variables (`.env`)

The `.env` file controls cross-navigation domains, SSO, and MQTT settings.

#### **Cross-Navigation Domains**

For **production with subdomains** (recommended):
```env
RENTALCORE_DOMAIN=rent.server-nt.de
WAREHOUSECORE_DOMAIN=warehouse.server-nt.de
COOKIE_DOMAIN=.server-nt.de
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
LED_MQTT_TOPIC_PREFIX=weidelbach
LED_WAREHOUSE_ID=WDL
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

### Database Configuration

Database credentials are configured in `docker-compose.yml`:

```yaml
# Shared database for both services
DB_HOST: tsunami-events.de
DB_NAME: RentalCore
DB_USERNAME: tsweb  # or DB_USER for WarehouseCore
DB_PASSWORD: j4z4mZv7DpG7cdCLkSQVjXCfXMOmt9dEGRp2Pmdn2Xzl5y8AAkwLmKX
```

**Database Schema:** Available in `RentalCore.sql`

---

## 🌐 Deployment Scenarios

### **Recommended: Subdomain Setup with nginx Reverse Proxy**

This is the **best setup for production** with clean URLs and SSL support.

#### 1. Create DNS Records

```
rent.server-nt.de        A    123.45.67.89
warehouse.server-nt.de   A    123.45.67.89
```

#### 2. Configure nginx Reverse Proxy

Use the included `nginx-reverse-proxy.conf`:

```bash
# Copy nginx configuration
sudo cp nginx-reverse-proxy.conf /etc/nginx/sites-available/lager-weidelbach.conf
sudo ln -s /etc/nginx/sites-available/lager-weidelbach.conf /etc/nginx/sites-enabled/

# Test and reload nginx
sudo nginx -t
sudo systemctl reload nginx
```

#### 3. Add SSL with Let's Encrypt (Optional)

```bash
sudo certbot --nginx -d rent.server-nt.de -d warehouse.server-nt.de
```

#### 4. Configure Environment

```env
RENTALCORE_DOMAIN=rent.server-nt.de
WAREHOUSECORE_DOMAIN=warehouse.server-nt.de
COOKIE_DOMAIN=.server-nt.de
```

#### Benefits:
- ✅ No port numbers in URLs
- ✅ Clean URLs (https://rent.server-nt.de)
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
# LED mapping backup
docker run --rm -v cores_led-mapping:/data -v $(pwd):/backup alpine \
  tar czf /backup/led-mapping-backup.tar.gz /data

# Mosquitto data backup
docker run --rm -v cores_mosquitto-data:/data -v $(pwd):/backup alpine \
  tar czf /backup/mosquitto-backup.tar.gz /data
```

---

## 🛠️ Troubleshooting

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

**1. Test database connectivity:**
```bash
docker compose exec rentalcore wget -qO- http://localhost:8081/health
```

**2. Check database credentials in `docker-compose.yml`**

**3. Verify database is accessible:**
```bash
mysql -h tsunami-events.de -u tsweb -p RentalCore
```

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
  -u leduser -P ledpassword123 -t 'weidelbach/#' -v
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

- The `.env` file contains **no database credentials** (safe to commit)
- Database credentials are in `docker-compose.yml` (for demo/testing only)
- **For production**: Use Docker Secrets or external secret management
- **MQTT Credentials**: Must match ESP32 firmware settings
- **SSO**: Cookie domain must start with `.` for subdomain sharing (e.g., `.server-nt.de`)

---

## 📝 System Requirements

- **Docker Engine**: 20.10 or higher
- **Docker Compose**: 2.0 or higher
- **RAM**: 2GB minimum (4GB recommended)
- **CPU**: 2 cores minimum
- **Disk**: 10GB minimum for images and volumes
- **Network**: Access to tsunami-events.de:3306 (MySQL)

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
