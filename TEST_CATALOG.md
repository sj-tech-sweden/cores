# 🧪 Tsunami Events Systems - Ultimate Test Catalog

This catalog is the definitive source of truth for validating the complete functionality of the Tsunami Events software ecosystem (`rentalcore` and `warehousecore`).

> **Testing Protocol**:
> 1.  All tests must start with a clean environment (`docker compose down -v && docker compose up -d`).
> 2.  If a bug is found, a specific reproduction test case must be created.
> 3.  The relevant Subagent must fix the code/schema.
> 4.  The test must pass **3 consecutive times** on a fresh environment to be considered "Fixed".
> 5.  "Live repairs" (hotfixes without code persistence) are strictly forbidden. Fixes must survive a restart.

---

## 🏗️ 1. Infrastructure & Shared Services
### 1.1 Deployment & Environment
- [ ] **Clean Boot**: `docker compose up -d` starts all services (rentalcore, warehousecore, postgres, mosquitto) without Error/Exit.
- [ ] **Database Initialization**: Migrations run successfully (`000_combined_init.sql`). All tables exist.
- [ ] **Default Data**: Admin user exists (`admin`/`admin`). Default Roles exist. Default Statuses exist.
- [ ] **Shared Session**: Login on RentalCore allows access to WarehouseCore (if SSO/Shared DB compliant) or credentials work on both.
- [ ] **Cookie Handling**: verify `COOKIE_DOMAIN` allows local/dev env cookies.

### 1.2 Authentication & Security (Shared)
- [ ] **Initial Login**: Admin uses default credentials -> Redirected to Force Password Change.
- [ ] **Password Logic**: New password must be accepted. Old password rejected after change.
- [ ] **2FA / WebAuthn**: Register a Passkey/WebAuthn device. Login with Passkey.
- [ ] **API Security**: Unauthenticated API calls return 401. Active User check works.
- [ ] **Role Enforcement**:
    -   `admin` has full access.
    -   `viewer` cannot create/edit/delete (test on Jobs/Customers).
    -   `warehouse_worker` cannot access RentalCore checks (if applicable).
- [ ] **Session Expiry**: Session timeout redirects to login.

---

## 🔌 2. WarehouseCore (Master Data & Operations)
*Port: 8082*

### 2.1 Master Data Management (Product Catalog)
- [ ] **Brands**:
    -   Create Brand (e.g., "Shure", "L-Acoustics").
    -   List Brands.
    -   Edit/Delete Brand.
- [ ] **Categories**:
    -   Create Category Tree (e.g., Audio -> Microphones).
    -   Verify Tree View rendering.
- [ ] **Products (The Core Item)**:
    -   Create Product (Name, Brand, Category, Weight, Power, Dimensions).
    -   Upload Product Image.
    -   **Dependencies**: Assign accessories to product (e.g., Mic needs Clip).
- [ ] **Product Packages (Kits)**:
    -   Create Package (e.g., "Drum Mic Kit").
    -   Add Products to Package.
- [ ] **Cables**:
    -   Define Cable Types (Length, Connector A, Connector B).

### 2.2 Inventory Management (Physical Assets)
- [ ] **Devices (Serialized Items)**:
    -   Create Device instance for a Product.
    -   Assign Barcode/QR Code.
    -   Scan Device (Simulate Scan).
- [ ] **Count Types**:
    -   Define counting logic (Serialized vs Bulk/Quantity).

### 2.3 Storage & Logistics
- [ ] **Storage Zones**:
    -   Create Warehouse Zones (Shelf A, Shelf B).
    -   Assign LED Controller channels to Zones (for Pick-to-Light).
- [ ] **Labels**:
    -   Generate Barcode Label PDF for a Device.
    -   Generate Label for a Shelf.

### 2.4 Hardware Integration
- [ ] **LED Controller**:
    -   Trigger "Highlight Device" -> Verify MQTT message sent to mosquitto.
    -   Verify LED Controller Handlers return 200.

---

## 💼 3. RentalCore (Business Logic & Rental)
*Port: 8081*

### 3.1 Dashboard & Analytics
- [ ] **Widgets**: Load "Active Jobs", "Revenue", "Upcoming Returns".
- [ ] **Customization**: Add/Remove widgets. Save preferences.
- [ ] **Financial Stats**: Verify revenue calculation (simulated).

### 3.2 CRM (Customer Relationship)
- [ ] **Customers**:
    -   Create Customer (Company, Address, Contact).
    -   Validate Email format.
    -   **History**: View past jobs for customer.

### 3.3 Job Management (The Core Workflow)
- [ ] **Job Lifecycle**:
    -   **Create Job**: Date Range, Customer, Name.
    -   **Planning**: Add Items (Products/Packages) to Job.
    -   **Availability Check**: Verify conflict detection (Overbooking).
    -   **Status Workflow**: Draft -> Confirmed -> Prep -> Active -> Returned -> Invoiced.
- [ ] **Scanboard / Logistics**:
    -   **Check-Out**: "Scan" items out of warehouse -> Job Status updates.
    -   **Check-In**: "Scan" items back -> Inventory updates.
    -   **Shortage Handling**: Flag missing/damaged items.

### 3.4 Equipment & Inventory Views
- [ ] **Availability Tree**: View Calendar/Gantt of item availability.
- [ ] **Maintenance**: Flag device as "In Repair". Verify it's unavailable for Jobs.
- [ ] **Cases**: Manage Case contents (Items inside Case).

### 3.5 Financials
- [ ] **Invoices**:
    -   Generate Invoice from Job.
    -   Test PDF Generation (Layout, Line Items, Totals, VAT).
    -   Mark Invoice as Paid.
- [ ] **Templates**: Edit Invoice PDF Template (CSS/HTML).

### 3.6 Documents & Attachments
- [ ] **Job Attachments**: Upload PDF/Image to Job.
- [ ] **Signatures**: Digital Signature flow (if implemented).

### 3.7 PWA & Mobile
- [ ] **Offline Mode**: Verify Manifest/Service Worker loads.
- [ ] **Mobile View**: Responsiveness check on small screens (`<500px`).

---

## 🛠️ 4. System Administration
### 4.1 User & Role Management
- [ ] **Users**: CRUD Users.
- [ ] **Roles**: CRUD Roles (Permissions).
- [ ] **Assignment**: Assign Role to User. Verify Permission effectiveness.

### 4.2 Audit & Monitoring
- [ ] **Audit Log**: Verify actions (Create Job, Login) appear in Audit Log.
- [ ] **Details**: Check "Before/After" value diffs (JSONB check).

### 4.3 App Settings
- [ ] **Settings**: Change "Company Name", "Logo", "Tax Rate".
- [ ] **Persistence**: Settings survive restart.

---

## 🧪 5. Edge Cases & Stress Tests
- [ ] **Concurrency**: Edit same Job from two tabs.
- [ ] **Large Data**: Create Job with 500 items. Check Invoice PDF generation time.
- [ ] **Invalid Input**: SQL Injection attempts in Search fields (Basic check).
- [ ] **Unicode**: Use Emoji/Special Chars in Customer Name.

---

## 🔄 6. Cross-System Integration Workflows (The "Holy Grail")
- [ ] **Product -> Job Flow**:
    1.  **WarehouseCore**: Create new Product "Test Microphone SM58" (Brand: Shure, Category: Audio).
    2.  **WarehouseCore**: Create a Device instance (Serial: SN12345) for this product in "Main Warehouse".
    3.  **RentalCore**: Create a new Job "Concert A".
    4.  **RentalCore**: In Job Planning, search for "Test Microphone". Verify it appears.
    5.  **RentalCore**: Add to Job. Verify Availability shows "1 Available".
    6.  **RentalCore**: Set Job Status to "Confirmed".
    7.  **RentalCore**: Check Availability Tree -> Should show bar for the job duration.
    8.  **WarehouseCore**: Check Product Inventory -> Should show "1 Reserved" or similar status.

---

## 🔄 Execution Log
*Subagent will append results here.*

| Date | Suite | Status | Notes |
|------|-------|--------|-------|
| 2026-01-09 | Infra Init | PASS | Deployment successful. |
| 2026-01-09 | API Fixes | PASS | Fixed 500/403 errors in WarehouseCore API. Verified via Curl. |
| 2026-01-09 | Integ Test | BLOCKED | Browser automation rate limited (429). Manual verification required. |
