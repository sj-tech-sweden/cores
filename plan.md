# RentalCore → WarehouseCore Feature Migration Plan

## Kontext

RentalCore (Go 1.23) enthält aktuell sowohl Jobmanagement als auch zahlreiche Lager-/Produktfunktionen. Ziel ist eine Trennung:

- **RentalCore**: reines Job-/Kundenverwaltungssystem. Keine Produkt-, Gerät-, Kabel-, Case-, Scanner- oder Warehouse-spezifischen Funktionen mehr.
- **WarehouseCore**: komplette Lagerverwaltung inklusive Produkt-/Geräteanlage, Kabel-/Case-Management, Scanner-Workflows etc.

Beide Services nutzen dieselbe MySQL-Datenbank. Migration erfolgt funktionsweise: Logik, UI, Routen, Tests und Dokumentation müssen aus RentalCore entfernt bzw. deaktiviert und in WarehouseCore ergänzt/übernommen werden.

Wichtige Artefakte:

- `rentalcore/cmd/server/main.go`: Routenregistrierung
- `rentalcore/internal/handlers/*`: Handler (z.B. `product_handler.go`, `device_handler.go`, `cable_handler.go`, `case_handler.go`, `scanner_handler.go`)
- `rentalcore/internal/repository/*`: Repositories für DB-Zugriff
- `rentalcore/web/templates/*`: HTML-Templates
- `rentalcore/web/static/js/css`: Scripts/Styles für UI
- `warehousecore/web/src/*`: React-Frontend (Admin-Module)
- `warehousecore/internal/...`: API-/Service-Layer

## Vorgeschlagene Migrationsphasen

> Jede Phase enthält Analyse, Implementierung (WarehouseCore), Entfernung/Deaktivierung (RentalCore), Tests, Dokumentation, Docker-Release.

### Phase 1 – Produkverwaltung
- [ ] **Analyse RentalCore**
  - [ ] Verzeichnisstruktur (Templates: `products_standalone.html`, JS, Handler/Repo).
  - [ ] API-Endpunkte (`/products`, `/api/v1/products` etc.), RBAC.
  - [ ] Verweise (z.B. Navbar, Job-Formulare).
- [ ] **WarehouseCore Implementierung**
  - [ ] Produkt-Tab/Frontend erweitern (ggf. Layout/UX an RentalCore angleichen).
  - [ ] Backend-API anpassen (POST/PUT/DELETE Produkte, Dropdown-Daten etc.).
  - [ ] Tests aktualisieren/ergänzen.
- [ ] **RentalCore deaktivieren**
  - [ ] Entferne /products-Routen + Templates.
  - [ ] Entferne entsprechende Handler/Repository-Aufrufe.
  - [ ] Verweise in UI (Navbar/Job-Form etc.) entfernen bzw. WarehouseCore-Link.
  - [ ] Tests & Dokumentation anpassen.
- [ ] **Verifikation**
  - [ ] Go-Tests (beide Services).
  - [ ] Frontend-Build WarehouseCore (`npm run build`).
  - [ ] Docker Builds + Push.
  - [ ] README/Docs aktualisieren.

### Phase 2 – Geräteverwaltung
- [ ] Ähnlicher Ablauf wie Phase 1 (Analyse → Migration → Deaktivierung → Tests).
- [ ] Berücksichtige Geräte-spezifische APIs (Bulk-Erstellung, QR-Codes etc.).
- [ ] UI: WarehouseCore Admin-Module für Geräte erweitern.

### Phase 3 – Scanner/Barcode Workflows
- [ ] Identifiziere `scanner_handler.go`, `web/templates/scan_*`, WASM-Decoder etc.
- [ ] Prüfe, wie WarehouseCore die Scanner-Funktion nutzen soll (z.B. vorhandenes React UI?).
- [ ] Migriere APIs + Frontend, deaktiviere RentalCore Routen.

### Phase 4 – Kabel-Management
- [ ] Handler/Routes (z.B. `/cables`), Templates, Services.
- [ ] WarehouseCore Module erstellen (Admin UI + API).
- [ ] Entferne aus RentalCore.

### Phase 5 – Case-Management
- [ ] Handler/Routes (z.B. `/cases`), Templates.
- [ ] WarehouseCore UI + API.
- [ ] Entferne aus RentalCore.

### Phase 6 – Sonstige Warehouse-Funktionalität
- [ ] Prüfen, ob weitere Warehouse-Funktionalitäten existieren (Bestände, Monitoring, LED etc).
- [ ] Konsolidieren in WarehouseCore.

## Querschnittsaufgaben

- **RBAC/Permissions:** Rollen anpassen (RentalCore soll keine „warehouse“ Berechtigungen mehr haben; WarehouseCore Admin muss neue Features sehen).
- **Dokumentation:** README, Deployment-Anleitungen, Makefiles, Docker Compose.
- **Navigation:** Cross-Link (RentalCore → WarehouseCore) klar ersichtlich (z.B. Buttons statt eigenem Management).
- **Tests:** Jede Phase erfordert Go-Tests & ggf. Integrationstests. WarehouseCore Frontend-Build muss laufen.
- **Docker:** Nach jeder Phase neue Images (z.B. `nobentie/rentalcore:<version>`, `nobentie/warehousecore:<version>`).
- **Monitoring/Logging:** Anpassung falls nötig (z.B. tags, Prometheus).

## Aktueller Stand (Chronologisch)

### ✅ Vorarbeiten
- [x] Branding-Divergenzen aus RentalCore entfernt, Header zeigt dynamischen Firmennamen (`company_provider`).
- [x] Manager dürfen Passwörter zurücksetzen; Force Password Change aktiv.
- [x] RentalCore: Produktmodal fixiert (zentriert, Scroll-Lock), Docker Push `nobentie/rentalcore:1.6`.
- [x] WarehouseCore: Produktmodal aktualisiert, Scroll-Lock, Docker Push `nobentie/warehousecore:1.6`.
- [x] Code auf `main` → GitLab, Docker Hub aktualisiert.

### ⏳ Phase 1 – Produkverwaltung (noch nicht gestartet)
- [ ] (Analyse) Funktionsumfang aufnehmen.
- [ ] (WarehouseCore) Anforderungsabgleich / Implementierung.
- [ ] (RentalCore) Deaktivieren.
- [ ] (Tests/Docker) Ausstehend.

### ⏳ Weitere Phasen
- [ ] Geräteverwaltung
- [ ] Scanner/Barcode
- [ ] Kabelmanagement
- [ ] Case-Management
- [ ] Restliche Warehouse-Funktionen

## Nächste Schritte

1. **Analyse Phase 1:** Detaillierte Auflistung aller Produkt-bezogenen Ressourcen in RentalCore.  
2. **Design Entscheidung:** WarehouseCore UI/UX für Produktanlage vereinheitlichen (falls abweichend).  
3. **Implementierung WarehouseCore:** API + Frontend.  
4. **RentalCore deaktivieren:** Routen, Handler, Templates entfernen.  
5. **Tests + Docker**: Go-Tests, `npm run build`, Docker build/push.  
6. **Plan.md aktualisieren:** Fortschritt mit Kontext/Verweis auf Commits & Images dokumentieren.  
7. **Phase 2 vorbereiten** (Geräteverwaltung).

> Bei jedem Schritt Plan aktualisieren, damit andere Agenten sofort sehen, wo wir stehen (Commits, Images, offene Punkte).

