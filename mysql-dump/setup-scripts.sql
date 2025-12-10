-- ============================================================================
-- OpenMRS Database Setup Script
-- ============================================================================
-- Sets up databases and performs data cleanup for EthiopiaEMR.
-- Safe to re-run (idempotent). Requires MySQL 8.0+ for SYSTEM_USER privilege.
-- ============================================================================

-- Database Creation
-- Create supporting databases for ETL and datatools functionality
create database if not exists kenyaemr_datatools;
create database if not exists kenyaemr_etl;

-- User Creation
-- Create database users (empty passwords - configure for production)
CREATE USER IF NOT EXISTS 'openmrs' @'%' IDENTIFIED BY '';
CREATE USER IF NOT EXISTS 'openmrs_user' @'%' IDENTIFIED BY '';

-- Privilege Assignment
-- Grant database and system privileges
GRANT ALL PRIVILEGES ON kenyaemr_datatools.* TO 'openmrs' @'%';
GRANT ALL PRIVILEGES ON kenyaemr_etl.* TO 'openmrs' @'%';
GRANT ALL PRIVILEGES ON *.* TO 'openmrs_user' @'%';

-- Grant SYSTEM_USER privilege (required for MySQL 8.0+ to drop procedures)
GRANT SYSTEM_USER ON *.* TO 'openmrs' @'%';
FLUSH PRIVILEGES;

-- Grant TRIGGER and SYSTEM_VARIABLES_ADMIN privileges
GRANT TRIGGER,
    SYSTEM_VARIABLES_ADMIN ON *.* TO 'openmrs' @'%';
FLUSH PRIVILEGES;

-- Data Cleanup
-- Remove specific records that may cause conflicts during deployment
use openmrs;

-- Remove conflicting location tag
delete from location_tag
where uuid = 'efa4143f-c6ae-44b5-8ce5-45cbdbbda934';

-- Clear Liquibase changelog entries to allow module re-initialization
delete from liquibasechangelog where id like '%charts%';
DELETE FROM liquibasechangelog WHERE id LIKE 'kenyaemrIL%';

-- Safe Deletion Operations
-- Delete with table existence checks (safe for different database states)

-- Clear Stock Management module changesets to fix Liquibase validation errors
SET @table_exists = (
        SELECT COUNT(*)
        FROM information_schema.tables
        WHERE table_schema = 'openmrs'
            AND table_name = 'liquibasechangelog'
    );
SET @sql = IF(
        @table_exists > 0,
        'DELETE FROM openmrs.liquibasechangelog WHERE id LIKE ''stockmanagement%''',
        'SELECT ''Table openmrs.liquibasechangelog does not exist, skipping delete'' AS message'
    );
PREPARE stmt
FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Remove problematic concept reference mapping
SET @table_exists = (
        SELECT COUNT(*)
        FROM information_schema.tables
        WHERE table_schema = 'openmrs'
            AND table_name = 'concept_reference_map'
    );
SET @sql = IF(
        @table_exists > 0,
        'DELETE FROM openmrs.concept_reference_map WHERE concept_reference_term_id = 283809',
        'SELECT ''Table openmrs.concept_reference_map does not exist, skipping delete'' AS message'
    );
PREPARE stmt
FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Schema Modifications
-- Fix role column character set and collation in stockmgmt_user_role_scope
SET FOREIGN_KEY_CHECKS = 0;
ALTER TABLE openmrs.stockmgmt_user_role_scope
MODIFY COLUMN role VARCHAR(50) CHARACTER SET utf8mb3 COLLATE utf8_general_ci NOT NULL;
SET FOREIGN_KEY_CHECKS = 1;

-- Final Privilege Configuration
-- Grant SUPER privilege (powerful - use granular privileges in production if possible)

GRANT SUPER ON *.* TO 'openmrs'@'%';
FLUSH PRIVILEGES;

