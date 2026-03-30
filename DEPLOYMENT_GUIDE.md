# 🚀 Fresh System Deployment Guide

Complete guide for deploying RentalCore + WarehouseCore on a fresh system.

**Last Updated:** January 2026

---

## ✅ Prerequisites

- **Docker Engine:** 20.10+
- **Docker Compose:** V2
- **RAM:** 2GB+ (4GB recommended)
- **Disk:** 10GB+ free space
- **Network:** Internet access to pull Docker images

---

## 📦 Fresh Deployment (5 Minutes)

### Step 1: Get the Project

```bash
git clone https://git.server-nt.de/ntielmann/cores.git
cd cores
```

Or download and extract the archive:
```bash
tar -xzf cores.tar.gz
cd cores
```

### Step 2: Configure Environment

```bash
cp .env.example .env
# Optional: Edit passwords for production
nano .env
```

**Minimum configuration (for local testing):**
- No changes needed, defaults work out of the box!

**Production configuration:**
```env
# Change these passwords!
POSTGRES_PASSWORD=your_secure_password_here

# Set your domains
RENTALCORE_DOMAIN=rent.example.com
WAREHOUSECORE_DOMAIN=warehouse.example.com
COOKIE_DOMAIN=.example.com
```

### Step 3: Start the Stack

```bash
docker compose up -d
```

**What happens automatically:**
1. ✅ PostgreSQL image pulled and started
2. ✅ Database schema automatically imported from `migrations/postgresql/`
3. ✅ Default admin user created (admin/admin)
4. ✅ Default roles and statuses created
5. ✅ RentalCore and WarehouseCore started
6. ✅ MQTT broker started for LED control
7. ✅ Daily backup service started

### Step 4: Wait for Initialization

**First start takes 1-2 minutes!** The database needs to import the schema.

```bash
# Monitor PostgreSQL initialization
docker compose logs -f postgres

# Wait for this message:
# "PostgreSQL init process complete; ready for start up."
# "database system is ready to accept connections"
```

### Step 5: Access the Applications

| Application | URL | Port |
|-------------|-----|------|
| RentalCore | http://localhost:8081 | 8081 |
| WarehouseCore | http://localhost:8082 | 8082 |

**Default Login:**
- **Username:** `admin`
- **Password:** `admin`
- ⚠️ **You will be forced to change the password on first login!**

---

## 🔑 What Gets Created Automatically

### Default Admin User

| Field | Value |
|-------|-------|
| Username | `admin` |
| Password | `admin` (must change on first login) |
| Email | `admin@example.com` |
| Roles | `super_admin`, `admin`, `warehouse_admin` |

### Default Roles

**RentalCore:**
- `super_admin` - Full access to both systems
- `admin` - RentalCore administration
- `manager` - Jobs, customers, devices
- `operator` - Operational work
- `viewer` - Read-only

**WarehouseCore:**
- `warehouse_admin` - Full warehouse admin
- `warehouse_manager` - Operations + reports
- `warehouse_worker` - Daily tasks
- `warehouse_viewer` - Read-only

### Default Job Statuses

- Planning
- Preparation
- Active
- Completed
- Invoiced
- Cancelled
- On Hold

### Default Storage Zones

- `MAIN-WH` - Main Warehouse
- `STAGE` - Staging Area

---

## 🔧 Troubleshooting

### Problem 1: Services in Restart Loop

**This is NORMAL during first start!**

PostgreSQL needs 30-60 seconds to import the database schema.

```bash
# Monitor PostgreSQL
docker compose logs -f postgres

# Once ready, services will automatically start
```

### Problem 2: Cannot Login with admin/admin

**Cause:** Existing PostgreSQL volume from previous install.

**Solution:**
```bash
# ⚠️ WARNING: This DELETES ALL DATA!
docker compose down -v
docker compose up -d
```

### Problem 3: Port Already in Use

```bash
# Check what's using the port
sudo lsof -i :8081
sudo lsof -i :8082
sudo lsof -i :5432

# Either stop the conflicting service or change ports in docker-compose.yml
```

### Problem 4: Services Won't Start

```bash
# Check detailed logs
docker compose logs --tail=100

# Pull fresh images
docker compose pull

# Force recreate
docker compose up -d --force-recreate
```

### Problem 5: Database Connection Errors

```bash
# Check if PostgreSQL is healthy
docker compose ps postgres

# Check database credentials
docker compose exec rentalcore env | grep -E "DB_|POSTGRES"
```

### Problem 6: Endless Login Redirect (Loop)

**Symptom:** You login successfully, get redirected to "Change Password" (or Dashboard), but then immediately back to Login page.

**Cause:** `COOKIE_DOMAIN` in `.env` is set to a domain (e.g. `.server-nt.de`) but you are accessing via `localhost` or IP. The browser rejects the cookie.

**Solution:**
1. Open `.env`
2. Comment out or empty `COOKIE_DOMAIN`:
   ```env
   # COOKIE_DOMAIN=.example.com
   COOKIE_DOMAIN=
   ```
3. Restart containers:
   ```bash
   docker compose up -d --force-recreate
   ```

---

## 🔄 Common Operations

### Complete Reset (Fresh Install)

```bash
# ⚠️ DELETES ALL DATA!
docker compose down -v
docker compose up -d
```

### Update to Latest Version

```bash
docker compose pull
docker compose up -d
```

### Manual Database Backup

```bash
docker compose exec postgres pg_dump -U rentalcore rentalcore > backup-$(date +%Y%m%d).sql
```

### Restore Database

```bash
docker compose exec -T postgres psql -U rentalcore rentalcore < backup.sql
```

### View Automated Backups

```bash
docker run --rm -v cores_postgres-backups:/backups alpine ls -lah /backups
```

---

## 📊 Startup Timeline

Understanding what happens during startup:

```
0s    - docker compose up -d
        ├─ PostgreSQL starts
        ├─ Mosquitto starts  
        └─ Apps wait for PostgreSQL health

5s    - PostgreSQL first healthcheck
10s   - Schema import begins (migrations/postgresql/)
30s   - Schema import continues...
60s   - PostgreSQL ready, healthcheck passes
        └─ RentalCore & WarehouseCore can now start

70s   - Apps connecting to database
90s   - Apps healthcheck passes
100s  - All services healthy ✅
```

**Key takeaway:** Wait at least 90 seconds on first start!

---

## 🔐 Production Security Checklist

After deployment, complete these steps:

- [ ] Login and change default admin password
- [ ] Update POSTGRES_PASSWORD in `.env`
- [ ] Set proper RENTALCORE_DOMAIN and WAREHOUSECORE_DOMAIN
- [ ] Configure nginx reverse proxy with HTTPS
- [ ] Enable firewall (block direct access to ports 8081, 8082, 5432)
- [ ] Set up regular database backups (already automated, verify!)
- [ ] Review and assign appropriate roles to users
- [ ] Change MQTT password if using LED system

---

## 📁 File Structure

```
cores/
├── docker-compose.yml          # Main deployment configuration
├── .env.example                # Environment template
├── .env                        # Your configuration (create from .env.example)
├── migrations/
│   └── postgresql/
│       └── 000_combined_init.sql   # Database schema (auto-imported)
├── nginx-reverse-proxy.conf    # Example nginx configuration
├── README.md                   # Main documentation
└── DEPLOYMENT_GUIDE.md         # This file
```

---

## 💡 Tips

1. **First Time?** Wait 2 minutes after `docker compose up -d`
2. **Already Running?** Use `docker compose down -v` to reset
3. **Check Logs!** Always monitor logs during first startup
4. **Backups!** Automated daily, but verify they work
5. **Production?** Change ALL default passwords!

---

## 🆘 Still Having Issues?

1. Check Docker version: `docker --version` (need 20.10+)
2. Check Compose version: `docker compose version` (need V2)
3. Check system resources: `free -h` and `df -h`
4. Get all logs: `docker compose logs > full-logs.txt`
5. Check network: `docker network ls`
6. Verify volumes: `docker volume ls`

**Complete reset:**
```bash
docker compose down -v
docker system prune -af --volumes
docker compose up -d
```

---

**Tsunami Events** - Professional Equipment Management

*Version: 2.0 | January 2026*
