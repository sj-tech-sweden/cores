-- RentalCore PostgreSQL Schema
-- This is a PostgreSQL-compatible version of the RentalCore schema

-- Customers table
CREATE TABLE IF NOT EXISTS customers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(50),
    address TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(name);
CREATE INDEX IF NOT EXISTS idx_customers_email ON customers(email);

-- Status table
CREATE TABLE IF NOT EXISTS statuses (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    color VARCHAR(7) DEFAULT '#007bff'
);
CREATE INDEX IF NOT EXISTS idx_statuses_name ON statuses(name);

-- Jobs table
CREATE TABLE IF NOT EXISTS jobs (
    id SERIAL PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(id),
    status_id INT NOT NULL REFERENCES statuses(id),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    start_date DATE,
    end_date DATE,
    revenue DECIMAL(10,2) DEFAULT 0.00,
    job_code VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL
);
CREATE INDEX IF NOT EXISTS idx_jobs_customer ON jobs(customer_id);
CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs(status_id);
CREATE INDEX IF NOT EXISTS idx_jobs_dates ON jobs(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_jobs_revenue ON jobs(revenue);
CREATE INDEX IF NOT EXISTS idx_jobs_title ON jobs(title);
CREATE INDEX IF NOT EXISTS idx_jobs_deleted_at ON jobs(deleted_at);
CREATE INDEX IF NOT EXISTS idx_jobs_job_code ON jobs(job_code);

-- Devices table
CREATE TABLE IF NOT EXISTS devices (
    id SERIAL PRIMARY KEY,
    serial_no VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(100),
    price DECIMAL(10,2) DEFAULT 0.00,
    available BOOLEAN DEFAULT TRUE,
    label_path VARCHAR(512),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_devices_serial ON devices(serial_no);
CREATE INDEX IF NOT EXISTS idx_devices_name ON devices(name);
CREATE INDEX IF NOT EXISTS idx_devices_category ON devices(category);
CREATE INDEX IF NOT EXISTS idx_devices_available ON devices(available);

-- Products table
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(100),
    price DECIMAL(10,2) DEFAULT 0.00,
    active BOOLEAN DEFAULT TRUE,
    website_visible BOOLEAN DEFAULT FALSE,
    website_description TEXT,
    website_image_url VARCHAR(512),
    website_sort_order INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_products_name ON products(name);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);
CREATE INDEX IF NOT EXISTS idx_products_active ON products(active);

-- Job-Device relationship table
CREATE TABLE IF NOT EXISTS job_devices (
    id SERIAL PRIMARY KEY,
    job_id INT NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    device_id INT NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    price DECIMAL(10,2) DEFAULT 0.00,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    removed_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_job_devices_job ON job_devices(job_id);
CREATE INDEX IF NOT EXISTS idx_job_devices_device ON job_devices(device_id);
CREATE INDEX IF NOT EXISTS idx_job_devices_assigned ON job_devices(assigned_at);
CREATE INDEX IF NOT EXISTS idx_job_devices_removed ON job_devices(removed_at);
CREATE UNIQUE INDEX IF NOT EXISTS unique_active_assignment ON job_devices(job_id, device_id, removed_at) WHERE removed_at IS NULL;

-- Users table (for auth)
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    is_admin BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    last_login TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_active ON users(is_active);

-- Sessions table
CREATE TABLE IF NOT EXISTS sessions (
    id VARCHAR(255) PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    data TEXT,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_expires ON sessions(expires_at);

-- User preferences table
CREATE TABLE IF NOT EXISTS user_preferences (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    preference_key VARCHAR(100) NOT NULL,
    preference_value TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, preference_key)
);

-- Cases table (for equipment cases)
CREATE TABLE IF NOT EXISTS cases (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    barcode VARCHAR(255),
    rfid_tag VARCHAR(255),
    status VARCHAR(50) DEFAULT 'available',
    zone_id INT,
    capacity INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_cases_barcode ON cases(barcode);
CREATE INDEX IF NOT EXISTS idx_cases_status ON cases(status);
CREATE INDEX IF NOT EXISTS idx_cases_zone ON cases(zone_id);

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

-- Insert default statuses
INSERT INTO statuses (name, description, color) VALUES
('Planning', 'Job is in planning phase', '#6c757d'),
('Active', 'Job is currently active', '#28a745'),
('Completed', 'Job has been completed', '#007bff'),
('Cancelled', 'Job has been cancelled', '#dc3545'),
('On Hold', 'Job is temporarily on hold', '#ffc107')
ON CONFLICT (name) DO NOTHING;

-- RBAC Roles table
CREATE TABLE IF NOT EXISTS roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    is_system BOOLEAN DEFAULT FALSE,
    permissions TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User Roles junction table
CREATE TABLE IF NOT EXISTS user_roles (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id INT NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    assigned_by INT REFERENCES users(id) ON DELETE SET NULL,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, role_id)
);
CREATE INDEX IF NOT EXISTS idx_user_roles_user ON user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_role ON user_roles(role_id);

-- Audit logs table
CREATE TABLE IF NOT EXISTS audit_logs (
    id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(100),
    entity_id INT,
    old_value TEXT,
    new_value TEXT,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_created ON audit_logs(created_at);

-- Default admin user (password: admin123 - CHANGE IN PRODUCTION!)
-- Password hash is bcrypt of 'admin123'
INSERT INTO users (username, email, password_hash, first_name, last_name, is_admin, is_active)
VALUES ('admin', 'admin@example.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'Admin', 'User', TRUE, TRUE)
ON CONFLICT (username) DO NOTHING;

-- Insert admin role
INSERT INTO roles (name, description, is_system, permissions) VALUES
('admin', 'Full system administrator', TRUE, '["*"]'),
('user', 'Standard user', TRUE, '["read", "write"]'),
('viewer', 'Read-only access', TRUE, '["read"]')
ON CONFLICT (name) DO NOTHING;
-- WarehouseCore PostgreSQL Schema
-- This is a PostgreSQL-compatible version of the WarehouseCore additional tables

-- Storage zone types (simulating ENUM)
CREATE TYPE zone_type AS ENUM ('shelf', 'rack', 'case', 'vehicle', 'stage', 'warehouse', 'other');

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

-- Add zone reference to cases table if needed
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'cases' AND column_name = 'zone_id') THEN
        ALTER TABLE cases ADD COLUMN zone_id INT NULL;
    END IF;
END $$;

-- Device movements table
CREATE TABLE IF NOT EXISTS device_movements (
    movement_id SERIAL PRIMARY KEY,
    device_id INT NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    from_zone_id INT NULL REFERENCES storage_zones(zone_id) ON DELETE SET NULL,
    to_zone_id INT NULL REFERENCES storage_zones(zone_id) ON DELETE SET NULL,
    from_case_id INT NULL REFERENCES cases(id) ON DELETE SET NULL,
    to_case_id INT NULL REFERENCES cases(id) ON DELETE SET NULL,
    moved_by INT NULL REFERENCES users(id) ON DELETE SET NULL,
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
    device_id INT NULL REFERENCES devices(id) ON DELETE SET NULL,
    zone_id INT NULL REFERENCES storage_zones(zone_id) ON DELETE SET NULL,
    case_id INT NULL REFERENCES cases(id) ON DELETE SET NULL,
    scanner_id VARCHAR(100),
    scanned_by INT NULL REFERENCES users(id) ON DELETE SET NULL,
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
    device_id INT NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    reported_by INT NULL REFERENCES users(id) ON DELETE SET NULL,
    severity VARCHAR(20) NOT NULL DEFAULT 'minor',
    status VARCHAR(20) NOT NULL DEFAULT 'open',
    description TEXT NOT NULL,
    resolution TEXT,
    resolved_by INT NULL REFERENCES users(id) ON DELETE SET NULL,
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
    topic_suffix VARCHAR(100),
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

-- Product packages table (for website catalog)
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
    product_id INT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    quantity INT DEFAULT 1,
    is_optional BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_pkg_item_package ON product_package_items(package_id);
CREATE INDEX IF NOT EXISTS idx_pkg_item_product ON product_package_items(product_id);

-- Product dependencies table
CREATE TABLE IF NOT EXISTS product_dependencies (
    id SERIAL PRIMARY KEY,
    product_id INT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    required_product_id INT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    dependency_type VARCHAR(50) DEFAULT 'requires',
    quantity INT DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(product_id, required_product_id)
);
CREATE INDEX IF NOT EXISTS idx_dep_product ON product_dependencies(product_id);
CREATE INDEX IF NOT EXISTS idx_dep_required ON product_dependencies(required_product_id);

-- API Keys table
CREATE TABLE IF NOT EXISTS api_keys (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    key_hash VARCHAR(255) NOT NULL UNIQUE,
    key_prefix VARCHAR(20) NOT NULL,
    user_id INT REFERENCES users(id) ON DELETE CASCADE,
    permissions TEXT DEFAULT '[]',
    is_active BOOLEAN DEFAULT TRUE,
    expires_at TIMESTAMP,
    last_used_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_api_key_hash ON api_keys(key_hash);
CREATE INDEX IF NOT EXISTS idx_api_key_active ON api_keys(is_active);
CREATE INDEX IF NOT EXISTS idx_api_key_user ON api_keys(user_id);

-- Add device current_zone_id column if not exists
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'devices' AND column_name = 'current_zone_id') THEN
        ALTER TABLE devices ADD COLUMN current_zone_id INT NULL REFERENCES storage_zones(zone_id) ON DELETE SET NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'devices' AND column_name = 'current_case_id') THEN
        ALTER TABLE devices ADD COLUMN current_case_id INT NULL REFERENCES cases(id) ON DELETE SET NULL;
    END IF;
END $$;

-- Default storage zones
INSERT INTO storage_zones (code, name, type, description, is_active) VALUES
('MAIN-WH', 'Main Warehouse', 'warehouse', 'Primary warehouse location', TRUE),
('SHELF-A1', 'Shelf A1', 'shelf', 'Shelf section A1', TRUE),
('STAGE', 'Stage Area', 'stage', 'Event staging area', TRUE)
ON CONFLICT (code) DO NOTHING;

-- Default label template
INSERT INTO label_templates (name, description, template_type, width_mm, height_mm, is_default) VALUES
('Default Device Label', 'Standard device label 62x29mm', 'device', 62, 29, TRUE)
ON CONFLICT (name) DO NOTHING;
