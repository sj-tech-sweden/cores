DROP TABLE IF EXISTS "devices";
CREATE TABLE "devices" (
  "deviceID" TEXT NOT NULL,
  "productID" INTEGER DEFAULT NULL,
  "serialnumber" TEXT DEFAULT NULL,
  "purchaseDate" TEXT DEFAULT NULL,
  "lastmaintenance" TEXT DEFAULT NULL,
  "nextmaintenance" TEXT DEFAULT NULL,
  "insurancenumber" TEXT DEFAULT NULL,
  "status" TEXT DEFAULT 'free',
  "insuranceID" INTEGER DEFAULT NULL,
  "qr_code" TEXT DEFAULT NULL,
  "current_location" TEXT DEFAULT NULL,
  "zone_id" INTEGER DEFAULT NULL,
  "gps_latitude" REAL DEFAULT NULL,
  "gps_longitude" REAL DEFAULT NULL,
  "condition_rating" REAL DEFAULT '5.0',
  "usage_hours" REAL DEFAULT '0.00',
  "total_revenue" REAL DEFAULT '0.00',
  "last_maintenance_cost" REAL DEFAULT NULL,
  "notes" text,
  "barcode" TEXT DEFAULT NULL,
  "label_path" TEXT DEFAULT NULL,
  PRIMARY KEY ("deviceID"));
DROP TABLE IF EXISTS "cables";
CREATE TABLE "cables" (
  "cableID" INTEGER NOT NULL,
  "connector1" INTEGER NOT NULL,
  "connector2" INTEGER NOT NULL,
  "typ" INTEGER NOT NULL,
  "length" REAL NOT NULL,
  "mm2" REAL DEFAULT NULL,
  "name" TEXT DEFAULT NULL,
  PRIMARY KEY ("cableID"));
DROP TABLE IF EXISTS "products";
CREATE TABLE "products" (
  "productID" INTEGER NOT NULL,
  "name" TEXT NOT NULL,
  "categoryID" INTEGER DEFAULT NULL,
  "subcategoryID" TEXT DEFAULT NULL,
  "subbiercategoryID" TEXT DEFAULT NULL,
  "manufacturerID" INTEGER DEFAULT NULL,
  "brandID" INTEGER DEFAULT NULL,
  "description" text,
  "maintenanceInterval" INTEGER DEFAULT NULL,
  "itemcostperday" REAL DEFAULT NULL,
  "weight" REAL DEFAULT NULL,
  "height" REAL DEFAULT NULL,
  "width" REAL DEFAULT NULL,
  "depth" REAL DEFAULT NULL,
  "powerconsumption" REAL DEFAULT NULL,
  "pos_in_category" INTEGER DEFAULT NULL,
  "is_accessory" INTEGER NOT NULL DEFAULT 0,
  "is_consumable" INTEGER NOT NULL DEFAULT 0,
  "count_type_id" INTEGER DEFAULT NULL,
  "stock_quantity" REAL DEFAULT NULL,
  "min_stock_level" REAL DEFAULT NULL,
  "generic_barcode" TEXT DEFAULT NULL,
  "price_per_unit" REAL DEFAULT NULL,
  "website_visible" INTEGER NOT NULL DEFAULT 0,
  "website_thumbnail" TEXT DEFAULT NULL,
  "website_images_json" TEXT DEFAULT NULL,
  PRIMARY KEY ("productID"));
DROP TABLE IF EXISTS "customers";
CREATE TABLE "customers" (
  "customerID" INTEGER NOT NULL,
  "companyname" TEXT DEFAULT NULL,
  "lastname" TEXT DEFAULT NULL,
  "firstname" TEXT DEFAULT NULL,
  "street" TEXT DEFAULT NULL,
  "housenumber" TEXT DEFAULT NULL,
  "ZIP" TEXT DEFAULT NULL,
  "city" TEXT DEFAULT NULL,
  "federalstate" TEXT DEFAULT NULL,
  "country" TEXT DEFAULT NULL,
  "phonenumber" TEXT DEFAULT NULL,
  "email" TEXT DEFAULT NULL,
  "customertype" TEXT DEFAULT NULL,
  "notes" text,
  "tax_number" TEXT DEFAULT NULL,
  "credit_limit" REAL DEFAULT '0.00',
  "payment_terms" INTEGER DEFAULT '30',
  "preferred_payment_method" TEXT DEFAULT NULL,
  "customer_since" TEXT DEFAULT NULL,
  "total_lifetime_value" REAL DEFAULT '0.00',
  "last_job_date" TEXT DEFAULT NULL,
  "rating" REAL DEFAULT '5.0',
  "billing_address" text,
  "shipping_address" text,
  PRIMARY KEY ("customerID"));
DROP TABLE IF EXISTS "jobs";
CREATE TABLE "jobs" (
  "jobID" INTEGER NOT NULL,
  "customerID" INTEGER DEFAULT NULL,
  "startDate" TEXT DEFAULT NULL,
  "endDate" TEXT DEFAULT NULL,
  "statusID" INTEGER DEFAULT NULL,
  "jobcategoryID" INTEGER DEFAULT NULL,
  "created_by" INTEGER DEFAULT NULL,
  "created_at" TEXT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_by" INTEGER DEFAULT NULL,
  "updated_at" TEXT NULL DEFAULT CURRENT_TIMESTAMP,
  "description" TEXT DEFAULT NULL,
  "discount" REAL DEFAULT '0.00',
  "discount_type" TEXT DEFAULT 'amount',
  "revenue" REAL NOT NULL DEFAULT '0.00',
  "final_revenue" REAL DEFAULT NULL,
  "priority" TEXT DEFAULT 'normal',
  "internal_notes" text,
  "customer_notes" text,
  "estimated_revenue" REAL DEFAULT NULL,
  "actual_cost" REAL DEFAULT '0.00',
  "profit_margin" REAL DEFAULT NULL,
  "contract_signed" INTEGER DEFAULT 0,
  "contract_documentID" INTEGER DEFAULT NULL,
  "completion_percentage" INTEGER DEFAULT 0,
  "job_code" TEXT NOT NULL,
  PRIMARY KEY ("jobID"));
DROP TABLE IF EXISTS "jobdevices";
CREATE TABLE "jobdevices" (
  "jobID" INTEGER NOT NULL,
  "deviceID" TEXT NOT NULL,
  "custom_price" REAL DEFAULT NULL,
  "package_id" INTEGER DEFAULT NULL,
  "is_package_item" INTEGER DEFAULT 0,
  "pack_status" TEXT NOT NULL DEFAULT 'pending',
  "pack_ts" TEXT DEFAULT NULL,
  PRIMARY KEY ("jobID","deviceID"));
DROP TABLE IF EXISTS "categories";
CREATE TABLE "categories" (
  "categoryID" INTEGER NOT NULL,
  "name" TEXT NOT NULL,
  "abbreviation" TEXT NOT NULL,
  PRIMARY KEY ("categoryID")
);
DROP TABLE IF EXISTS "subcategories";
CREATE TABLE "subcategories" (
  "subcategoryID" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "abbreviation" TEXT DEFAULT NULL,
  "categoryID" INTEGER DEFAULT NULL,
  PRIMARY KEY ("subcategoryID"));
DROP TABLE IF EXISTS "subbiercategories";
CREATE TABLE "subbiercategories" (
  "subbiercategoryID" TEXT NOT NULL,
  "name" TEXT DEFAULT NULL,
  "abbreviation" TEXT DEFAULT NULL,
  "subcategoryID" TEXT NOT NULL,
  PRIMARY KEY ("subbiercategoryID"));
DROP TABLE IF EXISTS "brands";
CREATE TABLE "brands" (
  "brandID" INTEGER NOT NULL,
  "name" TEXT NOT NULL,
  "manufacturerID" INTEGER DEFAULT NULL,
  PRIMARY KEY ("brandID"));
DROP TABLE IF EXISTS "manufacturer";
CREATE TABLE "manufacturer" (
  "manufacturerID" INTEGER NOT NULL,
  "name" TEXT NOT NULL,
  "website" TEXT DEFAULT NULL,
  PRIMARY KEY ("manufacturerID")
);
DROP TABLE IF EXISTS "cases";
CREATE TABLE "cases" (
  "caseID" INTEGER NOT NULL,
  "name" TEXT NOT NULL,
  "description" text,
  "width" REAL DEFAULT NULL,
  "height" REAL DEFAULT NULL,
  "depth" REAL DEFAULT NULL,
  "weight" REAL DEFAULT NULL,
  "status" TEXT NOT NULL,
  "zone_id" INTEGER DEFAULT NULL,
  "barcode" TEXT DEFAULT NULL,
  "rfid_tag" TEXT DEFAULT NULL,
  "label_path" TEXT DEFAULT NULL,
  PRIMARY KEY ("caseID"));
DROP TABLE IF EXISTS "devicescases";
CREATE TABLE "devicescases" (
  "caseID" INTEGER NOT NULL,
  "deviceID" TEXT NOT NULL,
  PRIMARY KEY ("caseID","deviceID"));
DROP TABLE IF EXISTS "cable_connectors";
CREATE TABLE "cable_connectors" (
  "cable_connectorsID" INTEGER NOT NULL,
  "name" TEXT NOT NULL,
  "abbreviation" TEXT DEFAULT NULL,
  "gender" TEXT DEFAULT NULL,
  PRIMARY KEY ("cable_connectorsID")
);
DROP TABLE IF EXISTS "cable_types";
CREATE TABLE "cable_types" (
  "cable_typesID" INTEGER NOT NULL,
  "name" TEXT NOT NULL,
  PRIMARY KEY ("cable_typesID")
);
DROP TABLE IF EXISTS "status";
CREATE TABLE "status" (
  "statusID" INTEGER NOT NULL,
  "status" TEXT NOT NULL,
  PRIMARY KEY ("statusID")
);
DROP TABLE IF EXISTS "users";
CREATE TABLE "users" (
  "userID" INTEGER NOT NULL,
  "username" TEXT NOT NULL,
  "email" TEXT NOT NULL,
  "password_hash" TEXT NOT NULL,
  "first_name" TEXT,
  "last_name" TEXT,
  "is_active" INTEGER DEFAULT 1,
  "created_at" TEXT(3) DEFAULT NULL,
  "updated_at" TEXT(3) DEFAULT NULL,
  "last_login" TEXT(3) DEFAULT NULL,
  "timezone" TEXT DEFAULT 'Europe/Berlin',
  "language" TEXT DEFAULT 'en',
  "avatar_path" TEXT DEFAULT NULL,
  "notification_preferences" TEXT DEFAULT NULL,
  "last_active" TEXT NULL DEFAULT NULL,
  "login_attempts" INTEGER DEFAULT 0,
  "locked_until" TEXT NULL DEFAULT NULL,
  "two_factor_enabled" INTEGER DEFAULT 0,
  "two_factor_secret" TEXT DEFAULT NULL,
  PRIMARY KEY ("userID"));
DROP TABLE IF EXISTS "roles";
CREATE TABLE "roles" (
  "roleID" INTEGER NOT NULL,
  "name" TEXT NOT NULL,
  "display_name" TEXT NOT NULL,
  "description" text,
  "permissions" TEXT NOT NULL,
  "is_system_role" INTEGER DEFAULT 0,
  "is_active" INTEGER DEFAULT 1,
  "created_at" TEXT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TEXT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY ("roleID"));
DROP TABLE IF EXISTS "user_roles";
CREATE TABLE "user_roles" (
  "userID" INTEGER NOT NULL,
  "roleID" INTEGER NOT NULL,
  "assigned_at" TEXT NULL DEFAULT CURRENT_TIMESTAMP,
  "assigned_by" INTEGER DEFAULT NULL,
  "expires_at" TEXT NULL DEFAULT NULL,
  "is_active" INTEGER DEFAULT 1,
  PRIMARY KEY ("userID","roleID"));
DROP TABLE IF EXISTS "user_profiles";
CREATE TABLE "user_profiles" (
  "id" INTEGER NOT NULL,
  "user_id" INTEGER NOT NULL,
  "display_name" TEXT DEFAULT NULL,
  "avatar_url" TEXT DEFAULT NULL,
  "prefs" TEXT DEFAULT NULL,
  "created_at" TEXT DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TEXT DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY ("id"));
DROP TABLE IF EXISTS "employee";
CREATE TABLE "employee" (
  "employeeID" INTEGER NOT NULL,
  "firstname" TEXT NOT NULL,
  "lastname" TEXT NOT NULL,
  "street" TEXT DEFAULT NULL,
  "housenumber" TEXT DEFAULT NULL,
  "ZIP" TEXT DEFAULT NULL,
  "city" TEXT DEFAULT NULL,
  "federalstate" TEXT DEFAULT NULL,
  "country" TEXT DEFAULT NULL,
  "phonenumber" TEXT DEFAULT NULL,
  "email" TEXT DEFAULT NULL,
  PRIMARY KEY ("employeeID")
);
DROP TABLE IF EXISTS "employeejob";
CREATE TABLE "employeejob" (
  "employeeID" INTEGER NOT NULL,
  "jobID" INTEGER NOT NULL,
  PRIMARY KEY ("employeeID","jobID"));
DROP TABLE IF EXISTS "storage_zones";
CREATE TABLE "storage_zones" (
  "zone_id" INTEGER NOT NULL,
  "code" TEXT NOT NULL,
  "barcode" TEXT DEFAULT NULL,
  "name" TEXT NOT NULL,
  "type" TEXT NOT NULL DEFAULT 'other',
  "description" text,
  "parent_zone_id" INTEGER DEFAULT NULL,
  "capacity" INTEGER DEFAULT NULL,
  "location" TEXT DEFAULT NULL,
  "metadata" TEXT DEFAULT NULL,
  "is_active" INTEGER NOT NULL DEFAULT 1,
  "created_at" TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY ("zone_id"));
DROP TABLE IF EXISTS "zone_types";
CREATE TABLE "zone_types" (
  "id" INTEGER NOT NULL,
  "key" TEXT NOT NULL,
  "label" TEXT NOT NULL,
  "description" text,
  "default_led_pattern" TEXT DEFAULT 'breathe',
  "default_led_color" TEXT DEFAULT '#FF7A00',
  "default_intensity" INTEGER DEFAULT '180',
  "created_at" TEXT DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TEXT DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY ("id"));
DROP TABLE IF EXISTS "led_controllers";
CREATE TABLE "led_controllers" (
  "id" INTEGER NOT NULL,
  "controller_id" TEXT NOT NULL,
  "display_name" TEXT NOT NULL,
  "topic_suffix" TEXT NOT NULL DEFAULT '',
  "is_active" INTEGER NOT NULL DEFAULT 1,
  "last_seen" TEXT DEFAULT NULL,
  "ip_address" TEXT DEFAULT NULL,
  "hostname" TEXT DEFAULT NULL,
  "firmware_version" TEXT DEFAULT NULL,
  "mac_address" TEXT DEFAULT NULL,
  "metadata" TEXT DEFAULT NULL,
  "status_data" TEXT DEFAULT NULL,
  "created_at" TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY ("id"));
DROP TABLE IF EXISTS "led_controller_zone_types";
CREATE TABLE "led_controller_zone_types" (
  "controller_id" INTEGER NOT NULL,
  "zone_type_id" INTEGER NOT NULL,
  "created_at" TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY ("controller_id","zone_type_id"));
DROP TABLE IF EXISTS "product_packages";
CREATE TABLE "product_packages" (
  "package_id" INTEGER NOT NULL,
  "product_id" INTEGER DEFAULT NULL,
  "package_code" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "description" text,
  "website_visible" INTEGER NOT NULL DEFAULT 0,
  "price" REAL DEFAULT NULL,
  "created_at" TEXT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TEXT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY ("package_id"));
DROP TABLE IF EXISTS "product_package_items";
CREATE TABLE "product_package_items" (
  "package_item_id" INTEGER NOT NULL,
  "package_id" INTEGER NOT NULL,
  "product_id" INTEGER NOT NULL,
  "quantity" INTEGER NOT NULL DEFAULT 1,
  "created_at" TEXT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY ("package_item_id"));
DROP TABLE IF EXISTS "package_devices";
CREATE TABLE "package_devices" (
  "packageID" INTEGER NOT NULL,
  "deviceID" TEXT NOT NULL,
  "quantity" INTEGER NOT NULL DEFAULT 1,
  "custom_price" REAL DEFAULT NULL,
  "is_required" INTEGER NOT NULL DEFAULT 0,
  "notes" text,
  "sort_order" INTEGER DEFAULT NULL,
  "created_at" TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY ("packageID","deviceID"));
DROP TABLE IF EXISTS "package_categories";
CREATE TABLE "package_categories" (
  "categoryID" INTEGER NOT NULL,
  "name" TEXT NOT NULL,
  "description" text,
  "color" TEXT DEFAULT NULL,
  "sort_order" INTEGER DEFAULT NULL,
  "is_active" INTEGER NOT NULL DEFAULT 1,
  "created_at" TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY ("categoryID"));
DROP TABLE IF EXISTS "job_attachments";
CREATE TABLE "job_attachments" (
  "attachment_id" INTEGER NOT NULL,
  "job_id" INTEGER NOT NULL,
  "filename" TEXT NOT NULL,
  "original_filename" TEXT NOT NULL,
  "file_path" TEXT NOT NULL,
  "file_size" INTEGER NOT NULL,
  "mime_type" TEXT NOT NULL,
  "uploaded_by" INTEGER DEFAULT NULL,
  "uploaded_at" TEXT NULL DEFAULT CURRENT_TIMESTAMP,
  "description" text,
  "is_active" INTEGER DEFAULT 1,
  PRIMARY KEY ("attachment_id"));
DROP TABLE IF EXISTS "job_history";
CREATE TABLE "job_history" (
  "history_id" INTEGER NOT NULL,
  "job_id" INTEGER NOT NULL,
  "user_id" INTEGER DEFAULT NULL,
  "changed_at" TEXT NULL DEFAULT CURRENT_TIMESTAMP,
  "change_type" TEXT NOT NULL,
  "field_name" TEXT DEFAULT NULL,
  "old_value" text,
  "new_value" text,
  "description" text,
  "ip_address" TEXT DEFAULT NULL,
  "user_agent" TEXT DEFAULT NULL,
  PRIMARY KEY ("history_id"));
DROP TABLE IF EXISTS "job_packages";
CREATE TABLE "job_packages" (
  "job_package_id" INTEGER NOT NULL,
  "job_id" INTEGER NOT NULL,
  "package_id" INTEGER NOT NULL,
  "quantity" INTEGER NOT NULL DEFAULT 1,
  "custom_price" REAL DEFAULT NULL,
  "added_at" TEXT NULL DEFAULT CURRENT_TIMESTAMP,
  "added_by" INTEGER DEFAULT NULL,
  "notes" text,
  PRIMARY KEY ("job_package_id"));
DROP TABLE IF EXISTS "jobCategory";
CREATE TABLE "jobCategory" (
  "jobcategoryID" INTEGER NOT NULL,
  "name" TEXT NOT NULL,
  "abbreviation" TEXT DEFAULT NULL,
  PRIMARY KEY ("jobcategoryID")
);
DROP TABLE IF EXISTS "device_movements";
CREATE TABLE "device_movements" (
  "movement_id" INTEGER NOT NULL,
  "device_id" TEXT NOT NULL,
  "action" TEXT NOT NULL,
  "from_zone_id" INTEGER DEFAULT NULL,
  "to_zone_id" INTEGER DEFAULT NULL,
  "from_job_id" INTEGER DEFAULT NULL,
  "to_job_id" INTEGER DEFAULT NULL,
  "barcode" TEXT DEFAULT NULL,
  "user_id" INTEGER DEFAULT NULL,
  "notes" text,
  "metadata" TEXT DEFAULT NULL,
  "TEXT" TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY ("movement_id"));
DROP TABLE IF EXISTS "app_settings";
CREATE TABLE "app_settings" (
  "id" INTEGER NOT NULL,
  "scope" TEXT NOT NULL DEFAULT 'warehousecore',
  "k" TEXT NOT NULL,
  "v" TEXT NOT NULL,
  "created_at" TEXT DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TEXT DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY ("id"));
DROP TABLE IF EXISTS "company_settings";
CREATE TABLE "company_settings" (
  "id" INTEGER NOT NULL,
  "company_name" TEXT NOT NULL,
  "address_line1" TEXT,
  "address_line2" TEXT,
  "city" TEXT,
  "state" TEXT,
  "postal_code" TEXT,
  "country" TEXT,
  "phone" TEXT,
  "email" TEXT,
  "website" TEXT,
  "tax_number" TEXT,
  "vat_number" TEXT,
  "logo_path" TEXT,
  "created_at" TEXT(3) DEFAULT NULL,
  "updated_at" TEXT(3) DEFAULT NULL,
  "bank_name" TEXT,
  "iban" TEXT,
  "bic" TEXT,
  "account_holder" TEXT,
  "ceo_name" TEXT,
  "register_court" TEXT,
  "register_number" TEXT,
  "footer_text" text,
  "payment_terms_text" text,
  "smtp_host" TEXT DEFAULT NULL,
  "smtp_port" INTEGER DEFAULT NULL,
  "smtp_username" TEXT DEFAULT NULL,
  "smtp_password" TEXT DEFAULT NULL,
  "smtp_from_email" TEXT DEFAULT NULL,
  "smtp_from_name" TEXT DEFAULT NULL,
  "smtp_use_tls" INTEGER DEFAULT 1,
  "brand_primary_color" TEXT DEFAULT NULL,
  "brand_accent_color" TEXT DEFAULT NULL,
  "brand_dark_mode" INTEGER NOT NULL DEFAULT 1,
  "brand_logo_url" TEXT DEFAULT NULL,
  PRIMARY KEY ("id"));
DROP TABLE IF EXISTS "invoice_settings";
CREATE TABLE "invoice_settings" (
  "setting_id" INTEGER NOT NULL,
  "setting_key" TEXT NOT NULL,
  "setting_value" text,
  "setting_type" TEXT NOT NULL DEFAULT 'text',
  "description" text,
  "updated_by" INTEGER DEFAULT NULL,
  "updated_at" TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY ("setting_id"));
DROP TABLE IF EXISTS "invoice_templates";
CREATE TABLE "invoice_templates" (
  "template_id" INTEGER NOT NULL,
  "name" TEXT NOT NULL,
  "description" text,
  "html_template" TEXT NOT NULL,
  "css_styles" TEXT,
  "is_default" INTEGER NOT NULL DEFAULT 0,
  "is_active" INTEGER NOT NULL DEFAULT 1,
  "created_by" INTEGER DEFAULT NULL,
  "created_at" TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY ("template_id"));
DROP TABLE IF EXISTS "email_templates";
CREATE TABLE "email_templates" (
  "template_id" INTEGER NOT NULL,
  "name" TEXT NOT NULL,
  "description" text,
  "template_type" TEXT NOT NULL DEFAULT 'general',
  "subject" TEXT NOT NULL,
  "html_content" TEXT NOT NULL,
  "text_content" TEXT,
  "is_default" INTEGER NOT NULL DEFAULT 0,
  "is_active" INTEGER NOT NULL DEFAULT 1,
  "created_by" INTEGER DEFAULT NULL,
  "created_at" TEXT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TEXT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY ("template_id"));
DROP TABLE IF EXISTS "label_templates";
CREATE TABLE "label_templates" (
  "id" INTEGER NOT NULL,
  "name" TEXT NOT NULL,
  "description" text,
  "width" REAL NOT NULL,
  "height" REAL NOT NULL,
  "template_json" TEXT NOT NULL,
  "is_default" INTEGER DEFAULT 0,
  "created_at" TEXT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TEXT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY ("id"));
DROP TABLE IF EXISTS "retention_policies";
CREATE TABLE "retention_policies" (
  "id" INTEGER NOT NULL,
  "data_type" TEXT NOT NULL,
  "retention_period_days" INTEGER NOT NULL,
  "legal_basis" TEXT NOT NULL,
  "auto_delete" INTEGER DEFAULT 0,
  "policy_description" text,
  "effective_from" TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "effective_until" TEXT NULL DEFAULT NULL,
  "created_by" INTEGER DEFAULT NULL,
  "created_at" TEXT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TEXT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY ("id"));
DROP TABLE IF EXISTS "count_types";
CREATE TABLE "count_types" (
  "count_type_id" INTEGER NOT NULL,
  "name" TEXT NOT NULL,
  "abbreviation" TEXT NOT NULL,
  "is_active" INTEGER NOT NULL DEFAULT 1,
  "created_at" TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY ("count_type_id"));
DROP TABLE IF EXISTS "documents";
CREATE TABLE "documents" (
  "documentID" INTEGER NOT NULL,
  "entity_type" TEXT NOT NULL,
  "entity_id" TEXT NOT NULL,
  "filename" TEXT NOT NULL,
  "original_filename" TEXT NOT NULL,
  "file_path" TEXT NOT NULL,
  "file_size" INTEGER NOT NULL,
  "mime_type" TEXT NOT NULL,
  "document_type" TEXT NOT NULL,
  "description" text,
  "uploaded_by" INTEGER DEFAULT NULL,
  "uploaded_at" TEXT NULL DEFAULT CURRENT_TIMESTAMP,
  "is_public" INTEGER DEFAULT 0,
  "version" INTEGER DEFAULT 1,
  "parent_documentID" INTEGER DEFAULT NULL,
  "checksum" TEXT DEFAULT NULL,
  PRIMARY KEY ("documentID"));
DROP TABLE IF EXISTS "insuranceprovider";
CREATE TABLE "insuranceprovider" (
  "insuranceproviderID" INTEGER NOT NULL,
  "name" TEXT NOT NULL,
  "website" TEXT NOT NULL,
  "phonenumber" TEXT NOT NULL,
  PRIMARY KEY ("insuranceproviderID")
);
DROP TABLE IF EXISTS "insurances";
CREATE TABLE "insurances" (
  "insuranceID" INTEGER NOT NULL,
  "name" TEXT NOT NULL,
  "insuranceproviderID" INTEGER NOT NULL,
  "policynumber" TEXT DEFAULT NULL,
  "coveragedetails" text,
  "validuntil" TEXT DEFAULT NULL,
  "price" REAL NOT NULL,
  PRIMARY KEY ("insuranceID"));
DROP TABLE IF EXISTS "rental_equipment";
CREATE TABLE "rental_equipment" (
  "equipment_id" INTEGER NOT NULL,
  "product_name" TEXT NOT NULL,
  "supplier_name" TEXT NOT NULL,
  "rental_price" REAL NOT NULL DEFAULT '0.00',
  "customer_price" REAL NOT NULL DEFAULT '0.00',
  "category" TEXT DEFAULT NULL,
  "description" TEXT DEFAULT NULL,
  "notes" TEXT DEFAULT NULL,
  "is_active" INTEGER DEFAULT 1,
  "created_at" TEXT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TEXT NULL DEFAULT CURRENT_TIMESTAMP,
  "created_by" INTEGER DEFAULT NULL,
  PRIMARY KEY ("equipment_id"));
DROP TABLE IF EXISTS "equipment_packages";
CREATE TABLE "equipment_packages" (
  "packageID" INTEGER NOT NULL,
  "name" TEXT NOT NULL,
  "description" text,
  "categoryID" INTEGER DEFAULT NULL,
  "package_items" TEXT NOT NULL,
  "package_price" REAL DEFAULT NULL,
  "discount_percent" REAL DEFAULT '0.00',
  "min_rental_days" INTEGER DEFAULT 1,
  "is_active" INTEGER DEFAULT 1,
  "created_by" INTEGER DEFAULT NULL,
  "created_at" TEXT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TEXT NULL DEFAULT CURRENT_TIMESTAMP,
  "usage_count" INTEGER DEFAULT 0,
  "max_rental_days" INTEGER DEFAULT NULL,
  "category" TEXT DEFAULT NULL,
  "tags" text,
  "last_used_at" TEXT NULL DEFAULT NULL,
  "total_revenue" REAL DEFAULT '0.00',
  PRIMARY KEY ("packageID"));
DROP TABLE IF EXISTS "api_keys";
CREATE TABLE "api_keys" (
  "id" INTEGER NOT NULL,
  "name" TEXT NOT NULL,
  "api_key_hash" TEXT NOT NULL,
  "is_active" INTEGER NOT NULL DEFAULT 1,
  "last_used_at" TEXT DEFAULT NULL,
  "created_at" TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY ("id"));
DROP TABLE IF EXISTS "invoices";
CREATE TABLE "invoices" (
  "invoice_id" INTEGER NOT NULL,
  "invoice_number" TEXT NOT NULL,
  "customer_id" INTEGER NOT NULL,
  "job_id" INTEGER DEFAULT NULL,
  "template_id" INTEGER DEFAULT NULL,
  "status" TEXT NOT NULL DEFAULT 'draft',
  "issue_date" TEXT NOT NULL,
  "due_date" TEXT NOT NULL,
  "payment_terms" TEXT DEFAULT NULL,
  "subtotal" REAL NOT NULL DEFAULT '0.00',
  "tax_rate" REAL NOT NULL DEFAULT '0.00',
  "tax_amount" REAL NOT NULL DEFAULT '0.00',
  "discount_amount" REAL NOT NULL DEFAULT '0.00',
  "total_amount" REAL NOT NULL DEFAULT '0.00',
  "paid_amount" REAL NOT NULL DEFAULT '0.00',
  "balance_due" REAL NOT NULL DEFAULT '0.00',
  "notes" text,
  "terms_conditions" text,
  "internal_notes" text,
  "sent_at" TEXT NULL DEFAULT NULL,
  "paid_at" TEXT NULL DEFAULT NULL,
  "created_by" INTEGER DEFAULT NULL,
  "created_at" TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY ("invoice_id"));
DROP TABLE IF EXISTS "invoice_line_items";
CREATE TABLE "invoice_line_items" (
  "line_item_id" INTEGER NOT NULL,
  "invoice_id" INTEGER NOT NULL,
  "item_type" TEXT NOT NULL DEFAULT 'custom',
  "device_id" TEXT DEFAULT NULL,
  "package_id" INTEGER DEFAULT NULL,
  "description" text NOT NULL,
  "quantity" REAL NOT NULL DEFAULT '1.00',
  "unit_price" REAL NOT NULL DEFAULT '0.00',
  "total_price" REAL NOT NULL DEFAULT '0.00',
  "rental_start_date" TEXT DEFAULT NULL,
  "rental_end_date" TEXT DEFAULT NULL,
  "rental_days" INTEGER DEFAULT NULL,
  "sort_order" INTEGER DEFAULT NULL,
  "created_at" TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY ("line_item_id"));