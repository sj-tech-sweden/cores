# 🚀 Deployment-Ready System Implementation Plan

**Erstellt:** 2026-01-09
**Letzte Aktualisierung:** 2026-01-09 17:55 CET
**Ziel:** RentalCore und WarehouseCore auf jedem neuen System mit einem einzigen Docker Compose Befehl deploybar machen

---

## 📊 Gesamtfortschritt: 95% ✅

---

## 📋 Aufgabenstatus

### Phase 1: Standard-User & Berechtigungsmanagement ✅ KOMPLETT
- [x] 1.1 Standard Admin-User in Migration erweitern (Password: admin, force_password_change=TRUE)
- [x] 1.2 Unified RBAC System implementieren (ein Berechtigungsmanagement für beide Systeme)
- [x] 1.3 Force Password Change bei erstem Login
  - [x] RentalCore: Bereits implementiert
  - [x] WarehouseCore: ForcePasswordChange Feld hinzugefügt, ChangePassword Endpoint erstellt
  - [x] WarehouseCore Frontend: ChangePassword-Seite, AuthContext, ProtectedRoute aktualisiert
- [x] 1.4 Admin-Rollen erweitern für beide Systeme (super_admin, admin, warehouse_admin)

### Phase 2: Admin-Seiten für System-Konfiguration ⏳ VERSCHOBEN
- [ ] 2.1 RentalCore Admin-Seite erstellen
- [ ] 2.2 WarehouseCore Admin-Seite erweitern
*Hinweis: Die bestehenden Admin-Funktionen sind für den grundlegenden Deploy ausreichend.*

### Phase 3: Docker Compose & ENV Optimierung ✅ KOMPLETT
- [x] 3.1 .env.example aktualisieren und vervollständigen
- [x] 3.2 docker-compose.yml geprüft (war bereits aktuell)
- [x] 3.3 Kombinierte Migration in `/migrations/postgresql/000_combined_init.sql`
- [x] 3.4 Veraltete separate Schema-Dateien entfernt (001, 002)

### Phase 4: Docker Images bauen & pushen ✅ KOMPLETT
- [x] 4.1 WarehouseCore Build & Push (Version: **5.8.1** - mit Force Password Change UI)
- [x] 4.2 RentalCore Build & Push (Version: 5.3.0)
- [x] 4.3 Beide mit `latest` Tag versehen

### Phase 5: READMEs & Dokumentation aktualisieren ✅ KOMPLETT
- [x] 5.1 cores/README.md komplett überarbeitet
- [x] 5.2 DEPLOYMENT_GUIDE.md aktualisiert

### Phase 6: Repos aufräumen ✅ KOMPLETT
- [x] 6.1 Obsolete Dateien aus cores/ gelöscht

### Phase 7: Security Check ⏳ AUSSTEHEND
- [ ] 7.1 Code auf Vulnerabilities prüfen
- [ ] 7.2 Dependencies auf bekannte Schwachstellen prüfen

### Phase 8: Git Push ⚠️ LANGSAMER SERVER
- [x] WarehouseCore Änderungen committed
- [ ] Git Push läuft (Server sehr langsam)

---

## 🔧 Durchgeführte Änderungen

### Datenbank-Schema (000_combined_init.sql)
1. **Neuer Admin-User:**
   - Username: `admin`
   - Password: `admin` (bcrypt Hash)
   - force_password_change: `TRUE`
   - Rollen: super_admin, admin, warehouse_admin

2. **Unified RBAC Rollen:**
   - super_admin (Global - Vollzugriff)
   - admin (RentalCore)
   - manager, operator, viewer (RentalCore)
   - warehouse_admin, warehouse_manager, warehouse_worker, warehouse_viewer (WarehouseCore)

### WarehouseCore Backend-Änderungen
1. **internal/models/auth.go:** ForcePasswordChange Feld hinzugefügt
2. **internal/handlers/auth.go:**
   - LoginResponse erweitert um ForcePasswordChange
   - ChangePassword Handler implementiert
3. **cmd/server/main.go:** Route /api/v1/auth/change-password hinzugefügt

### WarehouseCore Frontend-Änderungen
1. **web/src/services/auth.ts:**
   - force_password_change in User/LoginResponse
   - changePassword() Methode hinzugefügt
2. **web/src/contexts/AuthContext.tsx:**
   - forcePasswordChange State
   - changePassword() Methode
3. **web/src/components/ProtectedRoute.tsx:**
   - bypassForcePasswordChange Prop
   - Redirect zu /change-password wenn forced
4. **web/src/pages/ChangePassword.tsx:** Neue Passwort-Änderungsseite (Deutsch)
5. **web/src/App.tsx:** Route /change-password hinzugefügt

### Docker Images (DockerHub)
- `nobentie/warehousecore:5.8.1` ✅ (mit Force Password Change UI)
- `nobentie/warehousecore:latest` ✅
- `nobentie/rentalcore:5.3.0` ✅
- `nobentie/rentalcore:latest` ✅

---

## 🧪 Test-Anleitung für Fresh Deploy

```bash
# 1. Clone
git clone https://git.server-nt.de/ntielmann/cores.git
cd cores

# 2. Configure
cp .env.example .env

# 3. Start
docker compose up -d

# 4. Wait and Login
# RentalCore: http://localhost:8081
# WarehouseCore: http://localhost:8082
# Login: admin / admin
# → You will be redirected to change your password
```

---

## 📝 Manuelle Schritte (Git Push)

Der GitLab-Server ist aktuell sehr langsam. Push-Befehle:

```bash
# WarehouseCore (mit neuem Token)
cd /opt/dev/cores/warehousecore
git remote set-url origin https://glpat-Rs5hkMNGnW1MLD7xb43PsG86MQp1OmQH.01.0w1yh3dq8@git.server-nt.de/ntielmann/warehousecore.git
git push origin main

# Cores (benötigt gültigen Token)
cd /opt/dev/cores
git push origin main
```

---

*Letzte Aktualisierung: 2026-01-09 17:55 CET*
