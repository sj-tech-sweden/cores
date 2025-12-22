# 🚀 Fresh System Deployment Guide

Complete guide for deploying RentalCore + WarehouseCore on a fresh system.

## ✅ Prerequisites

- Docker Engine 20.10+
- Docker Compose V2
- Git (optional, for cloning)
- 2GB+ RAM
- 10GB+ free disk space

## 📦 Fresh Deployment Steps

### 1. Get the Project

```bash
# Clone or download the project
git clone <repository-url>
cd cores

# Or if provided as archive
tar -xzf cores.tar.gz
cd cores
```

### 2. Configure Environment

```bash
# Create .env file from example
cat > .env << 'EOF'
# Database Configuration
POSTGRES_PASSWORD=secure_root_password_change_me
DB_HOST=postgres
DB_PORT=5432
DB_NAME=RentalCore
DB_USER=tsweb
DB_PASSWORD=your_secure_password_here
DB_SSLMODE=disable

# Domain Configuration (optional, leave empty for localhost)
RENTALCORE_DOMAIN=
WAREHOUSECORE_DOMAIN=
COOKIE_DOMAIN=

# MQTT Configuration for LED System
LED_MQTT_HOST=mosquitto
LED_MQTT_PORT=1883
LED_MQTT_TLS=false
LED_MQTT_USER=leduser
LED_MQTT_PASS=ledpassword123
LED_MQTT_TOPIC_PREFIX=weidelbach
LED_WAREHOUSE_ID=weidelbach
LED_MQTT_CONNECT_RETRIES=10
LED_MQTT_CONNECT_RETRY_DELAY_MS=2000

# Admin Match (for special admin features)
ADMIN_NAME_MATCH=Your Admin Name
EOF

# Edit with your values
nano .env
```

### 3. Deploy the Stack

```bash
# Start all services
docker-compose up -d

# This will:
# 1. Pull PostgreSQL, RentalCore, WarehouseCore, and Mosquitto images
# 2. Create the database and automatically import schema from /migrations/postgresql/
# 3. Start all services with proper healthchecks
```

### 4. Wait for Initialization

**IMPORTANT:** First startup takes 1-2 minutes for database initialization!

```bash
# Monitor PostgreSQL initialization (most important)
docker-compose logs -f postgres

# Look for this message:
# "PostgreSQL init process complete; ready for start up."
# "database system is ready to accept connections"

# Monitor RentalCore startup
docker-compose logs -f rentalcore

# Monitor WarehouseCore startup
docker-compose logs -f warehousecore
```

### 5. Verify Services

```bash
# Check all services are healthy
docker-compose ps

# Expected output:
# NAME             STATUS
# postgres         Up (healthy)
# rentalcore       Up (healthy)
# warehousecore    Up (healthy)
# mosquitto        Up (healthy)
```

### 6. Access Applications

**RentalCore (Job Management):**
- URL: `http://localhost:8081`
- Default Login:
  - Username: `admin`
  - Password: `admin`

**WarehouseCore (Warehouse Management):**
- URL: `http://localhost:8082`
- Uses same credentials (shared database)

**⚠️ IMPORTANT:** The `admin` user is forced to change their password on the very first login before accessing the system.

---

## 🔧 Troubleshooting

### Problem 1: Services in Restart Loop

**Symptoms:**
```bash
docker-compose ps
# Shows containers restarting continuously
```

**Cause:** PostgreSQL initialization takes longer than expected.

**Solution:**
```bash
# Wait 1-2 minutes for PostgreSQL to fully initialize
docker-compose logs -f postgres

# Once you see "ready to accept connections", restart the apps
docker-compose restart rentalcore warehousecore
```

**Prevention:** The healthcheck settings have been optimized:
- PostgreSQL `start_period: 60s` - gives time for SQL import
- Apps `start_period: 120s` - wait for DB connection
- Increased retries to handle longer init times

### Problem 2: Cannot Login with admin/admin

**Symptoms:**
- Login fails with "Invalid username or password"
- Database seems to be running

**Possible Causes:**

#### A) Existing Volume from Previous Install

If you previously started the stack, the PostgreSQL volume exists and **won't be re-initialized**.

**Solution:**
```bash
# Stop and remove ALL volumes (⚠️ DELETES ALL DATA!)
docker-compose down -v

# Start fresh (triggers database initialization)
docker-compose up -d

# Wait 1-2 minutes for initialization
docker-compose logs -f postgres
```

#### B) Database Import Failed

Check if the SQL import completed successfully:

```bash
# Check PostgreSQL logs for errors
docker-compose logs postgres | grep -i error

# Verify admin user exists
docker-compose exec postgres psql -U ${DB_USER} -d ${DB_NAME} \
  -c "SELECT username, email FROM users WHERE username='admin';"

# Expected output:
#  username |      email
# ----------+-----------------
#  admin    | admin@example.com
# (1 row)
```

#### C) Wrong Database Credentials in App

Verify environment variables:

```bash
# Check RentalCore environment
docker-compose exec rentalcore env | grep DB_

# Should match your .env file settings
```

### Problem 3: Port Already in Use

**Symptoms:**
```bash
Error: bind: address already in use
```

**Solution:**
```bash
# Find what's using the port
sudo lsof -i :8081
sudo lsof -i :5432

# Either stop the conflicting service or change ports in docker-compose.yml
```

### Problem 4: Slow Performance

**Symptoms:**
- Applications respond slowly
- Database queries timeout

**Solutions:**

1. **Increase Docker Resources:**
```bash
# Edit Docker Desktop settings or Docker daemon
# Minimum: 2GB RAM, 2 CPU cores
```

2. **Check System Resources:**
```bash
# Monitor container resources
docker stats

# If PostgreSQL uses too much memory, tune postgresql.conf
```

### Problem 5: Services Won't Start

**Symptoms:**
- Container exits immediately
- No logs available

**Diagnostic Steps:**

```bash
# Check detailed logs
docker-compose logs --tail=100

# Check if images pulled correctly
docker images | grep -E "rentalcore|warehousecore|postgres"

# Try pulling images manually
docker-compose pull

# Check Docker daemon
sudo systemctl status docker
```

---

## 🔄 Common Operations

### Reset Everything (Fresh Start)

```bash
# Complete reset - removes all data!
docker-compose down -v
docker system prune -f
docker-compose up -d
```

### Update to Latest Version

```bash
# Pull latest images
docker-compose pull

# Restart with new images (keeps data!)
docker-compose up -d
```

### Backup Database

```bash
# Export database
docker-compose exec postgres pg_dump -U ${DB_USER} ${DB_NAME} > backup.sql

# Or export specific tables
docker-compose exec postgres pg_dump -U ${DB_USER} -t users -t jobs -t devices ${DB_NAME} > backup.sql
```

### Restore Database

```bash
# Import backup
docker-compose exec -T postgres psql -U ${DB_USER} ${DB_NAME} < backup.sql
```

### View Real-Time Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f rentalcore

# Last 100 lines
docker-compose logs --tail=100 postgres
```

### Access Database Directly

```bash
# PostgreSQL shell
docker-compose exec postgres psql -U ${DB_USER} ${DB_NAME}

# Run single query
docker-compose exec postgres psql -U ${DB_USER} ${DB_NAME} \
  -c "SELECT * FROM users;"
```

---

## 📊 Healthcheck Timeline

Understanding startup timing helps diagnose issues:

```
0s    - docker-compose up -d
      ├─ PostgreSQL starts
      ├─ Mosquitto starts
      └─ Apps wait (depends_on: service_healthy)

5s    - PostgreSQL first healthcheck attempt
10s   - PostgreSQL importing schema from /migrations/postgresql/...
20s   - Still importing...
40s   - Import complete, PostgreSQL starts
60s   - PostgreSQL healthcheck succeeds (start_period ends)
      └─ RentalCore & WarehouseCore can now start

70s   - Apps connecting to database
90s   - Apps healthcheck start_period ends
100s  - All services healthy ✅
```

**Key Points:**
- First 60s: PostgreSQL initialization
- Next 30s: Apps startup
- Total: ~90 seconds for fresh deployment

---

## 🔐 Security Checklist

After deployment, complete these security steps:

- [ ] Change default admin password
- [ ] Update `.env` with strong passwords
- [ ] Set proper `POSTGRES_PASSWORD`
- [ ] Configure domain names for production
- [ ] Enable HTTPS/TLS (use reverse proxy)
- [ ] Restrict PostgreSQL port 5432 (firewall)
- [ ] Review user permissions
- [ ] Enable 2FA for admin accounts
- [ ] Regular database backups
- [ ] Update Docker images regularly

---

## 📚 Additional Resources

- [RentalCore README](rentalcore/README.md)
- [Database Setup Guide](rentalcore/docs/DATABASE_SETUP.md)
- [CLAUDE.md](CLAUDE.md) - Development guidelines

---

## 💡 Tips

1. **First Time?** Wait 90 seconds after `docker-compose up -d` before checking
2. **Already Running?** Use `docker-compose down -v` to reset database
3. **Check Logs!** Always monitor logs during first startup
4. **Passwords!** Change defaults immediately in production
5. **Backups!** Set up automated database backups

---

## 🆘 Still Having Issues?

If problems persist after following this guide:

1. Check Docker version: `docker --version` (need 20.10+)
2. Check Compose version: `docker-compose version` (need V2+)
3. Check system resources: `free -h` and `df -h`
4. Review complete logs: `docker-compose logs > full-logs.txt`
5. Check network: `docker network ls`
6. Verify volumes: `docker volume ls`

**Clean slate approach:**
```bash
# Nuclear option - removes everything
docker-compose down -v
docker system prune -af --volumes
docker-compose up -d
```

---

**Last Updated:** 2025-10-26
**Version:** 1.0
