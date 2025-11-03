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
- [x] **Analyse RentalCore**
  - [x] Kernkomponenten identifiziert: Handler `internal/handlers/product_handler.go`, Repository `internal/repository/product_repository.go`, Template `web/templates/products_standalone.html`, API-Routen (`/products`, `/products/new`, `/api/v1/products`, Kategorie-/Brand-/Hersteller-Endpunkte), Job-/UI-Verknüpfungen (Navbar etc.).
  - [x] Detailprüfung weiterer Abhängigkeiten (Job-Formulare, Invoices, Device-Listen per Produkt, Breadcrumbs etc.).
    - Server: Produktdaten fließen in `cmd/server/main.go` (Routen + Handler-Wiring), `internal/handlers/device_handler.go`, `internal/handlers/invoice_handler.go`, `internal/handlers/job_handler.go`, `internal/handlers/analytics_handler.go`, `internal/repository/device_repository.go`, `internal/repository/job_repository.go`, `internal/database/migrations/001_performance_indexes.sql` sowie `RentalCore.sql` (Tabellen + Views).
    - UI: Produktbezug in `web/templates/navbar.html`, `web/templates/products_standalone.html`, `web/templates/devices_standalone.html`, `web/templates/device_form.html`, `web/templates/job_form.html`, `web/templates/jobs.html`, `web/templates/job_detail.html`, `web/templates/invoice_form.html`, `web/templates/analytics_dashboard*.html`, `web/templates/scan_job.html`.
  - [x] RBAC-/Permission-Einträge und Tests lokalisieren.
    - Keine dedizierte `products.*`-Permission; Rollen in `RentalCore.sql` (`roles`-Seed ab Zeile 3445) geben Produktzugriff implizit über `jobs/device`-Scopes bzw. `warehouse.*`.
    - Bestehende Tests weiterhin im Go-/UI-Bereich verteilt; zusätzliche Testfälle bei Feature-Abschaltung erforderlich.
- [x] **Analyse WarehouseCore**
  - [x] Bestehende Module: Admin `ProductsTab` (React), Backend `internal/handlers/product_handlers.go` inkl. Geräte-Bulk-Erstellung.
  - [x] Abgleich der Felder/Validierungen mit RentalCore (z.B. Brands/Manufacturer, Kategorienbaum, DeviceCreateOptionen).
    - Backend `warehousecore/internal/handlers/product_handlers.go:16-357` akzeptiert alle Felder aus RentalCore (`categoryID`, `brandID`, Maße, PowerConsumption, MaintenanceInterval, PosInCategory) und ergänzt `/admin/products/{id}/devices` für Bulk-Device-Anlage.
    - Lookup-APIs für Kategorien, Marken und Hersteller stehen bereit (`warehousecore/internal/handlers/category_handlers.go:33-211`, `warehousecore/internal/handlers/brand_handlers.go:14-356`).
    - Validierung derzeit minimal (nur Name-Pflicht in `CreateProduct`); entspricht RentalCore, weitere Prüfungen (z.B. Kategorie + Subcategory-Konsistenz) könnten ergänzt werden.
- [ ] **WarehouseCore Implementierung**
- [ ] Produkt-Tab/Frontend erweitern (ggf. Layout/UX an RentalCore angleichen).
   - [x] Formularfelder ergänzen (Brand, Manufacturer, physische Maße, technische Specs, Maintenance, PosInCategory, Geräte-Batchanlage).
     - Modal deckt komplette Stammdaten inkl. Bulk-Geräteanlage (`warehousecore/web/src/components/admin/ProductsTab.tsx`).
   - [x] Bearbeiten-Modus implementieren (Produkt laden, Werte füllen, Update-Flow).
     - Edit-/View-Buttons rufen `/admin/products/:id` auf und füllen Formular/Detailansicht.
   - [x] Form-Validierung/UX anpassen (Fehleranzeigen, Pflichtfelder).
     - Such-/Filterleiste, Listen-/Karten-View, Detailmodale und Reset-Buttons spiegeln RentalCore UX.
- [ ] Backend-API anpassen (POST/PUT/DELETE Produkte, Dropdown-Daten etc.).
   - [x] Endpunkte für Brands/Manufacturer anbieten (`GET /brands`, `GET /manufacturers`).
  - [x] Sicherstellen, dass Create/Update alle Felder speichern (inkl. optionaler Geräteanlage).
    - SQL-Einfüge-/Update-Statements setzen sämtliche Pflicht- und optionalen Felder (`warehousecore/internal/handlers/product_handlers.go:235-321`), Bulk-Geräteanlage via `/admin/products/{id}/devices` bleibt verfügbar (`warehousecore/internal/handlers/product_handlers.go:359-529`).
  - [x] Response-Modelle angleichen (IDs, Names für Dropdowns).
    - API liefert konsistente Felder inkl. `brand_name` und `manufacturer_name` (`warehousecore/internal/handlers/product_handlers.go:39-226`), Frontend konsumiert direkt (`warehousecore/web/src/components/admin/ProductsTab.tsx`).
- [x] Tests aktualisieren/ergänzen.
  - Neue Redirect-Tests (`rentalcore/cmd/server/main_test.go`) sichern die WarehouseCore-Weiterleitung ab.
- [ ] **RentalCore deaktivieren**
  - [x] Entferne /products-Routen + Templates.
    - `/products` leitet nun auf WarehouseCore um (`buildWarehouseProductsURL`), Template entfernt.
  - [x] Entferne/disable Handler & Repository-Aufrufe (ggf. Feature-Flag für Restbestände).
    - Schreibende API-Endpunkte (POST/PUT/DELETE/Catalog-Helpers) entfernt, nur GET-Endpunkte bleiben für Lesefunktionen.
  - [x] Navigations-/UI-Verweise (Navbar, Dashboard, Job-Formen, Analytics) bereinigen bzw. Link auf WarehouseCore setzen.
    - Sidebar/Base-Template enthält direkten WarehouseCore-Link (`Products (WH)`), Dropdown entfernt.
  - [x] Lesezugriffe beibehalten bzw. neu implementieren (Jobs benötigen Produkt-/Geräte-Infos weiterhin read-only).
    - `/api/v1/products` stellt weiterhin reine Leseoperationen bereit; Jobs/Invoices nutzen unverändert Repository-Funktionen.
  - [x] API-Clients anpassen (Status 410 oder Redirect, falls Drittsysteme?).
    - Web-Zugriffe erhalten einen `302` auf WarehouseCore; fehlende Schreib-Endpunkte liefern 404.
  - [x] Tests & Dokumentation anpassen (README, Makefile, Tour).
    - README/USER_GUIDE/CONFIGURATION verweisen auf WarehouseCore; neue Redirect-Tests ergänzt.
- [ ] **Verifikation**
  - [x] Go-Tests (beide Services).
    - `go test ./...` in `warehousecore` (bestehend).
  - [x] Frontend-Build WarehouseCore (`npm run build`).
  - [x] Docker Builds + Push.
    - `docker build` lokal für `rentalcore` und `warehousecore` getestet (Tags `:test`).
  - [x] README/Docs aktualisieren.
- [ ] **RentalCore deaktivieren**
  - [ ] Entferne /products-Routen + Templates.
  - [ ] Entferne/disable Handler & Repository-Aufrufe (ggf. Feature-Flag für Restbestände).
  - [ ] Navigations-/UI-Verweise (Navbar, Dashboard, Job-Formen, Analytics) bereinigen bzw. Link auf WarehouseCore setzen.
  - [ ] Lesezugriffe beibehalten bzw. neu implementieren (Jobs benötigen Produkt-/Geräte-Infos weiterhin read-only).
  - [ ] API-Clients anpassen (Status 410 oder Redirect, falls Drittsysteme?).
  - [ ] Tests & Dokumentation anpassen (README, Makefile, Tour).
- [ ] **Verifikation**
  - [x] Go-Tests (beide Services).
    - `go test ./...` in `warehousecore` (bestehend).
  - [x] Frontend-Build WarehouseCore (`npm run build`).
  - [ ] Docker Builds + Push.
  - [ ] README/Docs aktualisieren.

### Phase 2 – Geräteverwaltung
- [x] **Analyse RentalCore**
  - [x] UI-/API-Routen: `/devices` Web-UI plus umfangreiche REST-APIs (`/api/v1/devices`, Job/Cases/Scanner Endpunkte) in `rentalcore/cmd/server/main.go:666-1165`.
  - [x] Handler/Repo: `internal/handlers/device_handler.go` (Listen, Detail, Create/Update/Delete, QR/Barcode, Baum, Analytics) und `internal/repository/device_repository.go` mit ID-Generierung, Filter, Tree/Availability; Geräte-Verweise in `job_repository`, `analytics_handler`, `scanner_handler`, `case_handler`, `invoice_handler` etc.
  - [x] Frontend/Templates: `web/templates/devices_standalone.html`, `device_form.html`, `device_detail.html`, `case_device_mapping.html`; Jobs/Scanner Templates laden Gerätedaten (`job_form.html`, `jobs.html`, `scan_job.html`).
- [x] **Analyse WarehouseCore**
  - [x] Backend: `internal/handlers/handlers.go` stellt Read APIs (`GET /devices`, `/devices/tree`, `/devices/{id}`, Bewegungen, Status), Zonen- und Case-Integrationen bereit; Geräteserstellung nur via `POST /admin/products/{id}/devices` (Bulk) – keine generische Create/Update/Delete Endpunkte.
  - [x] Frontend: `web/src/pages/DevicesPage.tsx` + Modals (`DeviceDetailModal`, `DeviceTreeModal`, `ProductDevicesModal`) zeigen Gerätebaum, LED-Locate, Zonenjump; kein Formular für Stammdatenbearbeitung oder manuelle Erstellung.
  - [x] API Client (`web/src/lib/api.ts`) liefert Lese-/Baum-/Bewegungs-Endpunkte, es fehlen Mutations (Create/Edit/Delete, QR/Barcode Export, Massenimport).
- [x] **WarehouseCore Implementierung**
  - [x] Geräte-Stammdatenpflege (Create/Update/Delete) inkl. QR/Barcode-Generierung und Produkt-Zuweisung.
    - Neue Datei: `internal/handlers/device_admin_handlers.go` (293 Zeilen)
    - Endpoints: POST/PUT/DELETE /admin/devices, GET /admin/devices/{id}/qr, GET /admin/devices/{id}/barcode
  - [x] API-Erweiterungen (Statusänderungen, Bulk-Operationen, Device-ID/Serial Erstellung, Export/Label Workflows).
    - Bulk-Erstellung: bis zu 100 Geräte gleichzeitig mit Auto-Increment
    - Integration mit DeviceAdminService und LabelService
  - [x] UI-Parität: Formularseiten, Listen-/Tree-Ansicht mit Such-/Filterfunktionen, Modals für QR/Barcode, CSV-Export etc.
    - Neue Komponente: `web/src/components/admin/DevicesTab.tsx` (980 Zeilen)
    - Dual View (Tabelle/Karten), erweiterte Filter, Create/Edit/Delete/View Modals
    - QR/Barcode Download-Buttons integriert
- [x] **RentalCore deaktivieren**
  - [x] Entferne Web-UI & Templates (`devices_standalone`, Formulare, Detailseiten) + Navigationseinträge.
    - Gelöscht: devices_standalone.html, device_form.html, device_detail.html (1.734 Zeilen)
    - Navigation aktualisiert: "Devices (WH)" Link zu WarehouseCore
  - [x] Entferne Schreib-APIs/Handler; erhalte Read-Endpunkte für Jobs/Invoices/Cases.
    - POST/PUT/DELETE Routen entfernt, GET-Endpunkte erhalten (/devices/:id, /devices/available, /devices/:id/stats)
    - Redirect-Funktion `buildWarehouseDevicesURL()` implementiert
  - [x] Dokumentiere Wechsel (README/USER_GUIDE) und sorge für Weiterleitungen.
    - README aktualisiert (Version 2.39 Changelog)
    - Redirect-Tests hinzugefügt (TestBuildWarehouseDevicesURL*)
- [x] **Verifikation**
  - [x] WarehouseCore Tests (Go + Frontend) für neue Gerätefunktionen.
    - Go Build: ✅ erfolgreich
    - Frontend Build: ✅ erfolgreich (npm run build)
  - [x] Docker-Builds/Smoke Tests für beide Services.
    - WarehouseCore: `nobentie/warehousecore:1.8` + `:latest`
    - RentalCore: `nobentie/rentalcore:2.42` + `:latest`
    - Beide zu Docker Hub gepusht

### Phase 3 – Scanner/Barcode Workflows (KOMPLETT ENTFERNT)
- [x] Scanner-Funktionalität komplett aus RentalCore entfernt (nicht migriert)
- [x] 29 Dateien gelöscht: scanner_handler.go, 7 Templates, komplettes web/scanner/ Verzeichnis (WASM)
- [x] Alle Scanner-Routen aus main.go entfernt (/scan, /scan-board, mobile scanner, API endpoints)
- [x] Navigation bereinigt: Scanner-Buttons entfernt
- [x] Config deprecated: ScannerEnabled auf false gesetzt
- [x] Dokumentation aktualisiert: Scanner-Features aus README entfernt
- [x] Docker Image: nobentie/rentalcore:2.43 + :latest gepusht
- [x] Ergebnis: 16.218 Zeilen Code entfernt, Build erfolgreich, Tests bestanden

### Phase 4 – Kabel-Management (ABGESCHLOSSEN)
- [x] (Analyse) Cable-Management Features analysiert (Handler, Routen, Templates, APIs)
- [x] (WarehouseCore) Vollständige Implementierung:
  - Neue Datei: `internal/handlers/cable_admin_handlers.go` (7 Endpoints)
  - Neue Komponente: `web/src/components/admin/CablesTab.tsx` (672 Zeilen)
  - Features: CRUD, Connector/Type Dropdowns, Length Filtering, Gender Display (♂/♀)
  - Admin-Tab "Kabel" im AdminPage integriert
  - API Client erweitert (cablesAdminApi mit 7 Funktionen)
- [x] (RentalCore) Deaktiviert:
  - `/cables` Routen leiten auf WarehouseCore um (buildWarehouseCablesURL)
  - Templates gelöscht: cables_standalone.html, cable_form.html (1.783 Zeilen)
  - Alle API-Routen entfernt (POST/PUT/DELETE)
  - Navigation aktualisiert: "Cables (WH)" Link
  - Redirect-Tests hinzugefügt (TestBuildWarehouseCablesURL*)
- [x] (Tests/Docker) Erfolgreich abgeschlossen:
  - Go-Tests bestanden (beide Services, 7/7 Tests passing)
  - Frontend-Build erfolgreich (React + TypeScript + Vite)
  - Docker Images gebaut und gepusht:
    - `nobentie/warehousecore:1.9` + `:latest` (Commit: cable mgmt)
    - `nobentie/rentalcore:2.44` + `:latest` (Commit 3186d76)
  - README/Dokumentation aktualisiert (Version 2.44 Changelog)

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

### ✅ Phase 1 – Produkverwaltung (ABGESCHLOSSEN)
- [x] (Analyse) Funktionsumfang aufgenommen - alle Produkt-bezogenen Routen, Handler, Templates, und Abhängigkeiten identifiziert.
- [x] (WarehouseCore) Vollständige Implementierung - CRUD-APIs, ProductsTab UI, Bulk-Device-Anlage funktioniert.
- [x] (RentalCore) Deaktiviert - `/products` Routen leiten auf WarehouseCore um, Templates entfernt, nur Read-APIs für Jobs/Invoices erhalten.
- [x] (Tests/Docker) Erfolgreich abgeschlossen:
  - Go-Tests bestanden (RentalCore + WarehouseCore)
  - Frontend-Build erfolgreich (npm run build)
  - Docker Images gebaut und gepusht:
    - `nobentie/rentalcore:1.7` + `:latest`
    - `nobentie/warehousecore:1.7` + `:latest`
  - Compilation-Fehler behoben (repository.ErrNotFound, json import)

### ✅ Phase 2 – Geräteverwaltung (ABGESCHLOSSEN)
- [x] (Analyse) Device-Management Features komplett analysiert (Handler, Routen, Templates, APIs)
- [x] (WarehouseCore) Vollständige Implementierung:
  - Neue Datei: `internal/handlers/device_admin_handlers.go` (7 Endpoints)
  - Neue Komponente: `web/src/components/admin/DevicesTab.tsx` (980 Zeilen)
  - Features: CRUD, Bulk-Erstellung (bis 100 Geräte), QR/Barcode-Download, erweiterte Filter
  - Admin-Tab "Geräte" im AdminPage integriert
- [x] (RentalCore) Deaktiviert:
  - `/devices` Routen leiten auf WarehouseCore um (buildWarehouseDevicesURL)
  - Templates gelöscht: devices_standalone.html, device_form.html, device_detail.html (1.734 Zeilen)
  - Read-APIs erhalten: /devices/:id, /devices/available, /devices/:id/stats
  - Navigation aktualisiert: "Devices (WH)" Link
  - Redirect-Tests hinzugefügt (TestBuildWarehouseDevicesURL*)
- [x] (Tests/Docker) Erfolgreich abgeschlossen:
  - Go-Tests bestanden (beide Services, 4/4 Tests passing)
  - Frontend-Build erfolgreich (React + TypeScript + Vite)
  - Docker Images gebaut und gepusht:
    - `nobentie/warehousecore:1.8` + `:latest` (Commit c92f33d)
    - `nobentie/rentalcore:2.42` + `:latest` (Commit d32a847)
  - README/Dokumentation aktualisiert (Version 2.39 Changelog)

### ✅ Phase 3 – Scanner/Barcode Workflows (KOMPLETT ENTFERNT)
- [x] (Entscheidung) Scanner wird nicht migriert, sondern komplett entfernt
- [x] (Analyse) Alle Scanner-Komponenten identifiziert:
  - scanner_handler.go (1 Handler-Datei)
  - 7 Scanner-Templates (scanner_demo, professional_scanner, scan_board, mobile_scanner, etc.)
  - Komplettes web/scanner/ Verzeichnis (WASM-Decoder, UI, Worker)
  - Alle Scanner-Routen in main.go (/scan, /scan-board, mobile scanner, API endpoints)
- [x] (Löschung) 29 Dateien vollständig entfernt (16.218 Zeilen Code)
- [x] (Bereinigung) Navigation und UI:
  - Scanner-Links aus navbar.html entfernt
  - Job-Detail Seite: "Scan devices" → "Add devices manually"
  - ScannerEnabled Config auf deprecated gesetzt (default: false)
- [x] (Tests/Docker) Erfolgreich abgeschlossen:
  - Go-Build erfolgreich (keine Scanner-Referenzen mehr)
  - Alle Tests bestanden
  - Docker Image gebaut und gepusht: `nobentie/rentalcore:2.43` + `:latest` (Commit 2a1a59f)
  - README aktualisiert (Version 2.43 Changelog)

### ⏳ Weitere Phasen
- [x] Geräteverwaltung - ABGESCHLOSSEN ✅
- [x] Scanner/Barcode - KOMPLETT ENTFERNT ✅
- [x] Kabelmanagement - ABGESCHLOSSEN ✅
- [ ] Case-Management
- [ ] Restliche Warehouse-Funktionen

## Nächste Schritte

### Phase 1 - ABGESCHLOSSEN ✅ (2025-11-03)
- ✅ Analyse, Implementierung, Deaktivierung, Tests, Docker-Builds erfolgreich
- ✅ Versionen: `nobentie/rentalcore:1.7` und `nobentie/warehousecore:1.7`
- ✅ Alle Checkboxen in Phase 1 erledigt

### Phase 2 - Geräteverwaltung - ABGESCHLOSSEN ✅ (2025-11-03)
- ✅ Analyse abgeschlossen: Device-Handler, Routen, Templates identifiziert
- ✅ WarehouseCore erweitert: DevicesTab mit vollständigem CRUD (Create/Edit/Delete/View)
- ✅ API erweitert: 7 neue Admin-Endpoints inkl. QR/Barcode-Generierung
- ✅ RentalCore deaktiviert: Redirect-Funktion, 3 Templates gelöscht (1.734 Zeilen)
- ✅ Tests erfolgreich: Go-Tests + Frontend-Build für beide Services
- ✅ Docker-Images gepusht:
  - WarehouseCore: `nobentie/warehousecore:1.8` + `:latest`
  - RentalCore: `nobentie/rentalcore:2.42` + `:latest`
- ✅ Dokumentation: README, Changelogs, Redirect-Tests aktualisiert

### Phase 3 - Scanner/Barcode Workflows - KOMPLETT ENTFERNT ✅ (2025-11-03)
- ✅ Scanner-Funktionalität wurde NICHT migriert, sondern komplett entfernt
- ✅ 29 Dateien gelöscht (16.218 Zeilen Code)
- ✅ Alle Scanner-Routen und Handler entfernt
- ✅ WASM-Decoder komplett entfernt (web/scanner/ Verzeichnis)
- ✅ Navigation und UI bereinigt
- ✅ Version: `nobentie/rentalcore:2.43` + `:latest`
- ✅ Build erfolgreich, alle Tests bestanden

### Phase 4 - Kabelmanagement - ABGESCHLOSSEN ✅ (2025-11-03)
- ✅ Analyse abgeschlossen: Cable-Handler, Routen, Templates identifiziert
- ✅ WarehouseCore erweitert: CablesTab mit vollständigem CRUD (Create/Edit/Delete/View)
- ✅ API erweitert: 7 neue Admin-Endpoints inkl. Connectors und Types
- ✅ Connector-/Type-Dropdowns implementiert
- ✅ Gender-Display (♂/♀) für Connectors
- ✅ Length-Filtering (min/max range)
- ✅ RentalCore deaktiviert: Redirect-Funktion, 2 Templates gelöscht (1.783 Zeilen)
- ✅ Tests erfolgreich: Go-Tests + Frontend-Build für beide Services
- ✅ Docker-Images gepusht:
  - WarehouseCore: `nobentie/warehousecore:1.9` + `:latest`
  - RentalCore: `nobentie/rentalcore:2.44` + `:latest`
- ✅ Dokumentation: README, Changelogs, Redirect-Tests aktualisiert

### Phase 5 - Case-Management (Nächster Schritt)
1. **Analyse RentalCore Cases:** `case_handler.go`, Templates, Routen
2. **WarehouseCore erweitern:** Case-CRUD-UI erstellen (analog zu anderen Tabs)
3. **Case-Device-Mapping:** Verwaltung der Geräte-Zuordnung zu Cases
4. **RentalCore deaktivieren:** Case-Management auf WarehouseCore umleiten
5. **Tests + Docker:** Neue Images bauen und pushen
6. **Plan.md aktualisieren:** Phase 5 Status dokumentieren

> Bei jedem Schritt Plan aktualisieren, damit andere Agenten sofort sehen, wo wir stehen (Commits, Images, offene Punkte).
