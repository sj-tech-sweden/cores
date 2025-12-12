mysqldump: Deprecated program name. It will be removed in a future release, use '/usr/bin/mariadb-dump' instead
mysqldump: Error: 'Access denied; you need (at least one of) the PROCESS privilege(s) for this operation' when trying to dump tablespaces
/*M!999999\- enable the sandbox mode */ 
-- MariaDB dump 10.19-12.1.2-MariaDB, for debian-linux-gnu (x86_64)
--
-- Host: tsunami-events.de    Database: RentalCore
-- ------------------------------------------------------
-- Server version	9.5.0

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*M!100616 SET @OLD_NOTE_VERBOSITY=@@NOTE_VERBOSITY, NOTE_VERBOSITY=0 */;

--
-- Table structure for table `devices`
--

DROP TABLE IF EXISTS `devices`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `devices` (
  `deviceID` varchar(50) NOT NULL,
  `productID` int DEFAULT NULL,
  `serialnumber` varchar(50) DEFAULT NULL,
  `purchaseDate` date DEFAULT NULL,
  `lastmaintenance` date DEFAULT NULL,
  `nextmaintenance` date DEFAULT NULL,
  `insurancenumber` varchar(50) DEFAULT NULL,
  `status` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT 'free',
  `insuranceID` int DEFAULT NULL,
  `qr_code` varchar(255) DEFAULT NULL,
  `current_location` varchar(100) DEFAULT NULL,
  `zone_id` int DEFAULT NULL,
  `gps_latitude` decimal(10,8) DEFAULT NULL,
  `gps_longitude` decimal(11,8) DEFAULT NULL,
  `condition_rating` decimal(3,1) DEFAULT '5.0',
  `usage_hours` decimal(10,2) DEFAULT '0.00',
  `total_revenue` decimal(12,2) DEFAULT '0.00',
  `last_maintenance_cost` decimal(10,2) DEFAULT NULL,
  `notes` text,
  `barcode` varchar(255) DEFAULT NULL,
  `label_path` varchar(512) DEFAULT NULL,
  PRIMARY KEY (`deviceID`),
  UNIQUE KEY `qr_code` (`qr_code`),
  KEY `idx_devices_insuranceID` (`insuranceID`),
  KEY `idx_devices_productID` (`productID`),
  KEY `idx_devices_location` (`current_location`),
  KEY `idx_devices_qr` (`qr_code`),
  KEY `idx_devices_status` (`status`),
  KEY `idx_devices_search` (`deviceID`,`serialnumber`),
  KEY `idx_devices_product_status` (`productID`,`status`),
  KEY `idx_device_zone` (`zone_id`),
  KEY `idx_devices_label_path` (`label_path`),
  CONSTRAINT `devices_ibfk_1` FOREIGN KEY (`productID`) REFERENCES `products` (`productID`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `devices_ibfk_2` FOREIGN KEY (`insuranceID`) REFERENCES `insurances` (`insuranceID`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `cables`
--

DROP TABLE IF EXISTS `cables`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `cables` (
  `cableID` int NOT NULL AUTO_INCREMENT,
  `connector1` int NOT NULL,
  `connector2` int NOT NULL,
  `typ` int NOT NULL,
  `length` decimal(10,2) NOT NULL COMMENT 'in metern',
  `mm2` decimal(10,2) DEFAULT NULL COMMENT 'Kabelquerschnitt in mm^2',
  `name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL,
  PRIMARY KEY (`cableID`),
  KEY `connector1` (`connector1`),
  KEY `connector2` (`connector2`),
  KEY `typ` (`typ`),
  CONSTRAINT `cables_ibfk_1` FOREIGN KEY (`connector1`) REFERENCES `cable_connectors` (`cable_connectorsID`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `cables_ibfk_2` FOREIGN KEY (`connector2`) REFERENCES `cable_connectors` (`cable_connectorsID`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `cables_ibfk_3` FOREIGN KEY (`typ`) REFERENCES `cable_types` (`cable_typesID`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB AUTO_INCREMENT=1124 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `products`
--

DROP TABLE IF EXISTS `products`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `products` (
  `productID` int NOT NULL AUTO_INCREMENT,
  `name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `categoryID` int DEFAULT NULL,
  `subcategoryID` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL,
  `subbiercategoryID` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL,
  `manufacturerID` int DEFAULT NULL,
  `brandID` int DEFAULT NULL,
  `description` text,
  `maintenanceInterval` int DEFAULT NULL,
  `itemcostperday` decimal(10,2) DEFAULT NULL COMMENT 'in €',
  `weight` decimal(10,2) DEFAULT NULL COMMENT 'in kg',
  `height` decimal(10,2) DEFAULT NULL COMMENT 'in cm',
  `width` decimal(10,2) DEFAULT NULL COMMENT 'in cm',
  `depth` decimal(10,2) DEFAULT NULL COMMENT 'in cm',
  `powerconsumption` decimal(10,2) DEFAULT NULL COMMENT 'in W',
  `pos_in_category` int DEFAULT NULL,
  `is_accessory` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'TRUE if this is an accessory product',
  `is_consumable` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'TRUE if this is a consumable product',
  `count_type_id` int DEFAULT NULL COMMENT 'FK to count_types for accessories/consumables',
  `stock_quantity` decimal(10,3) DEFAULT NULL COMMENT 'Current stock for accessories/consumables',
  `min_stock_level` decimal(10,3) DEFAULT NULL COMMENT 'Minimum stock alert level',
  `generic_barcode` varchar(255) DEFAULT NULL COMMENT 'Generic barcode for accessories/consumables',
  `price_per_unit` decimal(10,2) DEFAULT NULL COMMENT 'Price per unit for accessories/consumables',
  `website_visible` tinyint(1) NOT NULL DEFAULT '0',
  `website_thumbnail` varchar(255) DEFAULT NULL,
  `website_images_json` json DEFAULT NULL,
  PRIMARY KEY (`productID`),
  KEY `idx_products_categoryID` (`categoryID`),
  KEY `idx_products_manufacturerID` (`manufacturerID`),
  KEY `idx_products_brandID` (`brandID`),
  KEY `idx_products_subcategoryID` (`subcategoryID`),
  KEY `idx_products_subbiercategoryID` (`subbiercategoryID`),
  KEY `idx_products_is_accessory` (`is_accessory`),
  KEY `idx_products_is_consumable` (`is_consumable`),
  KEY `idx_products_generic_barcode` (`generic_barcode`),
  KEY `fk_products_count_type` (`count_type_id`),
  CONSTRAINT `fk_products_count_type` FOREIGN KEY (`count_type_id`) REFERENCES `count_types` (`count_type_id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `products_ibfk_1` FOREIGN KEY (`brandID`) REFERENCES `brands` (`brandID`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `products_ibfk_2` FOREIGN KEY (`categoryID`) REFERENCES `categories` (`categoryID`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `products_ibfk_3` FOREIGN KEY (`manufacturerID`) REFERENCES `manufacturer` (`manufacturerID`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `products_ibfk_4` FOREIGN KEY (`subbiercategoryID`) REFERENCES `subbiercategories` (`subbiercategoryID`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `products_ibfk_5` FOREIGN KEY (`subcategoryID`) REFERENCES `subcategories` (`subcategoryID`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB AUTO_INCREMENT=1000009 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `customers`
--

DROP TABLE IF EXISTS `customers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `customers` (
  `customerID` int NOT NULL AUTO_INCREMENT,
  `companyname` varchar(100) DEFAULT NULL,
  `lastname` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL,
  `firstname` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL,
  `street` varchar(100) DEFAULT NULL,
  `housenumber` varchar(20) DEFAULT NULL,
  `ZIP` varchar(20) DEFAULT NULL,
  `city` varchar(50) DEFAULT NULL,
  `federalstate` varchar(50) DEFAULT NULL,
  `country` varchar(50) DEFAULT NULL,
  `phonenumber` varchar(20) DEFAULT NULL,
  `email` varchar(100) DEFAULT NULL,
  `customertype` varchar(50) DEFAULT NULL,
  `notes` text,
  `tax_number` varchar(50) DEFAULT NULL,
  `credit_limit` decimal(12,2) DEFAULT '0.00',
  `payment_terms` int DEFAULT '30',
  `preferred_payment_method` varchar(50) DEFAULT NULL,
  `customer_since` date DEFAULT NULL,
  `total_lifetime_value` decimal(12,2) DEFAULT '0.00',
  `last_job_date` date DEFAULT NULL,
  `rating` decimal(3,1) DEFAULT '5.0',
  `billing_address` text,
  `shipping_address` text,
  PRIMARY KEY (`customerID`),
  KEY `idx_customers_search_company` (`companyname`),
  KEY `idx_customers_search_name` (`firstname`,`lastname`),
  KEY `idx_customers_email` (`email`),
  FULLTEXT KEY `idx_customers_search` (`companyname`,`firstname`,`lastname`,`email`)
) ENGINE=InnoDB AUTO_INCREMENT=68 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `jobs`
--

DROP TABLE IF EXISTS `jobs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `jobs` (
  `jobID` int NOT NULL AUTO_INCREMENT,
  `customerID` int DEFAULT NULL,
  `startDate` date DEFAULT NULL,
  `endDate` date DEFAULT NULL,
  `statusID` int DEFAULT NULL,
  `jobcategoryID` int DEFAULT NULL,
  `created_by` bigint unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` bigint unsigned DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `description` varchar(50) DEFAULT NULL,
  `discount` decimal(10,2) DEFAULT '0.00',
  `discount_type` enum('percent','amount') DEFAULT 'amount',
  `revenue` decimal(12,2) NOT NULL DEFAULT '0.00' COMMENT 'Tatsächliche Einnahmen des Jobs in EUR',
  `final_revenue` decimal(10,2) DEFAULT NULL COMMENT 'Netto-Umsatz nach Rabatt',
  `priority` enum('low','normal','high','urgent') DEFAULT 'normal',
  `internal_notes` text,
  `customer_notes` text,
  `estimated_revenue` decimal(12,2) DEFAULT NULL,
  `actual_cost` decimal(12,2) DEFAULT '0.00',
  `profit_margin` decimal(5,2) DEFAULT NULL,
  `contract_signed` tinyint(1) DEFAULT '0',
  `contract_documentID` int DEFAULT NULL,
  `completion_percentage` int DEFAULT '0',
  `job_code` varchar(16) NOT NULL,
  PRIMARY KEY (`jobID`),
  UNIQUE KEY `ux_jobs_job_code` (`job_code`),
  KEY `idx_jobs_customerID` (`customerID`),
  KEY `idx_jobs_jobcategoryID` (`jobcategoryID`),
  KEY `statusID` (`statusID`),
  KEY `contract_documentID` (`contract_documentID`),
  KEY `idx_jobs_statusid` (`statusID`),
  KEY `idx_jobs_dates` (`startDate`,`endDate`),
  KEY `idx_jobs_status` (`statusID`),
  KEY `idx_created_by` (`created_by`),
  KEY `idx_updated_by` (`updated_by`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_updated_at` (`updated_at`),
  FULLTEXT KEY `idx_jobs_search` (`description`,`internal_notes`,`customer_notes`),
  CONSTRAINT `fk_jobs_created_by` FOREIGN KEY (`created_by`) REFERENCES `users` (`userID`) ON DELETE SET NULL,
  CONSTRAINT `fk_jobs_updated_by` FOREIGN KEY (`updated_by`) REFERENCES `users` (`userID`) ON DELETE SET NULL,
  CONSTRAINT `jobs_ibfk_1` FOREIGN KEY (`customerID`) REFERENCES `customers` (`customerID`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `jobs_ibfk_2` FOREIGN KEY (`jobcategoryID`) REFERENCES `jobCategory` (`jobcategoryID`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `jobs_ibfk_3` FOREIGN KEY (`statusID`) REFERENCES `status` (`statusID`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `jobs_ibfk_5` FOREIGN KEY (`contract_documentID`) REFERENCES `documents` (`documentID`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=1119 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `jobdevices`
--

DROP TABLE IF EXISTS `jobdevices`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `jobdevices` (
  `jobID` int NOT NULL,
  `deviceID` varchar(50) NOT NULL,
  `custom_price` decimal(10,2) DEFAULT NULL,
  `package_id` int DEFAULT NULL COMMENT 'If set, this device comes from a package and should not count in revenue',
  `is_package_item` tinyint(1) DEFAULT '0' COMMENT 'TRUE if this device is from a package (for UI display)',
  `pack_status` enum('pending','packed','issued','returned') NOT NULL DEFAULT 'pending',
  `pack_ts` datetime DEFAULT NULL,
  PRIMARY KEY (`jobID`,`deviceID`),
  KEY `deviceID` (`deviceID`),
  KEY `idx_jobdevices_deviceid` (`deviceID`),
  KEY `idx_jobdevices_jobid` (`jobID`),
  KEY `idx_jobdevices_composite` (`deviceID`,`jobID`),
  KEY `idx_jobdevices_job` (`jobID`),
  KEY `idx_jobdevices_device` (`deviceID`),
  KEY `idx_jobdevices_pack_status` (`pack_status`),
  KEY `idx_jobdevices_job_pack` (`jobID`,`pack_status`),
  KEY `idx_package_id` (`package_id`),
  CONSTRAINT `jobdevices_ibfk_2` FOREIGN KEY (`jobID`) REFERENCES `jobs` (`jobID`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `jobdevices_ibfk_3` FOREIGN KEY (`deviceID`) REFERENCES `devices` (`deviceID`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `categories`
--

DROP TABLE IF EXISTS `categories`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `categories` (
  `categoryID` int NOT NULL AUTO_INCREMENT,
  `name` varchar(20) NOT NULL,
  `abbreviation` varchar(3) NOT NULL,
  PRIMARY KEY (`categoryID`)
) ENGINE=InnoDB AUTO_INCREMENT=1008 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `subcategories`
--

DROP TABLE IF EXISTS `subcategories`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `subcategories` (
  `subcategoryID` varchar(50) NOT NULL,
  `name` varchar(20) NOT NULL,
  `abbreviation` varchar(3) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL,
  `categoryID` int DEFAULT NULL,
  PRIMARY KEY (`subcategoryID`),
  KEY `categoryID` (`categoryID`),
  CONSTRAINT `subcategories_ibfk_1` FOREIGN KEY (`categoryID`) REFERENCES `categories` (`categoryID`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `subbiercategories`
--

DROP TABLE IF EXISTS `subbiercategories`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `subbiercategories` (
  `subbiercategoryID` varchar(50) NOT NULL,
  `name` varchar(20) DEFAULT NULL,
  `abbreviation` varchar(3) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL,
  `subcategoryID` varchar(50) NOT NULL,
  PRIMARY KEY (`subbiercategoryID`),
  KEY `idx_subbiercategories_subcategoyID_unique` (`subcategoryID`) USING BTREE,
  CONSTRAINT `subbiercategories_ibfk_1` FOREIGN KEY (`subcategoryID`) REFERENCES `subcategories` (`subcategoryID`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `brands`
--

DROP TABLE IF EXISTS `brands`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `brands` (
  `brandID` int NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `manufacturerID` int DEFAULT NULL,
  PRIMARY KEY (`brandID`),
  KEY `idx_brands_manufacturerID` (`manufacturerID`),
  CONSTRAINT `brands_ibfk_1` FOREIGN KEY (`manufacturerID`) REFERENCES `manufacturer` (`manufacturerID`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB AUTO_INCREMENT=24 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `manufacturer`
--

DROP TABLE IF EXISTS `manufacturer`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `manufacturer` (
  `manufacturerID` int NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `website` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`manufacturerID`)
) ENGINE=InnoDB AUTO_INCREMENT=19 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `cases`
--

DROP TABLE IF EXISTS `cases`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `cases` (
  `caseID` int NOT NULL AUTO_INCREMENT,
  `name` varchar(30) NOT NULL,
  `description` text,
  `width` decimal(10,2) DEFAULT NULL,
  `height` decimal(10,2) DEFAULT NULL,
  `depth` decimal(10,2) DEFAULT NULL,
  `weight` decimal(10,2) DEFAULT NULL,
  `status` enum('free','rented','maintance','') NOT NULL,
  `zone_id` int DEFAULT NULL,
  `barcode` varchar(255) DEFAULT NULL,
  `rfid_tag` varchar(255) DEFAULT NULL,
  `label_path` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`caseID`),
  KEY `idx_case_zone` (`zone_id`)
) ENGINE=InnoDB AUTO_INCREMENT=1007 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `devicescases`
--

DROP TABLE IF EXISTS `devicescases`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `devicescases` (
  `caseID` int NOT NULL,
  `deviceID` varchar(50) NOT NULL,
  PRIMARY KEY (`caseID`,`deviceID`),
  KEY `deviceID` (`deviceID`),
  CONSTRAINT `devicescases_ibfk_1` FOREIGN KEY (`caseID`) REFERENCES `cases` (`caseID`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `devicescases_ibfk_2` FOREIGN KEY (`deviceID`) REFERENCES `devices` (`deviceID`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `cable_connectors`
--

DROP TABLE IF EXISTS `cable_connectors`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `cable_connectors` (
  `cable_connectorsID` int NOT NULL AUTO_INCREMENT,
  `name` varchar(30) NOT NULL,
  `abbreviation` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL,
  `gender` enum('male','female') CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL,
  PRIMARY KEY (`cable_connectorsID`)
) ENGINE=InnoDB AUTO_INCREMENT=1030 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `cable_types`
--

DROP TABLE IF EXISTS `cable_types`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `cable_types` (
  `cable_typesID` int NOT NULL AUTO_INCREMENT,
  `name` varchar(30) NOT NULL,
  PRIMARY KEY (`cable_typesID`)
) ENGINE=InnoDB AUTO_INCREMENT=1012 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `status`
--

DROP TABLE IF EXISTS `status`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `status` (
  `statusID` int NOT NULL AUTO_INCREMENT,
  `status` varchar(11) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  PRIMARY KEY (`statusID`)
) ENGINE=InnoDB AUTO_INCREMENT=1006 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `userID` bigint unsigned NOT NULL AUTO_INCREMENT,
  `username` varchar(191) NOT NULL,
  `email` varchar(191) NOT NULL,
  `password_hash` longtext NOT NULL,
  `first_name` longtext,
  `last_name` longtext,
  `is_active` tinyint(1) DEFAULT '1',
  `created_at` datetime(3) DEFAULT NULL,
  `updated_at` datetime(3) DEFAULT NULL,
  `last_login` datetime(3) DEFAULT NULL,
  `timezone` varchar(50) DEFAULT 'Europe/Berlin',
  `language` varchar(5) DEFAULT 'en',
  `avatar_path` varchar(500) DEFAULT NULL,
  `notification_preferences` json DEFAULT NULL,
  `last_active` timestamp NULL DEFAULT NULL,
  `login_attempts` int DEFAULT '0',
  `locked_until` timestamp NULL DEFAULT NULL,
  `two_factor_enabled` tinyint(1) DEFAULT '0',
  `two_factor_secret` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`userID`),
  UNIQUE KEY `username` (`username`),
  UNIQUE KEY `email` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=23 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `roles`
--

DROP TABLE IF EXISTS `roles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `roles` (
  `roleID` int NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `display_name` varchar(100) NOT NULL,
  `description` text,
  `permissions` json NOT NULL,
  `is_system_role` tinyint(1) DEFAULT '0',
  `is_active` tinyint(1) DEFAULT '1',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`roleID`),
  UNIQUE KEY `name` (`name`),
  KEY `idx_active_system` (`is_active`,`is_system_role`)
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `user_roles`
--

DROP TABLE IF EXISTS `user_roles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_roles` (
  `userID` bigint unsigned NOT NULL,
  `roleID` int NOT NULL,
  `assigned_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `assigned_by` bigint unsigned DEFAULT NULL,
  `expires_at` timestamp NULL DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT '1',
  PRIMARY KEY (`userID`,`roleID`),
  KEY `assigned_by` (`assigned_by`),
  KEY `idx_user_active` (`userID`,`is_active`),
  KEY `idx_role_active` (`roleID`,`is_active`),
  CONSTRAINT `user_roles_ibfk_1` FOREIGN KEY (`userID`) REFERENCES `users` (`userID`) ON DELETE CASCADE,
  CONSTRAINT `user_roles_ibfk_2` FOREIGN KEY (`roleID`) REFERENCES `roles` (`roleID`) ON DELETE CASCADE,
  CONSTRAINT `user_roles_ibfk_3` FOREIGN KEY (`assigned_by`) REFERENCES `users` (`userID`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `user_profiles`
--

DROP TABLE IF EXISTS `user_profiles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_profiles` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` bigint unsigned NOT NULL COMMENT 'FK to users.userID',
  `display_name` varchar(128) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Custom display name',
  `avatar_url` varchar(512) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Avatar image URL',
  `prefs` json DEFAULT NULL COMMENT 'UI preferences (dark mode, table density, etc.)',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `user_id` (`user_id`),
  KEY `idx_user_profile_user_id` (`user_id`),
  CONSTRAINT `fk_user_profiles_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`userID`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='WarehouseCore-specific user profiles';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `employee`
--

DROP TABLE IF EXISTS `employee`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `employee` (
  `employeeID` int NOT NULL AUTO_INCREMENT,
  `firstname` varchar(50) NOT NULL,
  `lastname` varchar(50) NOT NULL,
  `street` varchar(100) DEFAULT NULL,
  `housenumber` varchar(20) DEFAULT NULL,
  `ZIP` varchar(20) DEFAULT NULL,
  `city` varchar(50) DEFAULT NULL,
  `federalstate` varchar(50) DEFAULT NULL,
  `country` varchar(50) DEFAULT NULL,
  `phonenumber` varchar(20) DEFAULT NULL,
  `email` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`employeeID`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `employeejob`
--

DROP TABLE IF EXISTS `employeejob`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `employeejob` (
  `employeeID` int NOT NULL,
  `jobID` int NOT NULL,
  PRIMARY KEY (`employeeID`,`jobID`),
  KEY `idx_employeejob_jobID` (`jobID`),
  CONSTRAINT `employeejob_ibfk_1` FOREIGN KEY (`employeeID`) REFERENCES `employee` (`employeeID`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `employeejob_ibfk_2` FOREIGN KEY (`jobID`) REFERENCES `jobs` (`jobID`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `storage_zones`
--

DROP TABLE IF EXISTS `storage_zones`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `storage_zones` (
  `zone_id` int NOT NULL AUTO_INCREMENT,
  `code` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Short code: SHELF-A1, RACK-B2, VAN-01',
  `barcode` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `type` enum('warehouse','rack','gitterbox','shelf','vehicle','stage','case','other') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'other',
  `description` text COLLATE utf8mb4_unicode_ci,
  `parent_zone_id` int DEFAULT NULL COMMENT 'For hierarchical zones (e.g., shelf inside warehouse)',
  `capacity` int DEFAULT NULL COMMENT 'Maximum items this zone can hold',
  `location` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Physical location description',
  `metadata` json DEFAULT NULL COMMENT 'Flexible attributes (GPS, dimensions, etc.)',
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`zone_id`),
  UNIQUE KEY `code` (`code`),
  KEY `idx_zone_type` (`type`),
  KEY `idx_zone_active` (`is_active`),
  KEY `idx_zone_parent` (`parent_zone_id`),
  KEY `idx_zone_barcode` (`barcode`),
  CONSTRAINT `storage_zones_ibfk_1` FOREIGN KEY (`parent_zone_id`) REFERENCES `storage_zones` (`zone_id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `zone_types`
--

DROP TABLE IF EXISTS `zone_types`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `zone_types` (
  `id` int NOT NULL AUTO_INCREMENT,
  `key` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Machine-readable key: shelf, bin, eurobox, etc.',
  `label` varchar(128) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Display name',
  `description` text COLLATE utf8mb4_unicode_ci COMMENT 'Detailed description',
  `default_led_pattern` enum('solid','breathe','blink') COLLATE utf8mb4_unicode_ci DEFAULT 'breathe',
  `default_led_color` varchar(9) COLLATE utf8mb4_unicode_ci DEFAULT '#FF7A00',
  `default_intensity` tinyint unsigned DEFAULT '180',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `key` (`key`),
  KEY `idx_zone_type_key` (`key`)
) ENGINE=InnoDB AUTO_INCREMENT=25 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Configurable zone types with LED defaults';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `led_controllers`
--

DROP TABLE IF EXISTS `led_controllers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `led_controllers` (
  `id` int NOT NULL AUTO_INCREMENT,
  `controller_id` varchar(128) COLLATE utf8mb4_unicode_ci NOT NULL,
  `display_name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `topic_suffix` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `last_seen` datetime DEFAULT NULL,
  `ip_address` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `hostname` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `firmware_version` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `mac_address` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `metadata` json DEFAULT NULL,
  `status_data` json DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `controller_id` (`controller_id`),
  KEY `idx_led_controllers_last_seen` (`last_seen`)
) ENGINE=InnoDB AUTO_INCREMENT=42 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `led_controller_zone_types`
--

DROP TABLE IF EXISTS `led_controller_zone_types`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `led_controller_zone_types` (
  `controller_id` int NOT NULL,
  `zone_type_id` int NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`controller_id`,`zone_type_id`),
  KEY `fk_led_controller_zone_types_zone_type` (`zone_type_id`),
  CONSTRAINT `fk_led_controller_zone_types_controller` FOREIGN KEY (`controller_id`) REFERENCES `led_controllers` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_led_controller_zone_types_zone_type` FOREIGN KEY (`zone_type_id`) REFERENCES `zone_types` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `product_packages`
--

DROP TABLE IF EXISTS `product_packages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `product_packages` (
  `package_id` int NOT NULL AUTO_INCREMENT,
  `product_id` int DEFAULT NULL,
  `package_code` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `website_visible` tinyint(1) NOT NULL DEFAULT '0',
  `price` decimal(10,2) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`package_id`),
  UNIQUE KEY `uq_product_package_code` (`package_code`),
  KEY `idx_name` (`name`),
  KEY `idx_product_id` (`product_id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `product_package_items`
--

DROP TABLE IF EXISTS `product_package_items`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `product_package_items` (
  `package_item_id` int NOT NULL AUTO_INCREMENT,
  `package_id` int NOT NULL,
  `product_id` int NOT NULL,
  `quantity` int NOT NULL DEFAULT '1',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`package_item_id`),
  UNIQUE KEY `unique_package_product` (`package_id`,`product_id`),
  KEY `idx_package_id` (`package_id`),
  KEY `idx_product_id` (`product_id`),
  CONSTRAINT `product_package_items_ibfk_1` FOREIGN KEY (`package_id`) REFERENCES `product_packages` (`package_id`) ON DELETE CASCADE,
  CONSTRAINT `product_package_items_ibfk_2` FOREIGN KEY (`product_id`) REFERENCES `products` (`productID`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=32 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `package_devices`
--

DROP TABLE IF EXISTS `package_devices`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `package_devices` (
  `packageID` int NOT NULL,
  `deviceID` varchar(50) NOT NULL,
  `quantity` int unsigned NOT NULL DEFAULT '1',
  `custom_price` decimal(12,2) DEFAULT NULL COMMENT 'Override price for this device in package',
  `is_required` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Whether device is required (1) or optional (0)',
  `notes` text COMMENT 'Special notes about this device in package',
  `sort_order` int unsigned DEFAULT NULL COMMENT 'Display order within package',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`packageID`,`deviceID`),
  KEY `idx_package_devices_package` (`packageID`),
  KEY `idx_package_devices_device` (`deviceID`),
  KEY `idx_package_devices_required` (`is_required`),
  KEY `idx_package_devices_sort` (`sort_order`),
  CONSTRAINT `fk_package_devices_device` FOREIGN KEY (`deviceID`) REFERENCES `devices` (`deviceID`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_package_devices_package` FOREIGN KEY (`packageID`) REFERENCES `equipment_packages` (`packageID`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `package_categories`
--

DROP TABLE IF EXISTS `package_categories`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `package_categories` (
  `categoryID` int NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `description` text,
  `color` varchar(7) DEFAULT NULL COMMENT 'Hex color code for UI (#007bff)',
  `sort_order` int unsigned DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`categoryID`),
  UNIQUE KEY `uk_package_categories_name` (`name`),
  KEY `idx_package_categories_active` (`is_active`),
  KEY `idx_package_categories_sort` (`sort_order`)
) ENGINE=InnoDB AUTO_INCREMENT=43 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `job_attachments`
--

DROP TABLE IF EXISTS `job_attachments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `job_attachments` (
  `attachment_id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `job_id` int NOT NULL,
  `filename` varchar(255) NOT NULL,
  `original_filename` varchar(255) NOT NULL,
  `file_path` varchar(500) NOT NULL,
  `file_size` bigint NOT NULL,
  `mime_type` varchar(100) NOT NULL,
  `uploaded_by` bigint unsigned DEFAULT NULL,
  `uploaded_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `description` text,
  `is_active` tinyint(1) DEFAULT '1',
  PRIMARY KEY (`attachment_id`),
  KEY `uploaded_by` (`uploaded_by`),
  KEY `idx_job_attachments_job_id` (`job_id`),
  KEY `idx_job_attachments_uploaded_at` (`uploaded_at`),
  CONSTRAINT `job_attachments_ibfk_1` FOREIGN KEY (`job_id`) REFERENCES `jobs` (`jobID`) ON DELETE CASCADE,
  CONSTRAINT `job_attachments_ibfk_2` FOREIGN KEY (`uploaded_by`) REFERENCES `users` (`userID`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=62 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `job_history`
--

DROP TABLE IF EXISTS `job_history`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `job_history` (
  `history_id` bigint NOT NULL AUTO_INCREMENT,
  `job_id` int NOT NULL,
  `user_id` bigint unsigned DEFAULT NULL,
  `changed_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `change_type` enum('created','updated','status_changed','device_added','device_removed','deleted') COLLATE utf8mb4_unicode_ci NOT NULL,
  `field_name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `old_value` text COLLATE utf8mb4_unicode_ci,
  `new_value` text COLLATE utf8mb4_unicode_ci,
  `description` text COLLATE utf8mb4_unicode_ci,
  `ip_address` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_agent` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`history_id`),
  KEY `idx_job_id` (`job_id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_changed_at` (`changed_at`),
  CONSTRAINT `job_history_ibfk_1` FOREIGN KEY (`job_id`) REFERENCES `jobs` (`jobID`) ON DELETE CASCADE,
  CONSTRAINT `job_history_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`userID`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `job_packages`
--

DROP TABLE IF EXISTS `job_packages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `job_packages` (
  `job_package_id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `job_id` int NOT NULL,
  `package_id` int NOT NULL,
  `quantity` int NOT NULL DEFAULT '1',
  `custom_price` decimal(12,2) DEFAULT NULL COMMENT 'Override package price for this job',
  `added_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `added_by` bigint unsigned DEFAULT NULL,
  `notes` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`job_package_id`),
  KEY `idx_job_packages_job` (`job_id`),
  KEY `idx_job_packages_package` (`package_id`),
  CONSTRAINT `fk_job_packages_job` FOREIGN KEY (`job_id`) REFERENCES `jobs` (`jobID`) ON DELETE CASCADE,
  CONSTRAINT `fk_job_packages_package` FOREIGN KEY (`package_id`) REFERENCES `product_packages` (`package_id`) ON DELETE RESTRICT
) ENGINE=InnoDB AUTO_INCREMENT=99 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `jobCategory`
--

DROP TABLE IF EXISTS `jobCategory`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `jobCategory` (
  `jobcategoryID` int NOT NULL AUTO_INCREMENT,
  `name` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `abbreviation` varchar(3) DEFAULT NULL,
  PRIMARY KEY (`jobcategoryID`)
) ENGINE=InnoDB AUTO_INCREMENT=1006 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `device_movements`
--

DROP TABLE IF EXISTS `device_movements`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `device_movements` (
  `movement_id` bigint NOT NULL AUTO_INCREMENT,
  `device_id` varchar(50) NOT NULL,
  `action` enum('intake','outtake','transfer','return','move') NOT NULL,
  `from_zone_id` int DEFAULT NULL COMMENT 'Origin zone',
  `to_zone_id` int DEFAULT NULL COMMENT 'Destination zone',
  `from_job_id` bigint DEFAULT NULL COMMENT 'Job device came from',
  `to_job_id` bigint DEFAULT NULL COMMENT 'Job device went to',
  `barcode` varchar(255) DEFAULT NULL COMMENT 'Scanned barcode/QR code',
  `user_id` bigint DEFAULT NULL COMMENT 'User who performed the movement',
  `notes` text,
  `metadata` json DEFAULT NULL COMMENT 'Additional context',
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`movement_id`),
  KEY `idx_movement_device` (`device_id`),
  KEY `idx_movement_action` (`action`),
  KEY `idx_movement_timestamp` (`timestamp`),
  KEY `idx_movement_from_zone` (`from_zone_id`),
  KEY `idx_movement_to_zone` (`to_zone_id`),
  KEY `idx_movement_job` (`to_job_id`)
) ENGINE=InnoDB AUTO_INCREMENT=39 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `app_settings`
--

DROP TABLE IF EXISTS `app_settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `app_settings` (
  `id` int NOT NULL AUTO_INCREMENT,
  `scope` enum('global','warehousecore') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'warehousecore' COMMENT 'Setting scope',
  `k` varchar(128) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Setting key',
  `v` json NOT NULL COMMENT 'Setting value (JSON)',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_scope_key` (`scope`,`k`),
  KEY `idx_setting_key` (`k`)
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Application configuration settings';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `company_settings`
--

DROP TABLE IF EXISTS `company_settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `company_settings` (
  `id` int NOT NULL AUTO_INCREMENT,
  `company_name` longtext NOT NULL,
  `address_line1` longtext,
  `address_line2` longtext,
  `city` longtext,
  `state` longtext,
  `postal_code` longtext,
  `country` longtext,
  `phone` longtext,
  `email` longtext,
  `website` longtext,
  `tax_number` longtext,
  `vat_number` longtext,
  `logo_path` longtext,
  `created_at` datetime(3) DEFAULT NULL,
  `updated_at` datetime(3) DEFAULT NULL,
  `bank_name` longtext,
  `iban` longtext,
  `bic` longtext,
  `account_holder` longtext,
  `ceo_name` longtext,
  `register_court` longtext,
  `register_number` longtext,
  `footer_text` text,
  `payment_terms_text` text,
  `smtp_host` varchar(255) DEFAULT NULL,
  `smtp_port` int DEFAULT NULL,
  `smtp_username` varchar(255) DEFAULT NULL,
  `smtp_password` varchar(255) DEFAULT NULL,
  `smtp_from_email` varchar(255) DEFAULT NULL,
  `smtp_from_name` varchar(255) DEFAULT NULL,
  `smtp_use_tls` tinyint(1) DEFAULT '1',
  `brand_primary_color` varchar(7) DEFAULT NULL,
  `brand_accent_color` varchar(7) DEFAULT NULL,
  `brand_dark_mode` tinyint(1) NOT NULL DEFAULT '1',
  `brand_logo_url` varchar(500) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_company_settings_updated` (`updated_at`),
  KEY `idx_company_settings_iban` (`iban`(34)),
  KEY `idx_company_settings_register_number` (`register_number`(50))
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `invoice_settings`
--

DROP TABLE IF EXISTS `invoice_settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `invoice_settings` (
  `setting_id` int NOT NULL AUTO_INCREMENT,
  `setting_key` varchar(100) NOT NULL,
  `setting_value` text,
  `setting_type` enum('text','number','boolean','json') NOT NULL DEFAULT 'text',
  `description` text,
  `updated_by` bigint unsigned DEFAULT NULL,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`setting_id`),
  UNIQUE KEY `setting_key` (`setting_key`),
  KEY `idx_invoice_settings_key` (`setting_key`),
  KEY `invoice_settings_ibfk_1` (`updated_by`),
  CONSTRAINT `invoice_settings_ibfk_1` FOREIGN KEY (`updated_by`) REFERENCES `users` (`userID`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `invoice_templates`
--

DROP TABLE IF EXISTS `invoice_templates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `invoice_templates` (
  `template_id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `description` text,
  `html_template` longtext NOT NULL,
  `css_styles` longtext,
  `is_default` tinyint(1) NOT NULL DEFAULT '0',
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `created_by` bigint unsigned DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`template_id`),
  KEY `idx_invoice_templates_default` (`is_default`),
  KEY `idx_invoice_templates_active` (`is_active`),
  KEY `fk_invoice_templates_created_by` (`created_by`),
  CONSTRAINT `fk_invoice_templates_created_by` FOREIGN KEY (`created_by`) REFERENCES `users` (`userID`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `email_templates`
--

DROP TABLE IF EXISTS `email_templates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `email_templates` (
  `template_id` int unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `template_type` enum('invoice','reminder','payment_confirmation','general') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'general',
  `subject` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL,
  `html_content` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `text_content` longtext COLLATE utf8mb4_unicode_ci,
  `is_default` tinyint(1) NOT NULL DEFAULT '0',
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `created_by` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`template_id`),
  KEY `idx_email_templates_type` (`template_type`),
  KEY `idx_email_templates_default` (`is_default`),
  KEY `idx_email_templates_active` (`is_active`),
  KEY `idx_email_templates_created_by` (`created_by`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `label_templates`
--

DROP TABLE IF EXISTS `label_templates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `label_templates` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `width` decimal(10,2) NOT NULL COMMENT 'Width in millimeters',
  `height` decimal(10,2) NOT NULL COMMENT 'Height in millimeters',
  `template_json` longtext COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'JSON array of label elements',
  `is_default` tinyint(1) DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_is_default` (`is_default`),
  KEY `idx_name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `retention_policies`
--

DROP TABLE IF EXISTS `retention_policies`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `retention_policies` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `data_type` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `retention_period_days` int unsigned NOT NULL,
  `legal_basis` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL,
  `auto_delete` tinyint(1) DEFAULT '0',
  `policy_description` text COLLATE utf8mb4_unicode_ci,
  `effective_from` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `effective_until` timestamp NULL DEFAULT NULL,
  `created_by` bigint unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_active_policy` (`data_type`,`effective_until`),
  KEY `idx_retention_policies_type` (`data_type`),
  KEY `idx_retention_policies_effective` (`effective_from`,`effective_until`)
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `count_types`
--

DROP TABLE IF EXISTS `count_types`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `count_types` (
  `count_type_id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL COMMENT 'e.g., kg, piece, liter, meter',
  `abbreviation` varchar(10) NOT NULL COMMENT 'e.g., kg, pcs, L, m',
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`count_type_id`),
  UNIQUE KEY `unique_count_type_name` (`name`),
  UNIQUE KEY `unique_count_type_abbr` (`abbreviation`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Measurement units for accessories and consumables';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `documents`
--

DROP TABLE IF EXISTS `documents`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `documents` (
  `documentID` int NOT NULL AUTO_INCREMENT,
  `entity_type` enum('job','device','customer','user','system') NOT NULL,
  `entity_id` varchar(50) NOT NULL,
  `filename` varchar(255) NOT NULL,
  `original_filename` varchar(255) NOT NULL,
  `file_path` varchar(500) NOT NULL,
  `file_size` bigint NOT NULL,
  `mime_type` varchar(100) NOT NULL,
  `document_type` enum('contract','manual','photo','invoice','receipt','signature','other') NOT NULL,
  `description` text,
  `uploaded_by` bigint unsigned DEFAULT NULL,
  `uploaded_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `is_public` tinyint(1) DEFAULT '0',
  `version` int DEFAULT '1',
  `parent_documentID` int DEFAULT NULL,
  `checksum` varchar(64) DEFAULT NULL,
  PRIMARY KEY (`documentID`),
  KEY `uploaded_by` (`uploaded_by`),
  KEY `parent_documentID` (`parent_documentID`),
  KEY `idx_entity_type` (`entity_type`,`entity_id`,`document_type`),
  KEY `idx_uploaded_date` (`uploaded_at`,`document_type`),
  KEY `idx_filename` (`filename`),
  KEY `idx_documents_entity` (`entity_type`,`entity_id`,`document_type`),
  KEY `idx_documents_date` (`uploaded_at`,`document_type`),
  CONSTRAINT `documents_ibfk_1` FOREIGN KEY (`uploaded_by`) REFERENCES `users` (`userID`) ON DELETE SET NULL,
  CONSTRAINT `documents_ibfk_2` FOREIGN KEY (`parent_documentID`) REFERENCES `documents` (`documentID`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `insuranceprovider`
--

DROP TABLE IF EXISTS `insuranceprovider`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `insuranceprovider` (
  `insuranceproviderID` int NOT NULL AUTO_INCREMENT,
  `name` varchar(20) NOT NULL,
  `website` varchar(20) NOT NULL,
  `phonenumber` varchar(20) NOT NULL,
  PRIMARY KEY (`insuranceproviderID`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `insurances`
--

DROP TABLE IF EXISTS `insurances`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `insurances` (
  `insuranceID` int NOT NULL AUTO_INCREMENT,
  `name` varchar(20) NOT NULL,
  `insuranceproviderID` int NOT NULL,
  `policynumber` varchar(50) DEFAULT NULL,
  `coveragedetails` text,
  `validuntil` date DEFAULT NULL,
  `price` decimal(10,2) NOT NULL,
  PRIMARY KEY (`insuranceID`),
  KEY `insuranceproviderID` (`insuranceproviderID`),
  CONSTRAINT `insurances_ibfk_1` FOREIGN KEY (`insuranceproviderID`) REFERENCES `insuranceprovider` (`insuranceproviderID`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `rental_equipment`
--

DROP TABLE IF EXISTS `rental_equipment`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `rental_equipment` (
  `equipment_id` int unsigned NOT NULL AUTO_INCREMENT,
  `product_name` varchar(200) NOT NULL,
  `supplier_name` varchar(100) NOT NULL,
  `rental_price` decimal(12,2) NOT NULL DEFAULT '0.00',
  `customer_price` decimal(12,2) NOT NULL DEFAULT '0.00',
  `category` varchar(50) DEFAULT NULL,
  `description` varchar(1000) DEFAULT NULL,
  `notes` varchar(500) DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT '1',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `created_by` int unsigned DEFAULT NULL,
  PRIMARY KEY (`equipment_id`),
  KEY `idx_product_name` (`product_name`),
  KEY `idx_supplier_name` (`supplier_name`),
  KEY `idx_category` (`category`),
  KEY `idx_is_active` (`is_active`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `equipment_packages`
--

DROP TABLE IF EXISTS `equipment_packages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `equipment_packages` (
  `packageID` int NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `description` text,
  `categoryID` int DEFAULT NULL,
  `package_items` json NOT NULL,
  `package_price` decimal(12,2) DEFAULT NULL,
  `discount_percent` decimal(5,2) DEFAULT '0.00',
  `min_rental_days` int DEFAULT '1',
  `is_active` tinyint(1) DEFAULT '1',
  `created_by` bigint unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `usage_count` int DEFAULT '0',
  `max_rental_days` int DEFAULT NULL,
  `category` varchar(50) DEFAULT NULL,
  `tags` text,
  `last_used_at` timestamp NULL DEFAULT NULL,
  `total_revenue` decimal(12,2) DEFAULT '0.00',
  PRIMARY KEY (`packageID`),
  KEY `created_by` (`created_by`),
  KEY `idx_active_usage` (`is_active`,`usage_count` DESC),
  KEY `idx_equipment_packages_category` (`categoryID`),
  CONSTRAINT `equipment_packages_ibfk_1` FOREIGN KEY (`created_by`) REFERENCES `users` (`userID`) ON DELETE SET NULL,
  CONSTRAINT `fk_equipment_packages_category` FOREIGN KEY (`categoryID`) REFERENCES `package_categories` (`categoryID`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `api_keys`
--

DROP TABLE IF EXISTS `api_keys`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `api_keys` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `api_key_hash` char(64) COLLATE utf8mb4_unicode_ci NOT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `last_used_at` datetime DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_api_key_hash` (`api_key_hash`),
  KEY `idx_api_keys_active` (`is_active`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `invoices`
--

DROP TABLE IF EXISTS `invoices`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `invoices` (
  `invoice_id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `invoice_number` varchar(50) NOT NULL,
  `customer_id` int NOT NULL,
  `job_id` int DEFAULT NULL,
  `template_id` int DEFAULT NULL,
  `status` enum('draft','sent','paid','overdue','cancelled') NOT NULL DEFAULT 'draft',
  `issue_date` date NOT NULL,
  `due_date` date NOT NULL,
  `payment_terms` varchar(100) DEFAULT NULL,
  `subtotal` decimal(12,2) NOT NULL DEFAULT '0.00',
  `tax_rate` decimal(5,2) NOT NULL DEFAULT '0.00',
  `tax_amount` decimal(12,2) NOT NULL DEFAULT '0.00',
  `discount_amount` decimal(12,2) NOT NULL DEFAULT '0.00',
  `total_amount` decimal(12,2) NOT NULL DEFAULT '0.00',
  `paid_amount` decimal(12,2) NOT NULL DEFAULT '0.00',
  `balance_due` decimal(12,2) NOT NULL DEFAULT '0.00',
  `notes` text,
  `terms_conditions` text,
  `internal_notes` text,
  `sent_at` timestamp NULL DEFAULT NULL,
  `paid_at` timestamp NULL DEFAULT NULL,
  `created_by` bigint unsigned DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`invoice_id`),
  UNIQUE KEY `invoice_number` (`invoice_number`),
  KEY `idx_invoices_customer` (`customer_id`),
  KEY `idx_invoices_job` (`job_id`),
  KEY `idx_invoices_status` (`status`),
  KEY `idx_invoices_issue_date` (`issue_date`),
  KEY `idx_invoices_due_date` (`due_date`),
  KEY `idx_invoices_number` (`invoice_number`),
  KEY `fk_invoices_template` (`template_id`),
  KEY `invoices_ibfk_1` (`created_by`),
  CONSTRAINT `fk_invoices_customer` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`customerID`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_invoices_job` FOREIGN KEY (`job_id`) REFERENCES `jobs` (`jobID`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_invoices_template` FOREIGN KEY (`template_id`) REFERENCES `invoice_templates` (`template_id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `invoices_ibfk_1` FOREIGN KEY (`created_by`) REFERENCES `users` (`userID`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=31 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `invoice_line_items`
--

DROP TABLE IF EXISTS `invoice_line_items`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `invoice_line_items` (
  `line_item_id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `invoice_id` bigint unsigned NOT NULL,
  `item_type` enum('device','service','package','custom') NOT NULL DEFAULT 'custom',
  `device_id` varchar(50) DEFAULT NULL,
  `package_id` int DEFAULT NULL,
  `description` text NOT NULL,
  `quantity` decimal(10,2) NOT NULL DEFAULT '1.00',
  `unit_price` decimal(12,2) NOT NULL DEFAULT '0.00',
  `total_price` decimal(12,2) NOT NULL DEFAULT '0.00',
  `rental_start_date` date DEFAULT NULL,
  `rental_end_date` date DEFAULT NULL,
  `rental_days` int DEFAULT NULL,
  `sort_order` int unsigned DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`line_item_id`),
  KEY `idx_invoice_line_items_invoice` (`invoice_id`),
  KEY `idx_invoice_line_items_device` (`device_id`),
  KEY `idx_invoice_line_items_package` (`package_id`),
  KEY `idx_invoice_line_items_type` (`item_type`),
  CONSTRAINT `invoice_line_items_ibfk_1` FOREIGN KEY (`invoice_id`) REFERENCES `invoices` (`invoice_id`) ON DELETE CASCADE,
  CONSTRAINT `invoice_line_items_ibfk_2` FOREIGN KEY (`device_id`) REFERENCES `devices` (`deviceID`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `invoice_line_items_ibfk_3` FOREIGN KEY (`package_id`) REFERENCES `equipment_packages` (`packageID`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=33 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*M!100616 SET NOTE_VERBOSITY=@OLD_NOTE_VERBOSITY */;

-- Dump completed on 2025-12-12 21:59:04
