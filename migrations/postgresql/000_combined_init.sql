-- =============================================================================
-- RentalCore & WarehouseCore - Combined PostgreSQL Schema
-- =============================================================================
-- This script initializes a fresh database for both applications.
-- It is automatically executed on first Docker Compose startup.
-- 
-- Default Admin User: admin / admin (forced to change password on first login)
-- =============================================================================

-- =============================================================================
-- PART 1: CORE TABLES (Shared by both applications)
-- =============================================================================

-- RBAC Roles table (must be created before users for FK reference)
CREATE TABLE IF NOT EXISTS roles (
    roleid SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    display_name VARCHAR(150),
    description TEXT,
    scope VARCHAR(50) DEFAULT 'global',  -- 'global', 'rentalcore', 'warehousecore'
    is_system_role BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    permissions JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Users table (for auth) - shared between both systems
CREATE TABLE IF NOT EXISTS users (
    userid SERIAL PRIMARY KEY,
    username VARCHAR(100) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    is_admin BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    force_password_change BOOLEAN DEFAULT FALSE,
    last_login TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_active ON users(is_active);

-- User Roles junction table
CREATE TABLE IF NOT EXISTS user_roles (
    id SERIAL PRIMARY KEY,
    userid INT NOT NULL REFERENCES users(userid) ON DELETE CASCADE,
    roleid INT NOT NULL REFERENCES roles(roleid) ON DELETE CASCADE,
    assigned_by INT REFERENCES users(userid) ON DELETE SET NULL,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NULL,
    is_active BOOLEAN DEFAULT TRUE,
    UNIQUE(userid, roleid)
);
CREATE INDEX IF NOT EXISTS idx_user_roles_user ON user_roles(userid);
CREATE INDEX IF NOT EXISTS idx_user_roles_role ON user_roles(roleid);

-- Sessions table
CREATE TABLE IF NOT EXISTS sessions (
    session_id VARCHAR(255) PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(userid) ON DELETE CASCADE,
    data TEXT,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_expires ON sessions(expires_at);

-- 2FA table
CREATE TABLE IF NOT EXISTS user_2fa (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL UNIQUE REFERENCES users(userid) ON DELETE CASCADE,
    secret VARCHAR(255),
    backup_codes TEXT,
    is_enabled BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_user_2fa_user ON user_2fa(user_id);

-- Audit logs table
CREATE TABLE IF NOT EXISTS audit_log (
    id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(userid) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(100),
    entity_id VARCHAR(255),
    old_values JSONB,
    new_values JSONB,
    ip_address VARCHAR(45),
    user_agent TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_action ON audit_log(action);
CREATE INDEX IF NOT EXISTS idx_audit_entity ON audit_log(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_timestamp ON audit_log(timestamp);

-- App Settings table (for system configuration)
CREATE TABLE IF NOT EXISTS app_settings (
    id SERIAL PRIMARY KEY,
    scope VARCHAR(50) NOT NULL DEFAULT 'global',  -- 'global', 'rentalcore', 'warehousecore'
    key VARCHAR(100) NOT NULL,
    value TEXT,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(scope, key)
);

-- =============================================================================
-- PART 2: RENTALCORE TABLES
-- =============================================================================

-- Customers table
CREATE TABLE IF NOT EXISTS customers (
    customerid SERIAL PRIMARY KEY,
    name VARCHAR(255),
    companyname VARCHAR(255),
    firstname VARCHAR(100),
    lastname VARCHAR(100),
    street VARCHAR(255),
    housenumber VARCHAR(20),
    zip VARCHAR(20),
    city VARCHAR(100),
    federalstate VARCHAR(100),
    country VARCHAR(100) DEFAULT 'Deutschland',
    phonenumber VARCHAR(50),
    email VARCHAR(255),
    customertype VARCHAR(50),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(name);
CREATE INDEX IF NOT EXISTS idx_customers_email ON customers(email);
CREATE INDEX IF NOT EXISTS idx_customers_companyname ON customers(companyname);
CREATE INDEX IF NOT EXISTS idx_customers_lastname ON customers(lastname);

-- Status table (for job statuses)
CREATE TABLE IF NOT EXISTS status (
    statusid SERIAL PRIMARY KEY,
    status VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    color VARCHAR(7) DEFAULT '#007bff',
    sort_order INT DEFAULT 0
);

-- Job categories table
CREATE TABLE IF NOT EXISTS jobcategory (
    jobcategoryid SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    abbreviation VARCHAR(10)
);

-- Categories for products
CREATE TABLE IF NOT EXISTS categories (
    categoryid SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    abbreviation VARCHAR(10)
);

-- Subcategories for products
CREATE TABLE IF NOT EXISTS subcategories (
    subcategoryid VARCHAR(50) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    abbreviation VARCHAR(10),
    categoryid INT REFERENCES categories(categoryid) ON DELETE SET NULL
);

-- Subbiercategories for products (third level)
CREATE TABLE IF NOT EXISTS subbiercategories (
    subbiercategoryid VARCHAR(50) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    abbreviation VARCHAR(10),
    subcategoryid VARCHAR(50) REFERENCES subcategories(subcategoryid) ON DELETE SET NULL
);

-- Manufacturers table
CREATE TABLE IF NOT EXISTS manufacturer (
    manufacturerid SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    website VARCHAR(255)
);

-- Brands table
CREATE TABLE IF NOT EXISTS brands (
    brandid SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    manufacturerid INT REFERENCES manufacturer(manufacturerid) ON DELETE SET NULL
);

-- Count types for accessories/consumables
CREATE TABLE IF NOT EXISTS count_types (
    count_type_id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    abbreviation VARCHAR(10),
    is_decimal BOOLEAN DEFAULT FALSE
);

-- Products table
CREATE TABLE IF NOT EXISTS products (
    productid SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    categoryid INT REFERENCES categories(categoryid) ON DELETE SET NULL,
    subcategoryid VARCHAR(50) REFERENCES subcategories(subcategoryid) ON DELETE SET NULL,
    subbiercategoryid VARCHAR(50) REFERENCES subbiercategories(subbiercategoryid) ON DELETE SET NULL,
    "manufacturerID" INT REFERENCES manufacturer(manufacturerid) ON DELETE SET NULL,
    "brandID" INT REFERENCES brands(brandid) ON DELETE SET NULL,
    description TEXT,
    "maintenanceInterval" INT,
    itemcostperday DECIMAL(10,2) DEFAULT 0.00,
    weight DECIMAL(10,3),
    height DECIMAL(10,3),
    width DECIMAL(10,3),
    depth DECIMAL(10,3),
    powerconsumption DECIMAL(10,2),
    pos_in_category INT,
    is_accessory BOOLEAN DEFAULT FALSE,
    is_consumable BOOLEAN DEFAULT FALSE,
    count_type_id INT REFERENCES count_types(count_type_id) ON DELETE SET NULL,
    stock_quantity DECIMAL(10,3),
    min_stock_level DECIMAL(10,3),
    generic_barcode VARCHAR(100),
    price_per_unit DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_products_name ON products(name);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(categoryid);
CREATE INDEX IF NOT EXISTS idx_products_is_accessory ON products(is_accessory);
CREATE INDEX IF NOT EXISTS idx_products_is_consumable ON products(is_consumable);
CREATE INDEX IF NOT EXISTS idx_products_generic_barcode ON products(generic_barcode);

-- Devices table
CREATE TABLE IF NOT EXISTS devices (
    deviceid VARCHAR(50) PRIMARY KEY,
    productid INT REFERENCES products(productid) ON DELETE SET NULL,
    serialnumber VARCHAR(255),
    purchasedate DATE,
    lastmaintenance DATE,
    nextmaintenance DATE,
    insurancenumber VARCHAR(100),
    status VARCHAR(50) DEFAULT 'free',
    insuranceid INT,
    qr_code VARCHAR(255),
    current_location VARCHAR(255),
    gps_latitude DECIMAL(10,7),
    gps_longitude DECIMAL(10,7),
    condition_rating DECIMAL(3,1) DEFAULT 5.0,
    usage_hours DECIMAL(10,2) DEFAULT 0.00,
    total_revenue DECIMAL(12,2) DEFAULT 0.00,
    last_maintenance_cost DECIMAL(10,2),
    notes TEXT,
    barcode VARCHAR(255),
    current_zone_id INT,
    current_case_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_devices_productid ON devices(productid);
CREATE INDEX IF NOT EXISTS idx_devices_status ON devices(status);
CREATE INDEX IF NOT EXISTS idx_devices_barcode ON devices(barcode);
CREATE INDEX IF NOT EXISTS idx_devices_serialnumber ON devices(serialnumber);

-- Jobs table
CREATE TABLE IF NOT EXISTS jobs (
    jobid SERIAL PRIMARY KEY,
    job_code VARCHAR(50),
    customerid INT NOT NULL REFERENCES customers(customerid) ON DELETE CASCADE,
    statusid INT NOT NULL REFERENCES status(statusid) ON DELETE RESTRICT,
    jobcategoryid INT REFERENCES jobcategory(jobcategoryid) ON DELETE SET NULL,
    description TEXT,
    discount DECIMAL(10,2) DEFAULT 0.00,
    discount_type VARCHAR(20) DEFAULT 'amount',
    revenue DECIMAL(12,2) DEFAULT 0.00,
    final_revenue DECIMAL(12,2),
    startdate DATE,
    enddate DATE,
    created_by INT REFERENCES users(userid) ON DELETE SET NULL,
    updated_by INT REFERENCES users(userid) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL
);
CREATE INDEX IF NOT EXISTS idx_jobs_customerid ON jobs(customerid);
CREATE INDEX IF NOT EXISTS idx_jobs_statusid ON jobs(statusid);
CREATE INDEX IF NOT EXISTS idx_jobs_dates ON jobs(startdate, enddate);
CREATE INDEX IF NOT EXISTS idx_jobs_job_code ON jobs(job_code);
CREATE INDEX IF NOT EXISTS idx_jobs_deleted_at ON jobs(deleted_at);

-- Job-Device relationship table
CREATE TABLE IF NOT EXISTS job_devices (
    jobid INT NOT NULL REFERENCES jobs(jobid) ON DELETE CASCADE,
    deviceid VARCHAR(50) NOT NULL REFERENCES devices(deviceid) ON DELETE CASCADE,
    custom_price DECIMAL(10,2),
    package_id INT,
    is_package_item BOOLEAN DEFAULT FALSE,
    pack_status VARCHAR(20) DEFAULT 'pending',
    pack_ts TIMESTAMP,
    PRIMARY KEY (jobid, deviceid)
);
CREATE INDEX IF NOT EXISTS idx_job_devices_jobid ON job_devices(jobid);
CREATE INDEX IF NOT EXISTS idx_job_devices_deviceid ON job_devices(deviceid);
CREATE INDEX IF NOT EXISTS idx_job_devices_pack_status ON job_devices(pack_status);

-- Cases table (for equipment cases)
CREATE TABLE IF NOT EXISTS cases (
    caseid SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    weight DECIMAL(10,2),
    width DECIMAL(10,2),
    height DECIMAL(10,2),
    depth DECIMAL(10,2),
    status VARCHAR(50) DEFAULT 'free',
    barcode VARCHAR(255),
    zone_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_cases_status ON cases(status);
CREATE INDEX IF NOT EXISTS idx_cases_barcode ON cases(barcode);

-- Devices in Cases junction table
CREATE TABLE IF NOT EXISTS devicescases (
    caseid INT NOT NULL REFERENCES cases(caseid) ON DELETE CASCADE,
    deviceid VARCHAR(50) NOT NULL REFERENCES devices(deviceid) ON DELETE CASCADE,
    PRIMARY KEY (caseid, deviceid)
);

-- Cable connectors
CREATE TABLE IF NOT EXISTS cable_connectors (
    "cable_connectorsID" SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    abbreviation VARCHAR(20),
    gender VARCHAR(10)
);

-- Cable types
CREATE TABLE IF NOT EXISTS cable_types (
    "cable_typesID" SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL
);

-- Cables table
CREATE TABLE IF NOT EXISTS cables (
    "cableID" SERIAL PRIMARY KEY,
    connector1 INT NOT NULL REFERENCES cable_connectors("cable_connectorsID") ON DELETE RESTRICT,
    connector2 INT NOT NULL REFERENCES cable_connectors("cable_connectorsID") ON DELETE RESTRICT,
    typ INT NOT NULL REFERENCES cable_types("cable_typesID") ON DELETE RESTRICT,
    length DECIMAL(10,2) NOT NULL,
    mm2 DECIMAL(10,2),
    name VARCHAR(255)
);
CREATE INDEX IF NOT EXISTS idx_cables_connector1 ON cables(connector1);
CREATE INDEX IF NOT EXISTS idx_cables_connector2 ON cables(connector2);
CREATE INDEX IF NOT EXISTS idx_cables_type ON cables(typ);

-- Company settings table
CREATE TABLE IF NOT EXISTS company_settings (
    id SERIAL PRIMARY KEY,
    company_name VARCHAR(255),
    address_line1 VARCHAR(255),
    address_line2 VARCHAR(255),
    city VARCHAR(100),
    postal_code VARCHAR(20),
    country VARCHAR(100) DEFAULT 'Deutschland',
    phone VARCHAR(50),
    email VARCHAR(255),
    website VARCHAR(255),
    tax_id VARCHAR(100),
    vat_id VARCHAR(100),
    logo_path VARCHAR(512),
    terms_and_conditions TEXT,
    invoice_prefix VARCHAR(50) DEFAULT 'INV',
    invoice_footer TEXT,
    default_tax_rate DECIMAL(5,2) DEFAULT 19.00,
    currency VARCHAR(10) DEFAULT 'EUR',
    bank_name VARCHAR(255),
    bank_iban VARCHAR(50),
    bank_bic VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User preferences table
CREATE TABLE IF NOT EXISTS user_preferences (
    preference_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL UNIQUE REFERENCES users(userid) ON DELETE CASCADE,
    language VARCHAR(10) DEFAULT 'de',
    theme VARCHAR(20) DEFAULT 'dark',
    time_zone VARCHAR(50) DEFAULT 'Europe/Berlin',
    date_format VARCHAR(20) DEFAULT 'DD.MM.YYYY',
    time_format VARCHAR(10) DEFAULT '24h',
    email_notifications BOOLEAN DEFAULT TRUE,
    system_notifications BOOLEAN DEFAULT TRUE,
    job_status_notifications BOOLEAN DEFAULT TRUE,
    device_alert_notifications BOOLEAN DEFAULT TRUE,
    items_per_page INT DEFAULT 25,
    default_view VARCHAR(20) DEFAULT 'list',
    show_advanced_options BOOLEAN DEFAULT FALSE,
    auto_save_enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User Dashboard Widgets table
CREATE TABLE IF NOT EXISTS user_dashboard_widgets (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL UNIQUE REFERENCES users(userid) ON DELETE CASCADE,
    widgets JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_user_dashboard_widgets_user ON user_dashboard_widgets(user_id);

-- =============================================================================
-- PART 3: WAREHOUSECORE TABLES
-- =============================================================================

-- Storage zone types (simulating ENUM)
DO $$ BEGIN
    CREATE TYPE zone_type AS ENUM ('shelf', 'rack', 'case', 'vehicle', 'stage', 'warehouse', 'other');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Storage Zones table
CREATE TABLE IF NOT EXISTS storage_zones (
    zone_id SERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    type zone_type NOT NULL DEFAULT 'other',
    description TEXT,
    parent_zone_id INT NULL REFERENCES storage_zones(zone_id) ON DELETE SET NULL,
    capacity INT NULL,
    location VARCHAR(255) NULL,
    barcode VARCHAR(255),
    metadata JSONB NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    label_url VARCHAR(512),
    led_strip_id INT,
    led_start INT,
    led_end INT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_zone_type ON storage_zones(type);
CREATE INDEX IF NOT EXISTS idx_zone_active ON storage_zones(is_active);
CREATE INDEX IF NOT EXISTS idx_zone_parent ON storage_zones(parent_zone_id);
CREATE INDEX IF NOT EXISTS idx_zone_barcode ON storage_zones(barcode);

-- Add zone reference to devices and cases
ALTER TABLE devices ADD COLUMN IF NOT EXISTS current_zone_id INT REFERENCES storage_zones(zone_id) ON DELETE SET NULL;
ALTER TABLE cases ADD COLUMN IF NOT EXISTS zone_id INT REFERENCES storage_zones(zone_id) ON DELETE SET NULL;

-- Device movements table
CREATE TABLE IF NOT EXISTS device_movements (
    movement_id SERIAL PRIMARY KEY,
    device_id VARCHAR(50) NOT NULL REFERENCES devices(deviceid) ON DELETE CASCADE,
    from_zone_id INT NULL REFERENCES storage_zones(zone_id) ON DELETE SET NULL,
    to_zone_id INT NULL REFERENCES storage_zones(zone_id) ON DELETE SET NULL,
    from_case_id INT NULL REFERENCES cases(caseid) ON DELETE SET NULL,
    to_case_id INT NULL REFERENCES cases(caseid) ON DELETE SET NULL,
    moved_by INT NULL REFERENCES users(userid) ON DELETE SET NULL,
    movement_type VARCHAR(50) NOT NULL DEFAULT 'transfer',
    reason TEXT,
    metadata JSONB NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_movement_device ON device_movements(device_id);
CREATE INDEX IF NOT EXISTS idx_movement_from_zone ON device_movements(from_zone_id);
CREATE INDEX IF NOT EXISTS idx_movement_to_zone ON device_movements(to_zone_id);
CREATE INDEX IF NOT EXISTS idx_movement_type ON device_movements(movement_type);
CREATE INDEX IF NOT EXISTS idx_movement_created ON device_movements(created_at);

-- Scan events table
CREATE TABLE IF NOT EXISTS scan_events (
    scan_id SERIAL PRIMARY KEY,
    device_id VARCHAR(50) NULL REFERENCES devices(deviceid) ON DELETE SET NULL,
    zone_id INT NULL REFERENCES storage_zones(zone_id) ON DELETE SET NULL,
    case_id INT NULL REFERENCES cases(caseid) ON DELETE SET NULL,
    scanner_id VARCHAR(100),
    scanned_by INT NULL REFERENCES users(userid) ON DELETE SET NULL,
    scan_type VARCHAR(50) NOT NULL DEFAULT 'identify',
    barcode_value VARCHAR(255) NOT NULL,
    scan_result VARCHAR(50) NOT NULL DEFAULT 'success',
    metadata JSONB NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_scan_device ON scan_events(device_id);
CREATE INDEX IF NOT EXISTS idx_scan_zone ON scan_events(zone_id);
CREATE INDEX IF NOT EXISTS idx_scan_type ON scan_events(scan_type);
CREATE INDEX IF NOT EXISTS idx_scan_created ON scan_events(created_at);
CREATE INDEX IF NOT EXISTS idx_scan_barcode ON scan_events(barcode_value);

-- Defect reports table
CREATE TABLE IF NOT EXISTS defect_reports (
    defect_id SERIAL PRIMARY KEY,
    device_id VARCHAR(50) NOT NULL REFERENCES devices(deviceid) ON DELETE CASCADE,
    reported_by INT NULL REFERENCES users(userid) ON DELETE SET NULL,
    severity VARCHAR(20) NOT NULL DEFAULT 'minor',
    status VARCHAR(20) NOT NULL DEFAULT 'open',
    description TEXT NOT NULL,
    resolution TEXT,
    resolved_by INT NULL REFERENCES users(userid) ON DELETE SET NULL,
    resolved_at TIMESTAMP NULL,
    metadata JSONB NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_defect_device ON defect_reports(device_id);
CREATE INDEX IF NOT EXISTS idx_defect_status ON defect_reports(status);
CREATE INDEX IF NOT EXISTS idx_defect_severity ON defect_reports(severity);
CREATE INDEX IF NOT EXISTS idx_defect_created ON defect_reports(created_at);

-- LED Controllers table
CREATE TABLE IF NOT EXISTS led_controllers (
    id SERIAL PRIMARY KEY,
    controller_id VARCHAR(100) NOT NULL UNIQUE,
    display_name VARCHAR(100),
    topic_suffix VARCHAR(100),
    zone_types TEXT[],
    status_data JSONB,
    is_active BOOLEAN DEFAULT TRUE,
    last_seen TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_led_controller_id ON led_controllers(controller_id);
CREATE INDEX IF NOT EXISTS idx_led_active ON led_controllers(is_active);

-- Label templates table
CREATE TABLE IF NOT EXISTS label_templates (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    template_type VARCHAR(50) NOT NULL DEFAULT 'device',
    width_mm DECIMAL(10,2) DEFAULT 62,
    height_mm DECIMAL(10,2) DEFAULT 29,
    template_content TEXT,
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Product packages table (for rental bundles)
CREATE TABLE IF NOT EXISTS product_packages (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    code VARCHAR(50) UNIQUE,
    description TEXT,
    short_description VARCHAR(500),
    price DECIMAL(10,2) DEFAULT 0.00,
    category VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    website_visible BOOLEAN DEFAULT FALSE,
    website_description TEXT,
    website_image_url VARCHAR(512),
    website_sort_order INT DEFAULT 0,
    alias_json TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_package_code ON product_packages(code);
CREATE INDEX IF NOT EXISTS idx_package_category ON product_packages(category);
CREATE INDEX IF NOT EXISTS idx_package_active ON product_packages(is_active);
CREATE INDEX IF NOT EXISTS idx_package_website ON product_packages(website_visible);

-- Product package items junction table
CREATE TABLE IF NOT EXISTS product_package_items (
    id SERIAL PRIMARY KEY,
    package_id INT NOT NULL REFERENCES product_packages(id) ON DELETE CASCADE,
    product_id INT NOT NULL REFERENCES products(productid) ON DELETE CASCADE,
    quantity INT DEFAULT 1,
    is_optional BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_pkg_item_package ON product_package_items(package_id);
CREATE INDEX IF NOT EXISTS idx_pkg_item_product ON product_package_items(product_id);

-- Rental equipment (external rentals from suppliers)
CREATE TABLE IF NOT EXISTS rental_equipment (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    supplier VARCHAR(255),
    category VARCHAR(100),
    description TEXT,
    rental_price DECIMAL(10,2) DEFAULT 0.00,
    customer_price DECIMAL(10,2) DEFAULT 0.00,
    is_active BOOLEAN DEFAULT TRUE,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_rental_equipment_supplier ON rental_equipment(supplier);
CREATE INDEX IF NOT EXISTS idx_rental_equipment_active ON rental_equipment(is_active);

-- API Keys table
CREATE TABLE IF NOT EXISTS api_keys (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    key_hash VARCHAR(255) NOT NULL UNIQUE,
    key_prefix VARCHAR(20) NOT NULL,
    user_id INT REFERENCES users(userid) ON DELETE CASCADE,
    permissions JSONB DEFAULT '[]',
    is_active BOOLEAN DEFAULT TRUE,
    expires_at TIMESTAMP,
    last_used_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_api_key_hash ON api_keys(key_hash);
CREATE INDEX IF NOT EXISTS idx_api_key_active ON api_keys(is_active);
CREATE INDEX IF NOT EXISTS idx_api_key_user ON api_keys(user_id);

-- =============================================================================
-- PART 4: DEFAULT DATA
-- =============================================================================

-- Default job statuses
INSERT INTO status (status, description, color, sort_order) VALUES
('Planung', 'Job ist in der Planungsphase', '#6c757d', 1),
('Vorbereitung', 'Job wird vorbereitet', '#17a2b8', 2),
('Aktiv', 'Job ist aktuell aktiv', '#28a745', 3),
('Abgeschlossen', 'Job wurde abgeschlossen', '#007bff', 4),
('Abgerechnet', 'Job wurde abgerechnet', '#6610f2', 5),
('Storniert', 'Job wurde storniert', '#dc3545', 6),
('Pausiert', 'Job ist temporär pausiert', '#ffc107', 7)
ON CONFLICT (status) DO NOTHING;

-- Default RBAC roles
INSERT INTO roles (name, display_name, description, scope, is_system_role, permissions) VALUES
-- Global roles
('super_admin', 'Super Administrator', 'Full access across all systems', 'global', TRUE, '["*"]'),
-- RentalCore roles
('admin', 'Rental Key User', 'RentalCore full administration', 'rentalcore', TRUE, '["rentalcore.*"]'),
('manager', 'Rental Manager', 'Jobs, customers, devices management', 'rentalcore', TRUE, '["rentalcore.jobs.*", "rentalcore.customers.*", "rentalcore.devices.read"]'),
('operator', 'Rental Operator', 'Operational flows including scanning', 'rentalcore', TRUE, '["rentalcore.jobs.read", "rentalcore.jobs.scan", "rentalcore.devices.read"]'),
('viewer', 'Rental See-Only', 'Read-only access to RentalCore', 'rentalcore', TRUE, '["rentalcore.*.read"]'),
-- WarehouseCore roles
('warehouse_admin', 'Warehouse Admin', 'WarehouseCore full administration', 'warehousecore', TRUE, '["warehousecore.*"]'),
('warehouse_manager', 'Warehouse Manager', 'Warehouse operations and reporting', 'warehousecore', TRUE, '["warehousecore.zones.*", "warehousecore.devices.*", "warehousecore.reports.*"]'),
('warehouse_worker', 'Warehouse Worker', 'Daily warehouse tasks and scans', 'warehousecore', TRUE, '["warehousecore.devices.read", "warehousecore.devices.scan", "warehousecore.zones.read"]'),
('warehouse_viewer', 'Warehouse Viewer', 'Read-only warehouse access', 'warehousecore', TRUE, '["warehousecore.*.read"]')
ON CONFLICT (name) DO NOTHING;

-- Default admin user
-- Password: 'admin' (bcrypt hash)
-- IMPORTANT: force_password_change is TRUE - user MUST change password on first login!
INSERT INTO users (username, email, password_hash, first_name, last_name, is_admin, is_active, force_password_change)
VALUES ('admin', 'admin@example.com', '$2a$10$AlHJcEvCFEXXAoxQ/S4XXeVy3coR0yHtTv0Pn3bHEH/z3t3jdGVru', 'System', 'Administrator', TRUE, TRUE, TRUE)
ON CONFLICT (username) DO NOTHING;

-- Assign all administrative roles to the default admin user
DO $$
DECLARE
    admin_user_id INT;
BEGIN
    SELECT userid INTO admin_user_id FROM users WHERE username = 'admin';
    IF admin_user_id IS NOT NULL THEN
        INSERT INTO user_roles (userid, roleid)
        SELECT admin_user_id, roleid FROM roles WHERE name IN ('super_admin', 'admin', 'warehouse_admin')
        ON CONFLICT (userid, roleid) DO NOTHING;
    END IF;
END $$;

-- Default storage zones
INSERT INTO storage_zones (code, name, type, description, is_active) VALUES
('MAIN-WH', 'Hauptlager', 'warehouse', 'Primärer Lagerstandort', TRUE),
('STAGE', 'Staging-Bereich', 'stage', 'Bereich für Job-Vorbereitung', TRUE)
ON CONFLICT (code) DO NOTHING;

-- Default label template
INSERT INTO label_templates (name, description, template_type, width_mm, height_mm, is_default) VALUES
('Standard Geräte-Label', 'Standard Geräteetikett 62x29mm', 'device', 62, 29, TRUE)
ON CONFLICT (name) DO NOTHING;

-- Default count types for accessories/consumables
INSERT INTO count_types (name, abbreviation, is_decimal) VALUES
('Stück', 'Stk', FALSE),
('Kilogramm', 'kg', TRUE),
('Liter', 'L', TRUE),
('Meter', 'm', TRUE),
('Quadratmeter', 'm²', TRUE)
ON CONFLICT (name) DO NOTHING;

-- Default cable connectors
INSERT INTO cable_connectors (name, abbreviation, gender) VALUES
('Schuko', 'SCH', 'male'),
('Schuko Kupplung', 'SCH', 'female'),
('CEE 16A blau', 'CEE16', 'male'),
('CEE 16A blau Kupplung', 'CEE16', 'female'),
('CEE 32A rot', 'CEE32', 'male'),
('CEE 32A rot Kupplung', 'CEE32', 'female'),
('CEE 63A rot', 'CEE63', 'male'),
('CEE 63A rot Kupplung', 'CEE63', 'female'),
('CEE 125A rot', 'CEE125', 'male'),
('CEE 125A rot Kupplung', 'CEE125', 'female'),
('XLR 3-pol', 'XLR3', 'male'),
('XLR 3-pol Kupplung', 'XLR3', 'female'),
('XLR 5-pol', 'XLR5', 'male'),
('XLR 5-pol Kupplung', 'XLR5', 'female'),
('Powercon', 'PWC', 'male'),
('Powercon TRUE1', 'PWC1', 'male'),
('Socapex', 'SOC', 'male'),
('Socapex Kupplung', 'SOC', 'female'),
('HAN 16E', 'HAN16', 'male'),
('HAN 16E Kupplung', 'HAN16', 'female'),
('speakON 2-pol', 'NL2', 'male'),
('speakON 4-pol', 'NL4', 'male'),
('speakON 8-pol', 'NL8', 'male'),
('Klinke 6.3mm mono', 'TS', 'male'),
('Klinke 6.3mm stereo', 'TRS', 'male'),
('RJ45', 'RJ45', 'male'),
('etherCON', 'eCON', 'male')
ON CONFLICT DO NOTHING;

-- Default cable types
INSERT INTO cable_types (name) VALUES
('Strom'),
('Audio'),
('DMX'),
('Netzwerk'),
('Video'),
('Multicore'),
('Hybrid')
ON CONFLICT DO NOTHING;

-- Default company settings (empty template)
INSERT INTO company_settings (company_name, country, currency, default_tax_rate) 
VALUES ('Meine Firma', 'Deutschland', 'EUR', 19.00)
ON CONFLICT DO NOTHING;

-- Default LED settings
INSERT INTO app_settings (scope, key, value, description) VALUES
('warehousecore', 'led.single_bin.default', '{"color": "#FF7A00", "pattern": "breathe", "intensity": 180}', 'Default LED highlighting settings for single bins')
ON CONFLICT (scope, key) DO NOTHING;

-- =============================================================================
-- PART 5: INDEXES AND CONSTRAINTS
-- =============================================================================

-- Performance indexes for common queries
CREATE INDEX IF NOT EXISTS idx_jobs_active ON jobs(statusid) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_devices_available ON devices(status) WHERE status = 'free';

-- =============================================================================
-- INITIALIZATION COMPLETE
-- =============================================================================
-- Default login: admin / admin
-- User will be forced to change password on first login
-- =============================================================================
