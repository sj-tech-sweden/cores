# Claude.md  
**Global configuration and development rules for the Tsunami Events project cluster**  
Projects:  
- `rentalcore` → Auftragsmanagement  
- `warehousecore` → Lagermanagement  

---

## 🧭 Overview
Diese Datei definiert zentrale Entwicklungsrichtlinien, Datenbankkonfigurationen, Build-Workflows und Philosophien für die beiden Core-Systeme.  
Beide Systeme teilen sich dieselbe Datenbankstruktur (`RentalCore.sql`) und arbeiten eng integriert zusammen.

Verzeichnisstruktur:
```
/lager_weidelbach/
├── claude.md
├── rentalcore/      → Auftragsmanagement & Jobhandling
└── warehousecore/     → Lagermanagement & Gerätebewegungen
```

---

## ⚙️ 1. Global Database Configuration

```env
DB_HOST=tsunami-events.de
DB_USER=tsweb
DB_PASS=j4z4mZv7DpG7cdCLkSQVjXCfXMOmt9dEGRp2Pmdn2Xzl5y8AAkwLmKX
DB_NAME=RentalCore
```

- Template-Datei: `RentalCore.sql` (liegt im Root von `/rentalcore/`)
- Tabellenänderungen sind erlaubt (nicht die Daten selbst)
- WarehouseCore und RentalCore greifen auf dieselbe DB-Struktur zu  
- Änderungen an der Datenbankstruktur müssen synchron in beiden Projekten dokumentiert werden

---

## 🧩 2. RentalCore

### Repository & Deployment
- **Git:** [git.server-nt.de/ntielmann/rentalcore](https://git.server-nt.de/ntielmann/rentalcore)  
- **Docker Image:** `nobentie/rentalcore`
- **Version Tags:** `1.X` + `latest`

### Build & Push
```bash
docker build -t nobentie/rentalcore:1.X .
docker push nobentie/rentalcore:1.X
docker tag nobentie/rentalcore:1.X nobentie/rentalcore:latest
docker push nobentie/rentalcore:latest
```

### Aufgabenbereich
- Auftragsmanagement (Jobs, Kunden, Rechnungen, Zuordnungen)
- Verwaltung von Job-Devices, Preisen, Status und Projektdaten
- Synchronisierte Schnittstelle zu WarehouseCore (Status und Gerätebewegungen)
- Integriert in das Business-System von Tsunami Events

### Development Rules
- Niemals Code als *„fertig“* deklarieren, wenn er es nicht zu 100 % ist  
- Keine Debug- oder temporären Dateien im Repo behalten  
- Nach jedem Commit:
  - `README` aktualisieren  
  - zu GitLab **pushen**  
  - Docker-Image **builden & pushen**  
- **Sicherheitscheck:** vor jedem Push auf sensible Daten prüfen  
- **Commit Messages:** keine Erwähnung von „Claude“ oder „AI“  
- Nur Standard-Git-Kommandos verwenden  
- Navigationsabschnitt im README aktuell halten  
- Nach jeder Codeänderung → Server **neu starten**  
  > ⚠️ Niemals `pkill server` verwenden (würde tmux-Sessions beenden)

---

## 📦 3. WarehouseCore

### Repository & Deployment
- **Git:** [git.server-nt.de/ntielmann/warehousecore](https://git.server-nt.de/ntielmann/warehousecore)  
- **Docker Image:** `nobentie/warehousecore`
- **Version Tags:** `1.X` + `latest`

### Build & Push
```bash
docker build -t nobentie/warehousecore:1.X .
docker push nobentie/warehousecore:1.X
docker tag nobentie/warehousecore:1.X nobentie/warehousecore:latest
docker push nobentie/warehousecore:latest
```

### Datenbank
Verwendet dieselbe Konfiguration wie RentalCore:
```env
DB_HOST=tsunami-events.de
DB_USER=tsweb
DB_PASS=j4z4mZv7DpG7cdCLkSQVjXCfXMOmt9dEGRp2Pmdn2Xzl5y8AAkwLmKX
DB_NAME=RentalCore
```

---

### 🧠 Vision & Core Features

**WarehouseCore** ist das physische Gegenstück zu **RentalCore** – es bildet alle realen Lagerprozesse in Weidelbach digital ab.

#### Hauptziele
- **Digitale Lagerabbildung:** Jeder Lagerbereich, jedes Case und jeder Standort wird digital repräsentiert.  
- **Echtzeit-Statusanzeige:** Geräte, Cases und Kabel besitzen Zustände wie „im Lager“, „auf Job“, „defekt“, „repariert“.  
- **Live-Synchronisierung mit RentalCore:** Statusänderungen durch Scans werden sofort reflektiert.  
- **Visuelle Lagerkarte:** Spätere Erweiterung für grafische Darstellung (Regale, Cases, Räume).  
- **Erweiterbares Scansystem:** Alle Barcode- oder RFID-Scans werden automatisch gespeichert.  
- **Job-Bezug:** Jedes Gerät kennt seinen aktuellen Job-Kontext.  
- **Defekt- & Wartungsmanagement:** Verwaltung von Reparaturen, Prüfintervallen und Defektmeldungen.

#### Module
- **Device Tracker:** Verwaltung physischer Gerätebewegungen  
- **Case Manager:** Cases & Inhalte, optional RFID-unterstützt  
- **Storage Zones:** Logische Zonen (Regale, Cases, Fahrzeuge etc.)  
- **Maintenance Engine:** Defekt-, Prüf- und Wartungsstatus

---

### Development Rules
- Gleiche Philosophie & Buildstruktur wie RentalCore  
- Nach jedem Commit:
  - `README` aktualisieren  
  - zu GitLab **pushen**  
  - Docker-Image **builden & pushen**  
- **Keine sensiblen Daten ins Repo!**
- Tabellenänderungen immer in `RentalCore.sql` nachziehen  
- **Keine `_final`, `_new`, `_fixed` etc.** – alte Dateien immer löschen

---

## 🧰 4. Gemeinsame Entwicklungsrichtlinien

### File Management
- Alte Versionen sofort löschen  
- Keine Duplikate oder temporäre Dateien  
- Saubere Verzeichnisstruktur beibehalten  

### Professional Mindset
- Hoher Qualitätsanspruch  
- Klare, strukturierte Commits  
- Reproduzierbare Builds  
- Kein Feature bleibt ungetestet  

### Server Management
- Nach Änderungen sauber neustarten  
- Niemals `pkill server` verwenden  
- tmux-Sessions nicht stören  

### Sicherheit
- Alle Secrets prüfen, bevor Dateien gepusht werden  
- Nur Demo-Daten in Repos  
- `.env`-Dateien niemals pushen  

---

## 🌐 Zielumgebung

| Komponente | Beschreibung |
|-------------|---------------|
| **Server Root** | `/lager_weidelbach` |
| **RentalCore** | Auftragsmanagement-System |
| **WarehouseCore** | Physisches Lagermanagement |
| **Gemeinsame DB** | `RentalCore.sql` |
| **Docker Images** | `nobentie/rentalcore`, `nobentie/warehousecore` |
| **Host** | tsunami-events.de |

## GITLAB CREDENTIALS

Warehousecore
- Username: ntielmann
- Accesscode: glpat-gKzQug1kiBpRUxflfxE2p286MQp1OmQH.01.0w1pqzzx8

Rentalcore:
- Username: ntielmann
- Accesscode: glpat-WXH35pLDR5AuJ0OeDHPmG286MQp1OmMH.01.0w170uoa7
