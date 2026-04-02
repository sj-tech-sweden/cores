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

-- Early admin seed: ensures login works even if later migration steps fail
INSERT INTO users (username, email, password_hash, first_name, last_name, is_admin, is_active, force_password_change)
VALUES ('admin', 'admin@example.com', '$2a$10$AlHJcEvCFEXXAoxQ/S4XXeVy3coR0yHtTv0Pn3bHEH/z3t3jdGVru', 'System', 'Administrator', TRUE, TRUE, TRUE)
ON CONFLICT (username) DO NOTHING;

-- System user for background processes and audit logging
INSERT INTO users (userid, username, email, password_hash, first_name, last_name, is_admin, is_active)
VALUES (0, 'system', 'system@rentalcore.local', 'N/A', 'System', 'Internal', FALSE, FALSE)
ON CONFLICT (userid) DO NOTHING;

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

-- WebAuthn / Passkeys table
CREATE TABLE IF NOT EXISTS user_passkeys (
    passkey_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(userid) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    credential_id TEXT NOT NULL UNIQUE,
    public_key TEXT NOT NULL,
    sign_count BIGINT DEFAULT 0,
    aaguid VARCHAR(36),
    transports TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_user_passkeys_user ON user_passkeys(user_id);

-- Authentication attempts (login/2fa/passkey) logging
CREATE TABLE IF NOT EXISTS authentication_attempts (
    attempt_id SERIAL PRIMARY KEY,
    user_id INT NULL REFERENCES users(userid) ON DELETE SET NULL,
    method VARCHAR(50) NOT NULL,
    success BOOLEAN NOT NULL DEFAULT FALSE,
    ip_address VARCHAR(45),
    user_agent TEXT,
    attempted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    failure_reason TEXT
);
CREATE INDEX IF NOT EXISTS idx_auth_attempts_user ON authentication_attempts(user_id);
 
-- Enhanced user sessions table (from rentalcore migrations)
CREATE TABLE IF NOT EXISTS user_sessions (
    session_id VARCHAR(255) PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(userid) ON DELETE CASCADE,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_active TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    device_info JSONB
);
CREATE INDEX IF NOT EXISTS idx_user_sessions_user ON user_sessions(user_id);

-- WebAuthn sessions table (passkey flows)
CREATE TABLE IF NOT EXISTS webauthn_sessions (
    session_id VARCHAR(255) PRIMARY KEY,
    user_id INT NOT NULL DEFAULT 0,
    challenge VARCHAR(255) NOT NULL,
    session_type VARCHAR(50) NOT NULL,
    session_data TEXT,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_webauthn_sessions_user ON webauthn_sessions(user_id);

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

-- Digital signatures table
CREATE TABLE IF NOT EXISTS digital_signatures (
    signature_id SERIAL PRIMARY KEY,
    document_id INT,
    signed_by INT REFERENCES users(userid) ON DELETE SET NULL,
    signature_data TEXT,
    signed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_valid BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_digital_signatures_document ON digital_signatures(document_id);
CREATE INDEX IF NOT EXISTS idx_digital_signatures_user ON digital_signatures(signed_by);

-- Documents table for file/attachment storage
CREATE TABLE IF NOT EXISTS documents (
    "documentID" SERIAL PRIMARY KEY,
    "entityType" VARCHAR(50) NOT NULL CHECK ("entityType" IN ('job', 'device', 'customer', 'user', 'system')),
    "entityID" VARCHAR(255) NOT NULL,
    "filename" VARCHAR(255) NOT NULL,
    "originalFilename" VARCHAR(255) NOT NULL,
    "filePath" VARCHAR(512) NOT NULL,
    "fileSize" BIGINT NOT NULL,
    "mimeType" VARCHAR(100) NOT NULL,
    "documentType" VARCHAR(50) NOT NULL CHECK ("documentType" IN ('contract', 'manual', 'photo', 'invoice', 'receipt', 'signature', 'other')),
    "description" TEXT,
    "uploadedBy" INT REFERENCES users(userid) ON DELETE SET NULL,
    "uploadedAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "isPublic" BOOLEAN DEFAULT FALSE,
    "version" INT DEFAULT 1,
    "parent_documentID" INT REFERENCES documents("documentID") ON DELETE SET NULL,
    "checksum" VARCHAR(32),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_documents_entity ON documents("entityType", "entityID");
CREATE INDEX IF NOT EXISTS idx_documents_uploaded_by ON documents("uploadedBy");
CREATE INDEX IF NOT EXISTS idx_documents_uploaded_at ON documents("uploadedAt");
CREATE INDEX IF NOT EXISTS idx_documents_document_type ON documents("documentType");
CREATE INDEX IF NOT EXISTS idx_documents_checksum ON documents("checksum");

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

-- WarehouseCore compatibility: some code paths still use k/v column names
ALTER TABLE app_settings ADD COLUMN IF NOT EXISTS k VARCHAR(100);
ALTER TABLE app_settings ADD COLUMN IF NOT EXISTS v TEXT;
UPDATE app_settings SET k = key WHERE k IS NULL;
-- Ensure we update the compatibility column `v` in a way that handles
-- existing deployments where `v` may already be JSONB.
DO $$
DECLARE
    coltype TEXT;
BEGIN
    SELECT format_type(a.atttypid, a.atttypmod)
      INTO coltype
    FROM pg_attribute a
    WHERE a.attrelid = 'app_settings'::regclass
      AND a.attname = 'v'
      AND NOT a.attisdropped;

    IF coltype = 'jsonb' THEN
        EXECUTE 'UPDATE app_settings SET v = value::jsonb WHERE v IS NULL';
    ELSE
        EXECUTE 'UPDATE app_settings SET v = value WHERE v IS NULL';
    END IF;
END;
$$;
CREATE UNIQUE INDEX IF NOT EXISTS idx_app_settings_scope_k ON app_settings(scope, k);

CREATE OR REPLACE FUNCTION sync_app_settings_compat()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.key IS NULL AND NEW.k IS NOT NULL THEN
        NEW.key := NEW.k;
    ELSIF NEW.k IS NULL AND NEW.key IS NOT NULL THEN
        NEW.k := NEW.key;
    END IF;

    IF NEW.value IS NULL AND NEW.v IS NOT NULL THEN
        NEW.value := NEW.v;
    ELSIF NEW.v IS NULL AND NEW.value IS NOT NULL THEN
        NEW.v := NEW.value;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_app_settings_compat ON app_settings;
CREATE TRIGGER trg_sync_app_settings_compat
BEFORE INSERT OR UPDATE ON app_settings
FOR EACH ROW
EXECUTE FUNCTION sync_app_settings_compat();

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
ALTER TABLE count_types ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;

-- Products table
CREATE TABLE IF NOT EXISTS products (
    productid SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    categoryid INT REFERENCES categories(categoryid) ON DELETE SET NULL,
    subcategoryid VARCHAR(50) REFERENCES subcategories(subcategoryid) ON DELETE SET NULL,
    subbiercategoryid VARCHAR(50) REFERENCES subbiercategories(subbiercategoryid) ON DELETE SET NULL,
    manufacturerid INT REFERENCES manufacturer(manufacturerid) ON DELETE SET NULL,
    brandid INT REFERENCES brands(brandid) ON DELETE SET NULL,
    description TEXT,
    maintenanceinterval INT,
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
    website_visible BOOLEAN DEFAULT FALSE,
    website_thumbnail VARCHAR(512),
    website_images_json TEXT,
    website_description TEXT,
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
    label_path VARCHAR(512),
    current_zone_id INT,
    zone_id INT,
    current_case_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_devices_productid ON devices(productid);
CREATE INDEX IF NOT EXISTS idx_devices_status ON devices(status);
CREATE INDEX IF NOT EXISTS idx_devices_barcode ON devices(barcode);
CREATE INDEX IF NOT EXISTS idx_devices_serialnumber ON devices(serialnumber);
CREATE INDEX IF NOT EXISTS idx_devices_label_path ON devices(label_path);

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

-- Job history table (audit/history for job changes)
CREATE TABLE IF NOT EXISTS job_history (
    history_id SERIAL PRIMARY KEY,
    job_id INT NOT NULL REFERENCES jobs(jobid) ON DELETE CASCADE,
    user_id INT DEFAULT NULL REFERENCES users(userid) ON DELETE SET NULL,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    change_type VARCHAR(100) NOT NULL,
    field_name VARCHAR(255) DEFAULT NULL,
    old_value TEXT,
    new_value TEXT,
    description TEXT,
    ip_address VARCHAR(45) DEFAULT NULL,
    user_agent TEXT DEFAULT NULL
);
CREATE INDEX IF NOT EXISTS idx_job_history_job ON job_history(job_id);
CREATE INDEX IF NOT EXISTS idx_job_history_user ON job_history(user_id);
CREATE INDEX IF NOT EXISTS idx_job_history_changed_at ON job_history(changed_at);

-- Job editing sessions (track who is currently editing a job)
CREATE TABLE IF NOT EXISTS job_edit_sessions (
    job_id INT NOT NULL REFERENCES jobs(jobid) ON DELETE CASCADE,
    user_id INT NOT NULL REFERENCES users(userid) ON DELETE CASCADE,
    username VARCHAR(255) NOT NULL,
    display_name VARCHAR(255) NOT NULL,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (job_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_job_edit_sessions_last_seen ON job_edit_sessions(last_seen);

-- Job packages (packages attached to jobs)
CREATE TABLE IF NOT EXISTS job_packages (
    job_package_id SERIAL PRIMARY KEY,
    job_id INT NOT NULL REFERENCES jobs(jobid) ON DELETE CASCADE,
    package_id INT NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    custom_price DECIMAL(12,2) DEFAULT NULL,
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    added_by INT DEFAULT NULL REFERENCES users(userid) ON DELETE SET NULL,
    notes TEXT
);
CREATE INDEX IF NOT EXISTS idx_job_packages_job ON job_packages(job_id);
CREATE INDEX IF NOT EXISTS idx_job_packages_added_at ON job_packages(added_at);

-- Job attachments
CREATE TABLE IF NOT EXISTS job_attachments (
    attachment_id SERIAL PRIMARY KEY,
    job_id INT NOT NULL REFERENCES jobs(jobid) ON DELETE CASCADE,
    filename VARCHAR(512) NOT NULL,
    original_filename VARCHAR(512) NOT NULL,
    file_path VARCHAR(1024) NOT NULL,
    file_size BIGINT,
    mime_type VARCHAR(255),
    uploaded_by INT DEFAULT NULL REFERENCES users(userid) ON DELETE SET NULL,
    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_job_attachments_job ON job_attachments(job_id);

-- PDF OCR upload and extraction tables
CREATE TABLE IF NOT EXISTS pdf_uploads (
    upload_id SERIAL PRIMARY KEY,
    job_id INT REFERENCES jobs(jobid) ON DELETE SET NULL,
    document_id INT,
    original_filename VARCHAR(512) NOT NULL,
    stored_filename VARCHAR(512) NOT NULL,
    file_path VARCHAR(1024) NOT NULL,
    file_size BIGINT NOT NULL,
    mime_type VARCHAR(255) NOT NULL,
    file_hash VARCHAR(255),
    uploaded_by INT REFERENCES users(userid) ON DELETE SET NULL,
    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processing_status VARCHAR(20) NOT NULL DEFAULT 'pending',
    processing_started_at TIMESTAMP,
    processing_completed_at TIMESTAMP,
    error_message TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE INDEX IF NOT EXISTS idx_pdf_uploads_job ON pdf_uploads(job_id);
CREATE INDEX IF NOT EXISTS idx_pdf_uploads_status ON pdf_uploads(processing_status);

CREATE TABLE IF NOT EXISTS pdf_extractions (
    extraction_id SERIAL PRIMARY KEY,
    upload_id INT NOT NULL UNIQUE REFERENCES pdf_uploads(upload_id) ON DELETE CASCADE,
    raw_text TEXT,
    extracted_data JSONB,
    confidence_score DECIMAL(5,2),
    page_count INT DEFAULT 1,
    extraction_method VARCHAR(50) DEFAULT 'unipdf',
    extracted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    customer_name VARCHAR(255),
    customer_id INT REFERENCES customers(customerid) ON DELETE SET NULL,
    document_date DATE,
    document_number VARCHAR(100),
    parsed_total DECIMAL(10,2),
    discount_amount DECIMAL(10,2),
    discount_percent DECIMAL(5,2),
    total_amount DECIMAL(10,2),
    metadata JSONB
);
CREATE INDEX IF NOT EXISTS idx_pdf_extractions_customer ON pdf_extractions(customer_id);

CREATE TABLE IF NOT EXISTS pdf_extraction_items (
    item_id SERIAL PRIMARY KEY,
    extraction_id INT NOT NULL REFERENCES pdf_extractions(extraction_id) ON DELETE CASCADE,
    line_number INT,
    raw_product_text TEXT NOT NULL,
    quantity INT,
    unit_price DECIMAL(10,2),
    line_total DECIMAL(10,2),
    mapped_product_id INT REFERENCES products(productid) ON DELETE SET NULL,
    mapped_package_id INT,
    mapping_confidence DECIMAL(5,2),
    mapping_status VARCHAR(30) NOT NULL DEFAULT 'pending',
    user_notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_pdf_items_extraction ON pdf_extraction_items(extraction_id);
CREATE INDEX IF NOT EXISTS idx_pdf_items_product ON pdf_extraction_items(mapped_product_id);
CREATE INDEX IF NOT EXISTS idx_pdf_items_package ON pdf_extraction_items(mapped_package_id);
CREATE INDEX IF NOT EXISTS idx_pdf_items_status ON pdf_extraction_items(mapping_status);

DO $$
BEGIN
    IF to_regclass('public.pdf_extraction_items') IS NOT NULL
       AND to_regclass('public.product_packages') IS NOT NULL THEN
        BEGIN
            ALTER TABLE pdf_extraction_items
                ADD CONSTRAINT fk_pdf_items_package
                FOREIGN KEY (mapped_package_id)
                REFERENCES product_packages(package_id)
                ON DELETE SET NULL;
        EXCEPTION
            WHEN duplicate_object THEN NULL;
        END;
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS pdf_product_mappings (
    mapping_id SERIAL PRIMARY KEY,
    pdf_product_text TEXT NOT NULL,
    normalized_text TEXT,
    product_id INT NOT NULL REFERENCES products(productid) ON DELETE CASCADE,
    mapping_type VARCHAR(20) NOT NULL DEFAULT 'manual',
    confidence_score DECIMAL(5,2),
    usage_count INT NOT NULL DEFAULT 0,
    last_used_at TIMESTAMP,
    created_by INT REFERENCES users(userid) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE(pdf_product_text, product_id)
);
CREATE INDEX IF NOT EXISTS idx_pdf_mappings_text ON pdf_product_mappings(pdf_product_text);
CREATE INDEX IF NOT EXISTS idx_pdf_mappings_normalized ON pdf_product_mappings(normalized_text);
CREATE INDEX IF NOT EXISTS idx_pdf_mappings_product ON pdf_product_mappings(product_id);
CREATE INDEX IF NOT EXISTS idx_pdf_mappings_type ON pdf_product_mappings(mapping_type);

CREATE TABLE IF NOT EXISTS pdf_package_mappings (
    mapping_id SERIAL PRIMARY KEY,
    pdf_package_text TEXT NOT NULL,
    normalized_text TEXT,
    package_id INT NOT NULL,
    mapping_type VARCHAR(20) NOT NULL DEFAULT 'manual',
    confidence_score DECIMAL(5,2),
    usage_count INT NOT NULL DEFAULT 0,
    last_used_at TIMESTAMP,
    created_by INT REFERENCES users(userid) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE INDEX IF NOT EXISTS idx_pdf_package_mappings_text ON pdf_package_mappings(pdf_package_text);
CREATE INDEX IF NOT EXISTS idx_pdf_package_mappings_normalized ON pdf_package_mappings(normalized_text);
CREATE INDEX IF NOT EXISTS idx_pdf_package_mappings_package ON pdf_package_mappings(package_id);
CREATE INDEX IF NOT EXISTS idx_pdf_package_mappings_type ON pdf_package_mappings(mapping_type);

CREATE TABLE IF NOT EXISTS pdf_customer_mappings (
    mapping_id SERIAL PRIMARY KEY,
    pdf_customer_text TEXT NOT NULL,
    normalized_text TEXT,
    customer_id INT NOT NULL REFERENCES customers(customerid) ON DELETE CASCADE,
    mapping_type VARCHAR(20) NOT NULL DEFAULT 'manual',
    confidence_score DECIMAL(5,2),
    usage_count INT NOT NULL DEFAULT 0,
    last_used_at TIMESTAMP,
    created_by INT REFERENCES users(userid) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE INDEX IF NOT EXISTS idx_pdf_customer_mappings_text ON pdf_customer_mappings(pdf_customer_text);
CREATE INDEX IF NOT EXISTS idx_pdf_customer_mappings_normalized ON pdf_customer_mappings(normalized_text);
CREATE INDEX IF NOT EXISTS idx_pdf_customer_mappings_customer ON pdf_customer_mappings(customer_id);

CREATE TABLE IF NOT EXISTS pdf_mapping_events (
    event_id SERIAL PRIMARY KEY,
    extraction_id INT REFERENCES pdf_extractions(extraction_id) ON DELETE SET NULL,
    item_id INT REFERENCES pdf_extraction_items(item_id) ON DELETE SET NULL,
    pdf_product_text TEXT NOT NULL,
    normalized_text TEXT,
    product_id INT REFERENCES products(productid) ON DELETE SET NULL,
    package_id INT,
    created_by INT REFERENCES users(userid) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_pdf_mapping_events_item ON pdf_mapping_events(item_id);

-- Package -> Device mapping (from rental migrations)
CREATE TABLE IF NOT EXISTS package_devices (
    package_id INT NOT NULL,
    device_id VARCHAR(50) NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    custom_price DECIMAL(12,2) DEFAULT NULL,
    is_required BOOLEAN DEFAULT FALSE,
    notes TEXT,
    sort_order INT DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (package_id, device_id)
);
CREATE INDEX IF NOT EXISTS idx_package_devices_package ON package_devices(package_id);
CREATE INDEX IF NOT EXISTS idx_package_devices_device ON package_devices(device_id);

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
    cable_connectorsid SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    abbreviation VARCHAR(20),
    gender VARCHAR(10)
);

-- Cable types
CREATE TABLE IF NOT EXISTS cable_types (
    cable_typesid SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL
);

-- Cables table
CREATE TABLE IF NOT EXISTS cables (
    cableid SERIAL PRIMARY KEY,
    connector1 INT NOT NULL REFERENCES cable_connectors(cable_connectorsid) ON DELETE RESTRICT,
    connector2 INT NOT NULL REFERENCES cable_connectors(cable_connectorsid) ON DELETE RESTRICT,
    typ INT NOT NULL REFERENCES cable_types(cable_typesid) ON DELETE RESTRICT,
    length DECIMAL(10,2) NOT NULL,
    mm2 DECIMAL(10,2),
    name VARCHAR(255)
);
CREATE INDEX IF NOT EXISTS idx_cables_connector1 ON cables(connector1);
CREATE INDEX IF NOT EXISTS idx_cables_connector2 ON cables(connector2);
CREATE INDEX IF NOT EXISTS idx_cables_type ON cables(typ);

-- Ensure connector uniqueness to make seeding idempotent across runs
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_cable_connectors
    ON cable_connectors(name, abbreviation NULLS NOT DISTINCT, gender NULLS NOT DISTINCT);
-- Ensure cable types are unique to avoid duplicate seeds
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_cable_types ON cable_types(name);

-- Company settings table
CREATE TABLE IF NOT EXISTS "company_settings" (
    "id" SERIAL PRIMARY KEY,
    "company_name" VARCHAR(255),
    "address_line1" VARCHAR(255),
    "address_line2" VARCHAR(255),
    "city" VARCHAR(100),
    "state" VARCHAR(100),
    "postal_code" VARCHAR(20),
    "country" VARCHAR(100) DEFAULT 'Deutschland',
    "phone" VARCHAR(50),
    "email" VARCHAR(255),
    "website" VARCHAR(255),
    "tax_number" VARCHAR(100),
    "vat_number" VARCHAR(100),
    "logo_path" VARCHAR(512),
    "terms_and_conditions" TEXT,
    "invoice_prefix" VARCHAR(50) DEFAULT 'INV',
    "invoice_footer" TEXT,
    "default_tax_rate" DECIMAL(5,2) DEFAULT 19.00,
    "currency" VARCHAR(10) DEFAULT 'EUR',
    "bank_name" VARCHAR(255),
    "iban" VARCHAR(50),
    "bic" VARCHAR(20),
    "account_holder" VARCHAR(255),
    "ceo_name" VARCHAR(255),
    "register_court" VARCHAR(255),
    "register_number" VARCHAR(255),
    "footer_text" TEXT,
    "payment_terms_text" TEXT,
    "smtp_host" VARCHAR(255),
    "smtp_port" INTEGER,
    "smtp_username" VARCHAR(255),
    "smtp_password" VARCHAR(255),
    "smtp_from_email" VARCHAR(255),
    "smtp_from_name" VARCHAR(255),
    "smtp_use_tls" BOOLEAN DEFAULT TRUE,
    "brand_primary_color" VARCHAR(20),
    "brand_accent_color" VARCHAR(20),
    "brand_dark_mode" BOOLEAN DEFAULT TRUE,
    "brand_logo_url" VARCHAR(512),
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

-- User Profiles table
CREATE TABLE IF NOT EXISTS user_profiles (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL UNIQUE REFERENCES users(userid) ON DELETE CASCADE,
    display_name VARCHAR(150),
    avatar_url VARCHAR(512),
    prefs JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_user_profiles_user ON user_profiles(user_id);

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

-- Compatibility bridge for legacy queries comparing text with zone_type enum.
CREATE OR REPLACE FUNCTION text_eq_zone_type(lhs TEXT, rhs zone_type)
RETURNS BOOLEAN AS $$
SELECT lhs = rhs::text;
$$ LANGUAGE SQL IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION zone_type_eq_text(lhs zone_type, rhs TEXT)
RETURNS BOOLEAN AS $$
SELECT lhs::text = rhs;
$$ LANGUAGE SQL IMMUTABLE STRICT;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_operator
        WHERE oprname = '='
          AND oprleft = 'text'::regtype
          AND oprright = 'zone_type'::regtype
    ) THEN
        CREATE OPERATOR = (
            LEFTARG = text,
            RIGHTARG = zone_type,
            PROCEDURE = text_eq_zone_type
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_operator
        WHERE oprname = '='
          AND oprleft = 'zone_type'::regtype
          AND oprright = 'text'::regtype
    ) THEN
        CREATE OPERATOR = (
            LEFTARG = zone_type,
            RIGHTARG = text,
            PROCEDURE = zone_type_eq_text
        );
    END IF;
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

-- Zone types table (used by WarehouseCore)
CREATE TABLE IF NOT EXISTS zone_types (
        id SERIAL PRIMARY KEY,
        key TEXT NOT NULL,
        label TEXT NOT NULL,
        description TEXT,
        default_led_pattern TEXT DEFAULT 'breathe',
        default_led_color TEXT DEFAULT '#FF7A00',
        default_intensity INTEGER DEFAULT 180,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Seed basic zone types
INSERT INTO zone_types (id, key, label, description, default_led_pattern, default_led_color, default_intensity, created_at, updated_at) VALUES
    (1,'shelf','Shelf','Individual shelf / storage shelf','breathe','#FF4500',255,'2025-10-19 11:21:29','2025-12-01 17:29:10'),
    (4,'gitterbox','Gitter box','Wire mesh container','solid','#0088FF',200,'2025-10-19 11:21:29','2025-10-19 11:21:29'),
    (19,'rack','Rack','Rack or shelving unit','breathe','#FFAA00',240,'2025-12-01 17:29:10','2025-12-01 17:29:10'),
    (20,'warehouse','Warehouse','Warehouse hall or storage room','breathe','#00AA00',200,'2025-12-01 17:35:27','2025-12-01 17:35:27'),
    (21,'vehicle','Vehicle','Transport vehicle or trailer','breathe','#0088FF',220,'2025-12-01 17:35:35','2025-12-01 17:35:35'),
    (23,'case','Case','Transport case or flight case','breathe','#FFAA00',200,'2025-12-01 17:35:35','2025-12-01 17:35:35'),
    (24,'other','Other','Other storage types','breathe','#808080',180,'2025-12-01 17:35:35','2025-12-01 17:35:35')
ON CONFLICT (id) DO NOTHING;


-- Add zone reference to devices and cases
ALTER TABLE devices ADD COLUMN IF NOT EXISTS current_zone_id INT REFERENCES storage_zones(zone_id) ON DELETE SET NULL;
ALTER TABLE cases ADD COLUMN IF NOT EXISTS zone_id INT REFERENCES storage_zones(zone_id) ON DELETE SET NULL;

-- Product locations table (consumables/accessories by zone)
CREATE TABLE IF NOT EXISTS product_locations (
    id SERIAL PRIMARY KEY,
    product_id INT NOT NULL REFERENCES products(productid) ON DELETE CASCADE,
    zone_id INT NOT NULL REFERENCES storage_zones(zone_id) ON DELETE CASCADE,
    quantity NUMERIC(12,3) NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (product_id, zone_id)
);
CREATE INDEX IF NOT EXISTS idx_product_locations_product ON product_locations(product_id);
CREATE INDEX IF NOT EXISTS idx_product_locations_zone ON product_locations(zone_id);

-- Device movements table
CREATE TABLE IF NOT EXISTS device_movements (
    movement_id SERIAL PRIMARY KEY,
    device_id VARCHAR(50) NOT NULL REFERENCES devices(deviceid) ON DELETE CASCADE,
    from_zone_id INT NULL REFERENCES storage_zones(zone_id) ON DELETE SET NULL,
    to_zone_id INT NULL REFERENCES storage_zones(zone_id) ON DELETE SET NULL,
    from_case_id INT NULL REFERENCES cases(caseid) ON DELETE SET NULL,
    to_case_id INT NULL REFERENCES cases(caseid) ON DELETE SET NULL,
    from_job_id INT NULL REFERENCES jobs(jobid) ON DELETE SET NULL,
    to_job_id INT NULL REFERENCES jobs(jobid) ON DELETE SET NULL,
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
    scan_code VARCHAR(255) NOT NULL,
    device_id VARCHAR(50) NULL REFERENCES devices(deviceid) ON DELETE SET NULL,
    action VARCHAR(50) NOT NULL DEFAULT 'identify',
    job_id INT NULL,
    zone_id INT NULL REFERENCES storage_zones(zone_id) ON DELETE SET NULL,
    user_id INT NULL REFERENCES users(userid) ON DELETE SET NULL,
    success BOOLEAN NOT NULL DEFAULT TRUE,
    error_message TEXT,
    ip_address VARCHAR(100),
    user_agent TEXT,
    timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_scan_device ON scan_events(device_id);
CREATE INDEX IF NOT EXISTS idx_scan_zone ON scan_events(zone_id);
CREATE INDEX IF NOT EXISTS idx_scan_action ON scan_events(action);
CREATE INDEX IF NOT EXISTS idx_scan_timestamp ON scan_events(timestamp);
CREATE INDEX IF NOT EXISTS idx_scan_code ON scan_events(scan_code);

-- Inspection schedules table (compatibility for background inspection counters)
CREATE TABLE IF NOT EXISTS inspection_schedules (
    id SERIAL PRIMARY KEY,
    device_id VARCHAR(50) NULL REFERENCES devices(deviceid) ON DELETE SET NULL,
    next_inspection TIMESTAMP NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE inspection_schedules
    ADD COLUMN IF NOT EXISTS product_id INT NULL REFERENCES products(productid) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS inspection_type VARCHAR(50) NOT NULL DEFAULT 'routine',
    ADD COLUMN IF NOT EXISTS interval_days INT NOT NULL DEFAULT 30,
    ADD COLUMN IF NOT EXISTS last_inspection TIMESTAMP NULL;

CREATE INDEX IF NOT EXISTS idx_inspection_schedules_next_inspection ON inspection_schedules(next_inspection);
CREATE INDEX IF NOT EXISTS idx_inspection_schedules_is_active ON inspection_schedules(is_active);
CREATE INDEX IF NOT EXISTS idx_inspection_schedules_product_id ON inspection_schedules(product_id);

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

ALTER TABLE defect_reports
    ADD COLUMN IF NOT EXISTS title VARCHAR(200) NOT NULL DEFAULT 'Untitled Defect Report',
    ADD COLUMN IF NOT EXISTS assigned_to INT NULL REFERENCES users(userid) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS reported_at TIMESTAMP NULL,
    ADD COLUMN IF NOT EXISTS repair_cost NUMERIC(10,2) NULL,
    ADD COLUMN IF NOT EXISTS repaired_at TIMESTAMP NULL,
    ADD COLUMN IF NOT EXISTS closed_at TIMESTAMP NULL,
    ADD COLUMN IF NOT EXISTS repair_notes TEXT NULL;

UPDATE defect_reports SET reported_at = created_at WHERE reported_at IS NULL;

ALTER TABLE defect_reports
    ALTER COLUMN reported_at SET NOT NULL,
    ALTER COLUMN reported_at SET DEFAULT CURRENT_TIMESTAMP;

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

-- LED controller ↔ zone types junction table
CREATE TABLE IF NOT EXISTS led_controller_zone_types (
    controller_id INT NOT NULL REFERENCES led_controllers(id) ON DELETE CASCADE,
    zone_type_id INT NOT NULL REFERENCES zone_types(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (controller_id, zone_type_id)
);

-- Example mapping (keeps parity with rentalcore seeds)
INSERT INTO led_controller_zone_types (controller_id, zone_type_id, created_at)
SELECT 31, 1, CURRENT_TIMESTAMP
WHERE EXISTS (SELECT 1 FROM led_controllers WHERE id = 31)
    AND EXISTS (SELECT 1 FROM zone_types WHERE id = 1)
    AND NOT EXISTS (
            SELECT 1
            FROM led_controller_zone_types
            WHERE controller_id = 31 AND zone_type_id = 1
    );

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

-- WarehouseCore compatibility: legacy code paths expect package_id
ALTER TABLE product_packages ADD COLUMN IF NOT EXISTS package_id INT;
ALTER TABLE product_packages ADD COLUMN IF NOT EXISTS product_id INT;
UPDATE product_packages SET package_id = id WHERE package_id IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_product_packages_package_id ON product_packages(package_id);
CREATE INDEX IF NOT EXISTS idx_product_packages_product_id ON product_packages(product_id);

DO $$
BEGIN
    IF to_regclass('public.pdf_package_mappings') IS NOT NULL
       AND to_regclass('public.product_packages') IS NOT NULL THEN
        BEGIN
            ALTER TABLE pdf_package_mappings
                ADD CONSTRAINT fk_pdf_package_mappings_package
                FOREIGN KEY (package_id)
                REFERENCES product_packages(package_id)
                ON DELETE CASCADE;
        EXCEPTION
            WHEN duplicate_object THEN NULL;
        END;
    END IF;

    IF to_regclass('public.pdf_mapping_events') IS NOT NULL
       AND to_regclass('public.product_packages') IS NOT NULL THEN
        BEGIN
            ALTER TABLE pdf_mapping_events
                ADD CONSTRAINT fk_pdf_mapping_events_package
                FOREIGN KEY (package_id)
                REFERENCES product_packages(package_id)
                ON DELETE SET NULL;
        EXCEPTION
            WHEN duplicate_object THEN NULL;
        END;
    END IF;
END $$;

CREATE OR REPLACE FUNCTION sync_product_packages_ids()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.id IS NULL AND NEW.package_id IS NOT NULL THEN
        NEW.id := NEW.package_id;
    ELSIF NEW.package_id IS NULL AND NEW.id IS NOT NULL THEN
        NEW.package_id := NEW.id;
    END IF;

    -- Keep legacy product_id column aligned when available callers provide only one side.
    IF NEW.product_id IS NULL AND NEW.id IS NOT NULL THEN
        NEW.product_id := NEW.id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_product_packages_ids ON product_packages;
CREATE TRIGGER trg_sync_product_packages_ids
BEFORE INSERT OR UPDATE ON product_packages
FOR EACH ROW
EXECUTE FUNCTION sync_product_packages_ids();

-- Product package items junction table
CREATE TABLE IF NOT EXISTS product_package_items (
    package_item_id SERIAL PRIMARY KEY,
    package_id INT NOT NULL REFERENCES product_packages(id) ON DELETE CASCADE,
    product_id INT NOT NULL REFERENCES products(productid) ON DELETE CASCADE,
    quantity INT DEFAULT 1,
    is_optional BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_pkg_item_package ON product_package_items(package_id);
CREATE INDEX IF NOT EXISTS idx_pkg_item_product ON product_package_items(product_id);

-- Product dependencies (accessories/consumables required by a product)
CREATE TABLE IF NOT EXISTS product_dependencies (
    id SERIAL PRIMARY KEY,
    product_id INT NOT NULL REFERENCES products(productid) ON DELETE CASCADE,
    dependency_product_id INT NOT NULL REFERENCES products(productid) ON DELETE CASCADE,
    is_optional BOOLEAN DEFAULT FALSE,
    default_quantity INT DEFAULT 1,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(product_id, dependency_product_id)
);
CREATE INDEX IF NOT EXISTS idx_product_deps_product ON product_dependencies(product_id);
CREATE INDEX IF NOT EXISTS idx_product_deps_dep ON product_dependencies(dependency_product_id);

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

-- WarehouseCore compatibility: legacy code paths expect equipment_id and supplier_name
ALTER TABLE rental_equipment ADD COLUMN IF NOT EXISTS equipment_id INT;
ALTER TABLE rental_equipment ADD COLUMN IF NOT EXISTS supplier_name VARCHAR(255);
ALTER TABLE rental_equipment ADD COLUMN IF NOT EXISTS product_name VARCHAR(255);
ALTER TABLE rental_equipment ADD COLUMN IF NOT EXISTS created_by INT;
UPDATE rental_equipment SET equipment_id = id WHERE equipment_id IS NULL;
UPDATE rental_equipment SET supplier_name = supplier WHERE supplier_name IS NULL;
UPDATE rental_equipment SET product_name = name WHERE product_name IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_rental_equipment_equipment_id ON rental_equipment(equipment_id);
CREATE INDEX IF NOT EXISTS idx_rental_equipment_supplier_name ON rental_equipment(supplier_name);
CREATE INDEX IF NOT EXISTS idx_rental_equipment_product_name ON rental_equipment(product_name);

-- WarehouseCore compatibility: legacy case queries expect label_path
ALTER TABLE cases ADD COLUMN IF NOT EXISTS label_path VARCHAR(512);
CREATE INDEX IF NOT EXISTS idx_cases_label_path ON cases(label_path);

-- WarehouseCore compatibility: legacy product-device queries expect devices.label_path
ALTER TABLE devices ADD COLUMN IF NOT EXISTS label_path VARCHAR(512);
CREATE INDEX IF NOT EXISTS idx_devices_label_path ON devices(label_path);

CREATE OR REPLACE FUNCTION sync_rental_equipment_compat()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.id IS NULL AND NEW.equipment_id IS NOT NULL THEN
        NEW.id := NEW.equipment_id;
    ELSIF NEW.equipment_id IS NULL AND NEW.id IS NOT NULL THEN
        NEW.equipment_id := NEW.id;
    END IF;

    IF NEW.supplier IS NULL AND NEW.supplier_name IS NOT NULL THEN
        NEW.supplier := NEW.supplier_name;
    ELSIF NEW.supplier_name IS NULL AND NEW.supplier IS NOT NULL THEN
        NEW.supplier_name := NEW.supplier;
    END IF;

    IF NEW.name IS NULL AND NEW.product_name IS NOT NULL THEN
        NEW.name := NEW.product_name;
    ELSIF NEW.product_name IS NULL AND NEW.name IS NOT NULL THEN
        NEW.product_name := NEW.name;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_rental_equipment_compat ON rental_equipment;
CREATE TRIGGER trg_sync_rental_equipment_compat
BEFORE INSERT OR UPDATE ON rental_equipment
FOR EACH ROW
EXECUTE FUNCTION sync_rental_equipment_compat();

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

-- Financial transactions table (payments, refunds, adjustments)
CREATE TABLE IF NOT EXISTS financial_transaction (
    transaction_id SERIAL PRIMARY KEY,
    job_id INT NULL REFERENCES jobs(jobid) ON DELETE SET NULL,
    invoice_id INT NULL,
    customer_id INT NULL REFERENCES customers(customerid) ON DELETE SET NULL,
    amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    currency VARCHAR(10) DEFAULT 'EUR',
    transaction_type VARCHAR(50) NOT NULL DEFAULT 'payment', -- legacy column
    "type" VARCHAR(50) NOT NULL DEFAULT 'payment', -- compatible column used by queries
    transaction_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    due_date TIMESTAMP NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    payment_method VARCHAR(100),
    reference VARCHAR(255),
    processed_at TIMESTAMP NULL,
    metadata JSONB,
    created_by INT NULL REFERENCES users(userid) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_fin_tx_job ON financial_transaction(job_id);
CREATE INDEX IF NOT EXISTS idx_fin_tx_customer ON financial_transaction(customer_id);
CREATE INDEX IF NOT EXISTS idx_fin_tx_status ON financial_transaction(status);
CREATE INDEX IF NOT EXISTS idx_fin_tx_due_date ON financial_transaction(due_date);

-- Compatibility table expected by admin/audit UI queries
CREATE TABLE IF NOT EXISTS audit_events (
    id SERIAL PRIMARY KEY,
    event_type VARCHAR(100) NOT NULL,
    object_type VARCHAR(100),
    object_id VARCHAR(255),
    user_id INT,
    username VARCHAR(100),
    action VARCHAR(100) NOT NULL,
    old_values TEXT,
    new_values TEXT,
    ip_address VARCHAR(45),
    user_agent TEXT,
    session_id VARCHAR(255),
    context TEXT,
    event_hash VARCHAR(128),
    previous_hash VARCHAR(128),
    is_compliant BOOLEAN DEFAULT TRUE,
    retention_date TIMESTAMP,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE audit_events ADD COLUMN IF NOT EXISTS event_type VARCHAR(100);
ALTER TABLE audit_events ADD COLUMN IF NOT EXISTS object_type VARCHAR(100);
ALTER TABLE audit_events ADD COLUMN IF NOT EXISTS object_id VARCHAR(255);
ALTER TABLE audit_events ADD COLUMN IF NOT EXISTS username VARCHAR(100);
ALTER TABLE audit_events ADD COLUMN IF NOT EXISTS old_values TEXT;
ALTER TABLE audit_events ADD COLUMN IF NOT EXISTS new_values TEXT;
ALTER TABLE audit_events ADD COLUMN IF NOT EXISTS session_id VARCHAR(255);
ALTER TABLE audit_events ADD COLUMN IF NOT EXISTS context TEXT;
ALTER TABLE audit_events ADD COLUMN IF NOT EXISTS event_hash VARCHAR(128);
ALTER TABLE audit_events ADD COLUMN IF NOT EXISTS previous_hash VARCHAR(128);
ALTER TABLE audit_events ADD COLUMN IF NOT EXISTS is_compliant BOOLEAN DEFAULT TRUE;
ALTER TABLE audit_events ADD COLUMN IF NOT EXISTS retention_date TIMESTAMP;
ALTER TABLE audit_events ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE audit_events ALTER COLUMN old_values TYPE TEXT USING old_values::text;
ALTER TABLE audit_events ALTER COLUMN new_values TYPE TEXT USING new_values::text;
ALTER TABLE audit_events ALTER COLUMN context TYPE TEXT USING context::text;
CREATE INDEX IF NOT EXISTS idx_audit_events_timestamp ON audit_events(timestamp);
CREATE INDEX IF NOT EXISTS idx_audit_events_event_type ON audit_events(event_type);
CREATE INDEX IF NOT EXISTS idx_audit_events_object ON audit_events(object_type, object_id);
ALTER TABLE audit_events DROP CONSTRAINT IF EXISTS audit_events_user_id_fkey;

-- Data retention policies used by compliance module
CREATE TABLE IF NOT EXISTS retention_policies (
    id SERIAL PRIMARY KEY,
    document_type VARCHAR(100) NOT NULL UNIQUE,
    retention_years INT,
    retention_period_days INT,
    legal_basis TEXT NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    auto_delete BOOLEAN DEFAULT FALSE,
    auto_delete_after TIMESTAMP,
    policy_description TEXT,
    effective_from TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    effective_until TIMESTAMP,
    created_by INT REFERENCES users(userid) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE retention_policies ADD COLUMN IF NOT EXISTS retention_years INT;
ALTER TABLE retention_policies ADD COLUMN IF NOT EXISTS retention_period_days INT;
ALTER TABLE retention_policies ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE retention_policies ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;
ALTER TABLE retention_policies ADD COLUMN IF NOT EXISTS auto_delete_after TIMESTAMP;
ALTER TABLE retention_policies ADD COLUMN IF NOT EXISTS policy_description TEXT;
CREATE INDEX IF NOT EXISTS idx_retention_policies_doc_type ON retention_policies(document_type);

INSERT INTO retention_policies (id, document_type, retention_years, retention_period_days, legal_basis, description, is_active, auto_delete, policy_description)
VALUES
    (1, 'invoice_data', 10, 3650, 'HGB §257, AO §147', 'Retained for legal and tax purposes: invoice data - 10 years', TRUE, TRUE, 'Retained for legal and tax purposes: invoice data - 10 years'),
    (2, 'customer_data', 10, 3650, 'HGB §257, AO §147', 'Business correspondence and trade books - 10 years', TRUE, FALSE, 'Business correspondence and trade books - 10 years'),
    (3, 'payment_data', 6, 2190, 'HGB §257', 'Payment receipts and bank statements - 6 years', TRUE, TRUE, 'Payment receipts and bank statements - 6 years'),
    (4, 'contract_data', 10, 3650, 'BGB §195ff', 'Contract documentation - 10 years (warranty period)', TRUE, FALSE, 'Contract documentation - 10 years (warranty period)'),
    (5, 'tax_data', 10, 3650, 'AO §147', 'Tax-relevant documentation - 10 years', TRUE, TRUE, 'Tax-relevant documentation - 10 years'),
    (6, 'employee_data', 3, 1095, 'GDPR Art. 5', 'Personnel records - 3 years after termination', TRUE, FALSE, 'Personnel records - 3 years after termination'),
    (7, 'marketing_consent', 3, 1095, 'GDPR Art. 7', 'Marketing consent records - 3 years', TRUE, TRUE, 'Marketing consent records - 3 years'),
    (8, 'access_logs', 6, 2190, 'GDPR Art. 32', 'Access logs and audit trails - 6 years', TRUE, TRUE, 'Access logs and audit trails - 6 years'),
    (9, 'backup_data', 1, 365, 'GDPR Art. 32', 'Backup data - 1 year', TRUE, TRUE, 'Backup data - 1 year')
ON CONFLICT (id) DO NOTHING;

-- Invoice template storage used by invoice rendering UI
CREATE TABLE IF NOT EXISTS invoice_templates (
    template_id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    html_template TEXT NOT NULL DEFAULT '',
    css_styles TEXT,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_by INT REFERENCES users(userid) ON DELETE SET NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_invoice_templates_default ON invoice_templates(is_default);
CREATE INDEX IF NOT EXISTS idx_invoice_templates_name ON invoice_templates(name);


-- Default job statuses
INSERT INTO status (status, description, color, sort_order) VALUES
('Planning', 'Job is in planning phase', '#6c757d', 1),
('Preparation', 'Job is being prepared', '#17a2b8', 2),
('Active', 'Job is currently active', '#28a745', 3),
('Completed', 'Job has been completed', '#007bff', 4),
('Invoiced', 'Job has been invoiced', '#6610f2', 5),
('Cancelled', 'Job has been cancelled', '#dc3545', 6),
('Paused', 'Job is temporarily paused', '#ffc107', 7)
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

-- Ensure default preferences exist for the admin user
DO $$
DECLARE
    admin_user_id INT;
BEGIN
    SELECT userid INTO admin_user_id FROM users WHERE username = 'admin';
    IF admin_user_id IS NOT NULL THEN
        INSERT INTO user_preferences (user_id, language, theme, time_zone, date_format, time_format, items_per_page, default_view, created_at, updated_at)
        VALUES (admin_user_id, 'de', 'dark', 'Europe/Berlin', 'DD.MM.YYYY', '24h', 25, 'list', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        ON CONFLICT (user_id) DO NOTHING;
    END IF;
END $$;

-- Ensure default dashboard widgets exist for admin
DO $$
DECLARE
    admin_user_id INT;
BEGIN
    SELECT userid INTO admin_user_id FROM users WHERE username = 'admin';
    IF admin_user_id IS NOT NULL THEN
        INSERT INTO user_dashboard_widgets (user_id, widgets, created_at, updated_at)
        VALUES (admin_user_id, '{"layout":[{"widget":"quick_actions","x":0,"y":0},{"widget":"recent_jobs","x":1,"y":0}]}', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        ON CONFLICT (user_id) DO NOTHING;
    END IF;
END $$;

-- Default storage zones
INSERT INTO storage_zones (code, name, type, description, is_active) VALUES
('MAIN-WH', 'Main warehouse', 'warehouse', 'Primary storage location', TRUE),
('STAGE', 'Staging area', 'stage', 'Job preparation area', TRUE)
ON CONFLICT (code) DO NOTHING;

-- Default label template
INSERT INTO label_templates (name, description, template_type, width_mm, height_mm, is_default) VALUES
('Standard Equipment Label', 'Standard Equipment Label 62x29mm', 'device', 62, 29, TRUE)
ON CONFLICT (name) DO NOTHING;

-- Default count types for accessories/consumables
INSERT INTO count_types (name, abbreviation, is_decimal) VALUES
('Piece', 'Pcs', FALSE),
('Kilogram', 'kg', TRUE),
('Liter', 'L', TRUE),
('Meter', 'm', TRUE),
('Square meter', 'm²', TRUE)
ON CONFLICT (name) DO NOTHING;

-- Default cable connectors
INSERT INTO cable_connectors (name, abbreviation, gender) VALUES
('Schuko', 'SCH', 'male'),
('Schuko coupling', 'SCH', 'female'),
('CEE 16A blue', 'CEE16', 'male'),
('CEE 16A blue coupling', 'CEE16', 'female'),
('CEE 32A red', 'CEE32', 'male'),
('CEE 32A red coupling', 'CEE32', 'female'),
('CEE 63A red', 'CEE63', 'male'),
('CEE 63A red coupling', 'CEE63', 'female'),
('CEE 125A red', 'CEE125', 'male'),
('CEE 125A red coupling', 'CEE125', 'female'),
('XLR 3-pin', 'XLR3', 'male'),
('XLR 3-pin coupling', 'XLR3', 'female'),
('XLR 5-pin', 'XLR5', 'male'),
('XLR 5-pin coupling', 'XLR5', 'female'),
('Powercon', 'PWC', 'male'),
('Powercon TRUE1', 'PWC1', 'male'),
('Socapex', 'SOC', 'male'),
('Socapex coupling', 'SOC', 'female'),
('HAN 16E', 'HAN16', 'male'),
('HAN 16E coupling', 'HAN16', 'female'),
('speakON 2-pin', 'NL2', 'male'),
('speakON 4-pin', 'NL4', 'male'),
('speakON 8-pin', 'NL8', 'male'),
('Jack 6.3mm mono', 'TS', 'male'),
('Jack 6.3mm stereo', 'TRS', 'male'),
('RJ45', 'RJ45', 'male'),
('etherCON', 'eCON', 'male')
ON CONFLICT DO NOTHING;

-- Default cable types
INSERT INTO cable_types (name) VALUES
('Power'),
('Audio'),
('DMX'),
('Network'),
('Video'),
('Multicore'),
('Hybrid')
ON CONFLICT DO NOTHING;

-- Default product categories
INSERT INTO categories (name, abbreviation)
SELECT v.name, v.abbreviation
FROM (
    VALUES
    ('Lighting', 'LT'),
    ('Audio', 'AU'),
    ('Video', 'VI'),
    ('Power Distribution', 'PW'),
    ('Cables & Connectors', 'CA'),
    ('Rigging & Staging', 'RS'),
    ('Backline', 'BL'),
    ('Communication', 'CM'),
    ('Accessories', 'AC'),
    ('ICT & Network', 'ICT')
) AS v(name, abbreviation)
WHERE NOT EXISTS (
    SELECT 1 FROM categories c WHERE c.abbreviation = v.abbreviation
);

-- Default product subcategories
INSERT INTO subcategories (subcategoryid, name, abbreviation, categoryid) VALUES
('LT-MH',  'Moving Heads',           'MH',  (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'LT')),
('LT-PAR', 'LED Pars',               'PAR', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'LT')),
('LT-BAR', 'LED Bars & Strips',      'BAR', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'LT')),
('LT-FSP', 'Followspots',            'FSP', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'LT')),
('LT-HAZ', 'Hazers & Fog Machines',  'HAZ', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'LT')),
('LT-STB', 'Strobes',                'STB', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'LT')),
('LT-CTL', 'Controllers & Dimmers', 'CTL', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'LT')),
('AU-MIC', 'Microphones',            'MIC', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'AU')),
('AU-SPA', 'PA Speakers',            'SPA', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'AU')),
('AU-MON', 'Stage Monitors',         'MON', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'AU')),
('AU-AMP', 'Amplifiers',             'AMP', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'AU')),
('AU-MIX', 'Mixing Consoles',        'MIX', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'AU')),
('AU-WRL', 'Wireless Systems',       'WRL', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'AU')),
('AU-IEM', 'In-Ear Monitors',        'IEM', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'AU')),
('AU-LAR', 'Line Arrays',            'LAR', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'AU')),
('VI-PRJ', 'Projectors',             'PRJ', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'VI')),
('VI-LED', 'LED Screens',            'LED', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'VI')),
('VI-MNT', 'Monitors & Displays',    'MNT', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'VI')),
('VI-SWT', 'Video Switchers',        'SWT', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'VI')),
('VI-CAM', 'Cameras',                'CAM', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'VI')),
('VI-MSV', 'Media Servers',          'MSV', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'VI')),
('PW-DST', 'Distribution Boards',   'DST', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'PW')),
('PW-GEN', 'Generators',             'GEN', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'PW')),
('PW-UPS', 'UPS Systems',            'UPS', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'PW')),
('PW-RLS', 'Cable Reels',            'RLS', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'PW')),
('CA-PWC', 'Power Cables',           'PWC', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'CA')),
('CA-AUC', 'Audio Cables',           'AUC', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'CA')),
('CA-VIC', 'Video Cables',           'VIC', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'CA')),
('CA-DMX', 'DMX Cables',             'DMX', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'CA')),
('CA-NTC', 'Network Cables',         'NTC', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'CA')),
('CA-MCC', 'Multicore',              'MCC', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'CA')),
('RS-TRS', 'Trussing',               'TRS', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'RS')),
('RS-CHH', 'Chain Hoists',           'CHH', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'RS')),
('RS-STA', 'Stands & Tripods',       'STA', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'RS')),
('RS-PLT', 'Staging Platforms',      'PLT', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'RS')),
('RS-DRP', 'Drapes & Fabric',        'DRP', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'RS')),
('BL-GTR', 'Guitars',                'GTR', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'BL')),
('BL-KEY', 'Keyboards & Synths',     'KEY', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'BL')),
('BL-DRM', 'Drums & Percussion',     'DRM', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'BL')),
('BL-AMP', 'Guitar & Bass Amps',     'AMP', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'BL')),
('CM-INT', 'Intercoms',              'INT', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'CM')),
('CM-WLK', 'Walkie-Talkies',         'WLK', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'CM')),
('AC-CAS', 'Cases & Flight Cases',   'CAS', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'AC')),
('AC-HWT', 'Hardware & Tools',       'HWT', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'AC')),
('AC-ADP', 'Adapters & Connectors',  'ADP', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'AC')),
('ICT-NSW','Network Switches',       'NSW', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'ICT')),
('ICT-RAP','Routers & Access Points','RAP', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'ICT')),
('ICT-SRV','Servers & Compute',      'SRV', (SELECT MIN(categoryid) FROM categories WHERE abbreviation = 'ICT'))
ON CONFLICT (subcategoryid) DO NOTHING;

-- Default manufacturers
INSERT INTO manufacturer (name, website)
SELECT v.name, v.website
FROM (
    VALUES
    ('Shure',                  'https://www.shure.com'),
    ('Sennheiser',              'https://www.sennheiser.com'),
    ('d&b audiotechnik',        'https://www.dbaudio.com'),
    ('L-Acoustics',             'https://www.l-acoustics.com'),
    ('JBL Professional',        'https://jblpro.com'),
    ('Yamaha',                  'https://usa.yamaha.com'),
    ('QSC',                     'https://www.qsc.com'),
    ('Crown International',     'https://www.crownaudio.com'),
    ('Martin by Harman',        'https://www.martin.com'),
    ('Robe Lighting',           'https://www.robe.cz'),
    ('Chauvet Professional',    'https://www.chauvetprofessional.com'),
    ('ETC',                     'https://www.etcconnect.com'),
    ('GLP',                     'https://www.glp.de'),
    ('Ayrton',                  'https://www.ayrton.eu'),
    ('Claypaky',                'https://www.claypaky.it'),
    ('Elation Professional',    'https://www.elationlighting.com'),
    ('DiGiCo',                  'https://www.digico.biz'),
    ('Midas',                   'https://www.midasconsoles.com'),
    ('Allen & Heath',           'https://www.allen-heath.com'),
    ('Roland',                  'https://www.roland.com'),
    ('Blackmagic Design',       'https://www.blackmagicdesign.com'),
    ('Panasonic',               'https://www.panasonic.com'),
    ('Sony',                    'https://pro.sony'),
    ('Christie',                'https://www.christiedigital.com'),
    ('Barco',                   'https://www.barco.com'),
    ('Prolyte Group',           'https://www.prolyte.com'),
    ('Global Truss',            'https://www.global-truss.com'),
    ('Neutrik',                 'https://www.neutrik.com'),
    ('Amphenol',                'https://www.amphenol.com'),
    ('Obsidian Control Systems','https://www.obsidiancontrol.com'),
    ('MA Lighting',             'https://www.malighting.com'),
    ('Avolites',                'https://www.avolites.com')
) AS v(name, website)
WHERE NOT EXISTS (
    SELECT 1 FROM manufacturer m WHERE m.name = v.name
);

-- Default brands
INSERT INTO brands (name, manufacturerid) VALUES
('Shure',              (SELECT MIN(manufacturerid) FROM manufacturer WHERE name = 'Shure')),
('Sennheiser',         (SELECT MIN(manufacturerid) FROM manufacturer WHERE name = 'Sennheiser')),
('Neumann',            (SELECT MIN(manufacturerid) FROM manufacturer WHERE name = 'Sennheiser')),
('d&b audiotechnik',   (SELECT MIN(manufacturerid) FROM manufacturer WHERE name = 'd&b audiotechnik')),
('L-Acoustics',        (SELECT MIN(manufacturerid) FROM manufacturer WHERE name = 'L-Acoustics')),
('JBL Professional',   (SELECT MIN(manufacturerid) FROM manufacturer WHERE name = 'JBL Professional')),
('JBL',                (SELECT MIN(manufacturerid) FROM manufacturer WHERE name = 'JBL Professional')),
('Yamaha',             (SELECT MIN(manufacturerid) FROM manufacturer WHERE name = 'Yamaha')),
('Nexo',               (SELECT MIN(manufacturerid) FROM manufacturer WHERE name = 'Yamaha')),
('QSC',                (SELECT MIN(manufacturerid) FROM manufacturer WHERE name = 'QSC')),
('Crown',              (SELECT MIN(manufacturerid) FROM manufacturer WHERE name = 'Crown International')),
('Martin',             (SELECT MIN(manufacturerid) FROM manufacturer WHERE name = 'Martin by Harman')),
('Robe',               (SELECT MIN(manufacturerid) FROM manufacturer WHERE name = 'Robe Lighting')),
('Chauvet Professional',(SELECT MIN(manufacturerid) FROM manufacturer WHERE name = 'Chauvet Professional')),
('Chauvet DJ',         (SELECT MIN(manufacturerid) FROM manufacturer WHERE name = 'Chauvet Professional')),
('ETC',                (SELECT MIN(manufacturerid) FROM manufacturer WHERE name = 'ETC')),
('GLP',                (SELECT MIN(manufacturerid) FROM manufacturer WHERE name = 'GLP')),
('Ayrton',             (SELECT MIN(manufacturerid) FROM manufacturer WHERE name = 'Ayrton')),
('Claypaky',           (SELECT MIN(manufacturerid) FROM manufacturer WHERE name = 'Claypaky')),
('Elation',            (SELECT MIN(manufacturerid) FROM manufacturer WHERE name = 'Elation Professional')),
('DiGiCo',             (SELECT MIN(manufacturerid) FROM manufacturer WHERE name = 'DiGiCo')),
('Midas',              (SELECT MIN(manufacturerid) FROM manufacturer WHERE name = 'Midas')),
('Allen & Heath',      (SELECT MIN(manufacturerid) FROM manufacturer WHERE name = 'Allen & Heath')),
('Roland',             (SELECT MIN(manufacturerid) FROM manufacturer WHERE name = 'Roland')),
('BOSS',               (SELECT MIN(manufacturerid) FROM manufacturer WHERE name = 'Roland')),
('Blackmagic Design',  (SELECT MIN(manufacturerid) FROM manufacturer WHERE name = 'Blackmagic Design')),
('ATEM',               (SELECT MIN(manufacturerid) FROM manufacturer WHERE name = 'Blackmagic Design')),
('Panasonic',          (SELECT MIN(manufacturerid) FROM manufacturer WHERE name = 'Panasonic')),
('Sony',               (SELECT MIN(manufacturerid) FROM manufacturer WHERE name = 'Sony')),
('Christie',           (SELECT MIN(manufacturerid) FROM manufacturer WHERE name = 'Christie')),
('Barco',              (SELECT MIN(manufacturerid) FROM manufacturer WHERE name = 'Barco')),
('Prolyte',            (SELECT MIN(manufacturerid) FROM manufacturer WHERE name = 'Prolyte Group')),
('Global Truss',       (SELECT MIN(manufacturerid) FROM manufacturer WHERE name = 'Global Truss')),
('Neutrik',            (SELECT MIN(manufacturerid) FROM manufacturer WHERE name = 'Neutrik')),
('Amphenol',           (SELECT MIN(manufacturerid) FROM manufacturer WHERE name = 'Amphenol')),
('Onyx',               (SELECT MIN(manufacturerid) FROM manufacturer WHERE name = 'Obsidian Control Systems')),
('grandMA',            (SELECT MIN(manufacturerid) FROM manufacturer WHERE name = 'MA Lighting')),
('Avolites',           (SELECT MIN(manufacturerid) FROM manufacturer WHERE name = 'Avolites'))
ON CONFLICT DO NOTHING;

-- Default company settings (empty template)
INSERT INTO company_settings (company_name, country, currency, default_tax_rate) 
VALUES ('My Company', 'Germany', 'EUR', 19.00)
ON CONFLICT DO NOTHING;

-- Default LED settings
INSERT INTO app_settings (scope, key, value, description) VALUES
('warehousecore', 'led.single_bin.default', '{"color": "#FF7A00", "pattern": "breathe", "intensity": 180}', 'Default LED highlighting settings for single bins')
ON CONFLICT (scope, key) DO NOTHING;

-- Default API limits
INSERT INTO app_settings (scope, key, value, description) VALUES
    ('warehousecore', 'api.device_limit', '50000', 'Maximum number of devices returned by the API'),
    ('warehousecore', 'api.case_limit',   '50000', 'Maximum number of cases returned by the API')
ON CONFLICT (scope, key) DO NOTHING;

-- Default LED job highlight settings
INSERT INTO app_settings (scope, key, value, description) VALUES
    ('warehousecore', 'led.job.highlight', '{"mode":"all_bins","required":{"color":"#00FF00","pattern":"solid","intensity":220,"speed":1200},"non_required":{"color":"#FF0000","pattern":"solid","intensity":160,"speed":1200}}', 'LED highlight settings for job packing bins')
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
