# Code Improvement Plan: RentalCore & WarehouseCore

**Created:** 12. December 2025  
**Status:** Planning Phase

---

## Executive Summary

This plan addresses technical debt in two Go microservices (RentalCore and WarehouseCore) sharing MySQL and MQTT. The main issues are near-zero test coverage, duplicated logic between services, inconsistent patterns, and code organization problems.

---

## 1. Identified Issues

### 🔴 CRITICAL

| Issue | Location | Description |
|-------|----------|-------------|
| **Near-zero test coverage** | Both services | Only 1-2 test files found per service. Critical business logic is untested. |
| **Hardcoded encryption key in example** | `rentalcore/config.json.example` | Example shows placeholder key but no validation that it's changed in production |
| **Debug statements in production code** | `warehousecore/internal/handlers/` | Multiple `fmt.Println` statements will leak to production logs |

### 🟠 HIGH

| Issue | Location | Description |
|-------|----------|-------------|
| **Inconsistent web frameworks** | RentalCore uses Gin, WarehouseCore uses Gorilla/Mux | Creates inconsistent error handling, middleware, and response patterns |
| **Module naming inconsistency** | `rentalcore/go.mod` | Module named `go-barcode-webapp` but service is `RentalCore` |
| **Duplicated authentication logic** | `rentalcore/internal/handlers/auth_handler.go` vs `warehousecore/internal/handlers/auth.go` | SSO cookie handling duplicated with subtle differences |
| **Duplicated RBAC implementation** | `rentalcore/internal/middleware/rbac.go` vs `warehousecore/internal/middleware/rbac.go` | RBAC logic duplicated instead of shared package |
| **Raw SQL in handlers** | Multiple handler files | Large SQL queries directly in handlers instead of repository layer |
| **No database transaction handling** | Multiple handler files | Critical operations like job creation don't use transactions |

### 🟡 MEDIUM

| Issue | Location | Description |
|-------|----------|-------------|
| **Global singletons** | `database.go`, `repository/database.go` | `db` and `mqttClient` as package globals make testing difficult |
| **Unused root internal folder** | `/opt/dev/cores/internal` | Empty root internal folder should have shared validators per AGENTS.md |
| **Configuration inconsistency** | Both services | RentalCore uses JSON config file, WarehouseCore uses env vars only |
| **Migration numbering gaps** | `rentalcore/migrations` | Missing migration 004, duplicate 013 and 021 prefixes |
| **Cache invalidation weakness** | `rentalcore/internal/cache/` | Simple time-based cache with no invalidation on data changes |
| **Large monolithic main.go** | `rentalcore/cmd/server/main.go` (~1784 lines) | Main function has repeated URL-building functions, template functions, route setup |
| **Large handlers file** | `warehousecore/internal/handlers/handlers.go` (~3126 lines) | Single file with all handlers instead of domain-specific files |

### 🟢 LOW

| Issue | Location | Description |
|-------|----------|-------------|
| **Inconsistent pointer usage** | Model definitions | RentalCore uses `sql.NullString`, WarehouseCore uses `*string` |
| **Magic numbers** | Various files | Session timeout, bcrypt cost, cache TTL not configurable |
| **Duplicate URL building functions** | `rentalcore/cmd/server/main.go` | 5 nearly identical `buildWarehouse*URL` functions |
| **Go version mismatch** | go.mod files | RentalCore `go 1.24.1`, WarehouseCore `go 1.24.0` |

---

## 2. Code Smells & Anti-patterns

### Duplication
- **Cookie domain handling**: Implemented in both services with slight differences
- **RBAC checking**: Nearly identical role-checking logic in both services' middleware
- **Response helpers**: Inconsistent error response patterns between services

### Tight Coupling
- Handler functions directly access `db` and `mqttClient` globals instead of dependency injection
- Template functions in main.go directly query database

### Missing Abstractions
- No interface definitions for repositories - hard to mock for testing
- No service layer in WarehouseCore - handlers call repositories directly
- No shared DTO/API response types between services

### Long Functions
| File | Function | Lines |
|------|----------|-------|
| `rentalcore/internal/handlers/job_handler.go` | `UpdateJob` | ~200+ lines |
| `warehousecore/internal/handlers/handlers.go` | `ListDevices` | ~150 lines |
| `rentalcore/cmd/server/main.go` | `main` | 80+ lines |

---

## 3. Missing or Weak Areas

### Testing (CRITICAL GAP)
- **RentalCore**: 1 test file with 5 unit tests for product selection parsing
- **WarehouseCore**: 1 test file with 3 unit tests for LED validation
- **Missing entirely**:
  - Integration tests
  - API endpoint tests
  - Repository tests
  - Service layer tests
  - Authentication flow tests
  - Database migration tests

### Documentation
- README files exist and are well-maintained
- **Missing**: 
  - API documentation doesn't cover all endpoints
  - No godoc comments on exported functions
  - No architecture decision records (ADRs)

### Error Handling
- Errors often logged but not properly propagated
- Generic "Internal server error" messages without correlation IDs
- No consistent error type hierarchy

### Observability
- RentalCore has structured logging but WarehouseCore uses standard log
- No metrics/prometheus endpoints visible
- No distributed tracing

### Security
- Password requirements only checked in some places (`min=8`)
- No rate limiting on login endpoints
- No audit logging for admin actions
- Session tokens not rotated on privilege escalation

---

## 4. Improvement Plan

### Phase 1: Immediate Actions (Week 1-2)

#### 1.1 Remove debug statements
- [ ] Search and remove all `fmt.Println` from production code in WarehouseCore
- [ ] Replace with proper structured logging

#### 1.2 Extract shared code
- [ ] Create `/opt/dev/cores/internal/shared/` package with:
  - `cookie.go` - SSO cookie domain handling
  - `session.go` - Session validation
  - `rbac.go` - RBAC checking middleware helpers
  - `response.go` - Standard API response helpers

#### 1.3 Fix module naming
- [ ] Rename RentalCore module from `go-barcode-webapp` to `rentalcore`
- [ ] Update all imports accordingly

### Phase 2: Short-term (Month 1)

#### 2.1 Add critical test coverage
- [ ] Create `rentalcore/internal/handlers/auth_handler_test.go` - Authentication tests
- [ ] Create `rentalcore/internal/handlers/job_handler_test.go` - Job CRUD tests
- [ ] Create `warehousecore/internal/handlers/handlers_test.go` - Device/Product tests
- [ ] Target: 40% coverage on critical paths

#### 2.2 Refactor large handler files
- [ ] Split `warehousecore/internal/handlers/handlers.go` into:
  - `device_handler.go`
  - `product_handler.go`
  - `location_handler.go`
  - `label_handler.go`
  - `auth_handler.go`

#### 2.3 Standardize configuration
- [ ] Create shared config validation package
- [ ] Move RentalCore to environment-variable-based config
- [ ] Add startup validation for required config values

#### 2.4 Fix migration numbering
- [ ] Audit all migrations in both services
- [ ] Renumber to remove gaps (missing 004)
- [ ] Resolve duplicate prefixes (013, 021)

### Phase 3: Medium-term (Quarter 1)

#### 3.1 Introduce repository interfaces
- [ ] Define interfaces for all repository types
- [ ] Implement constructor-based dependency injection
- [ ] Remove global `db` singletons

#### 3.2 Add service layer to WarehouseCore
- [ ] Create `internal/services/` package
- [ ] Move business logic from handlers to services
- [ ] Handlers become thin request/response adapters

#### 3.3 Unify GORM versions
- [ ] Upgrade RentalCore GORM from 1.25.4 to 1.31.0
- [ ] Test for breaking changes
- [ ] Update any deprecated API usage

#### 3.4 Add observability
- [ ] Add Prometheus metrics endpoint (`/metrics`)
- [ ] Implement structured logging in WarehouseCore
- [ ] Add request correlation IDs

### Phase 4: Long-term (Quarter 2)

#### 4.1 Comprehensive testing
- [ ] Target 70%+ code coverage
- [ ] Add integration tests with test database
- [ ] Add API contract tests between services

#### 4.2 Security hardening
- [ ] Implement rate limiting on authentication endpoints
- [ ] Add audit logging for admin actions
- [ ] Implement session rotation on privilege changes

#### 4.3 Web framework decision
- [ ] Evaluate: Migrate WarehouseCore to Gin OR extract common HTTP abstractions
- [ ] Implement chosen approach
- [ ] Align middleware patterns

---

## 5. Dependency Analysis

### Current State
| Package | RentalCore | WarehouseCore | Action |
|---------|------------|---------------|--------|
| Gin | v1.9.1 | - | Keep |
| Gorilla/Mux | - | v1.8.1 | Evaluate |
| GORM | v1.25.4 | v1.31.0 | Align to 1.31.0 |
| golang.org/x/crypto | v0.40.0 | Current | Keep |
| Go Version | 1.24.1 | 1.24.0 | Align to 1.24.1 |

---

## 6. Success Metrics

| Metric | Current | Target (Q1) | Target (Q2) |
|--------|---------|-------------|-------------|
| Test Coverage | ~1% | 40% | 70% |
| Duplicated Code | High | Medium | Low |
| Handler File Size | 3000+ LOC | <500 LOC each | <500 LOC each |
| Critical Issues | 3 | 0 | 0 |
| High Issues | 6 | 2 | 0 |

---

## 7. Open Questions

1. **Web framework unification?** 
   - Option A: Migrate WarehouseCore to Gin for consistency
   - Option B: Keep separate but align middleware patterns
   - Option C: Extract common HTTP abstractions
   - **Decision needed by:** End of Phase 2

2. **Shared code location?**
   - Option A: `/opt/dev/cores/internal/shared/` (monorepo style)
   - Option B: Separate `github.com/company/cores-common` module
   - **Recommendation:** Option A for simplicity

3. **Test database strategy?**
   - Option A: SQLite for unit tests, MySQL for integration
   - Option B: Testcontainers with MySQL
   - Option C: Shared test MySQL instance
   - **Decision needed by:** Start of Phase 2

---

## Notes

- Prioritize changes that improve developer productivity and reduce bugs
- Each phase should be deployable independently
- Coordinate changes between services to avoid breaking inter-service communication
- Update AGENTS.md and README files as architecture evolves
