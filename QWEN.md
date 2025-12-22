# Qwen Code Context - Tsunami Events Core Management Systems

## Project Overview

This is a comprehensive equipment rental and warehouse management solution built for professional event technology companies. The system consists of two main Go applications:

- **RentalCore**: Job and customer management system for equipment rentals
- **WarehouseCore**: Physical warehouse management with LED bin highlighting via MQTT
- **Shared PostgreSQL Database**: Single database serving both applications
- **MQTT Broker**: For real-time LED control in the warehouse

The system is deployed using Docker Compose with automatic database initialization from PostgreSQL schema files.

## Architecture

```
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
         │  PostgreSQL 17   │
         │  (Port 5432)     │
         │                  │
         │  Containerized   │
         │  Auto-Init DB    │
         └──────────────────┘
```

## Key Features

### RentalCore
- Equipment rental management
- Job tracking and scheduling
- Customer database
- Invoice generation
- Device assignment and tracking
- Revenue analytics

### WarehouseCore
- Physical warehouse management
- Device location tracking
- Storage zone mapping
- LED bin highlighting (MQTT-based)
- Device movement history
- Real-time inventory status

### Shared Features
- Single Sign-On (SSO) between applications
- Automatic cross-navigation
- Shared database schema
- Real-time updates between systems

## Building and Running

### Prerequisites
- Docker Engine 20.10+
- Docker Compose 2.0+

### Quick Start
```bash
# 1. Clone the repository
git clone https://git.server-nt.de/ntielmann/cores.git
cd cores

# 2. Copy environment configuration
cp .env.example .env
# Optional: Edit .env to change database passwords

# 3. Start the complete stack
docker compose up -d

# 4. Access the applications:
#    RentalCore: http://localhost:8081
#    WarehouseCore: http://localhost:8082
```

### Default Credentials
- Username: `admin`
- Password: `admin`
- Roles: `super_admin`, `admin`, `warehouse_admin`

**Important**: The admin user is forced to change their password on first login.

## Development Structure

### Code Organization
- `/rentalcore` - Rental management application
- `/warehousecore` - Warehouse management application
- `/migrations` - PostgreSQL database migration files
  - `/postgresql` - PostgreSQL-specific schema files
- `/migrations/migrate_to_postgres.sh` - PostgreSQL migration script

### Database Schema
The system uses a comprehensive PostgreSQL database schema with 102 tables including:
- User management (users, roles, sessions)
- Customer and job management
- Product and device inventory
- Warehouse zones and locations
- Invoice and payment processing
- Audit and compliance logging

## Configuration

### Environment Variables
The system is configured via `.env` file with sections for:
- Database configuration (PostgreSQL)
- Cross-navigation domains for SSO
- MQTT settings for LED control
- Nextcloud WebDAV integration
- Backup retention settings

### Deployment Scenarios
1. **Local Development**: Auto-detection of localhost:8081/8082
2. **Subdomain Setup**: With nginx reverse proxy for production
3. **VPS with Ports**: Direct port access (8081, 8082)
4. **Internal Network**: Private IP-based access

## Docker Services

### Main Services
- `postgres`: PostgreSQL 17 database with health checks
- `rentalcore`: RentalCore application with health checks
- `warehousecore`: WarehouseCore application with health checks
- `mosquitto`: MQTT broker for LED control
- `db-backup`: Automatic backup service

### Network and Volumes
- Custom bridge network: `weidelbach`
- Persistent volumes for data and backups
- LED mapping configuration volume

## Development Conventions

### Code Quality
- Go modules for dependency management
- Structured logging
- GORM for database operations
- JWT for authentication
- RBAC for authorization

### Testing
- Unit tests for critical business logic
- Integration tests for database operations
- API endpoint tests
- PostgreSQL schema validation tests

### Security
- Password requirements (min 8 characters)
- Session management with expiration
- Role-based access control
- Input validation and sanitization

## Current Development Focus

Based on the `CODE_IMPROVEMENT_PLAN.md`, the project is undergoing significant refactoring:

1. **Database Migration**: Migration from MySQL to PostgreSQL is now complete
2. **Test Coverage**: Improving from near-zero to 70%+ coverage
3. **Code Organization**: Extracting shared code and reducing duplication
4. **Security Hardening**: Adding rate limiting and audit logging
5. **Observability**: Adding metrics and structured logging

## Troubleshooting

### Common Issues
1. **Services in restart loop**: Wait 1-2 minutes for PostgreSQL initialization
2. **Cannot login**: Check if existing volumes prevent re-initialization
3. **Database connection**: Verify credentials in `.env` file
4. **Cross-navigation**: Check domain configuration in environment

### Monitoring
```bash
# Check service status
docker compose ps

# View logs
docker compose logs -f

# Health checks
curl http://localhost:8081/health
curl http://localhost:8082/health
```

## Deployment

### Production Setup
For production, use:
- Subdomain setup with nginx reverse proxy
- SSL certificates (Let's Encrypt)
- Proper domain configuration in `.env`
- Strong database passwords
- Regular backups

### Backup Strategy
- Automatic daily database backups
- Manual backup with pg_dump
- Volume-based backup for persistence

## Project Status

- **Current Version**: RentalCore 1.55, WarehouseCore 2.51
- **Database**: PostgreSQL 17
- **Deployment**: Docker Compose
- **Development Status**: Active refactoring to improve code quality
- **Architecture**: Microservices with shared PostgreSQL database

## Future Roadmap

Based on the improvement plan:
1. Increase test coverage to 70%+
2. Refactor large monolithic files
3. Unify web frameworks or extract common abstractions
4. Enhance security features
5. Improve observability with metrics and tracing

## Qwen Added Memories
- ALWAYS BUILD AND PUSH TO DOCKERHUB AND GITLAB AFTER CHANGES
