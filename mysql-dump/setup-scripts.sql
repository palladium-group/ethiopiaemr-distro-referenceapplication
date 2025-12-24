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

-- Fix appointments module missing SQL files issue
-- For the appointments module v2.1.0-20250318.070530-1, the patientPastAppointments.sql
-- and patientUpcomingAppointments.sql files in its JAR. We pre-populate the global
-- properties here so the module's liquibase changesets will be skipped.

-- Insert past appointments global property (if it doesn't exist)
INSERT INTO openmrs.global_property (property, property_value, description, uuid)
SELECT * FROM (
    SELECT
        'bahmni.sqlGet.pastAppointments' AS property,
        'SELECT
     app_service.name                                                                                AS `DASHBOARD_APPOINTMENTS_SERVICE_KEY`,
     app_service_type.name                                                                           AS `DASHBOARD_APPOINTMENTS_SERVICE_TYPE_KEY`,
     DATE_FORMAT(start_date_time, "%d/%m/%Y")                                                        AS `DASHBOARD_APPOINTMENTS_DATE_KEY`,
     CONCAT(DATE_FORMAT(start_date_time, "%l:%i %p"), " - ", DATE_FORMAT(end_date_time, "%l:%i %p")) AS `DASHBOARD_APPOINTMENTS_SLOT_KEY`,
     CONCAT(pn.given_name, '' '', pn.family_name)                                                      AS `DASHBOARD_APPOINTMENTS_PROVIDER_KEY`,
     pa.status                                                                                       AS `DASHBOARD_APPOINTMENTS_STATUS_KEY`
FROM
   patient_appointment pa
   JOIN person p ON p.person_id = pa.patient_id AND pa.voided IS FALSE
   JOIN appointment_service app_service
     ON app_service.appointment_service_id = pa.appointment_service_id AND app_service.voided IS FALSE
   LEFT JOIN patient_appointment_provider pap on pa.patient_appointment_id = pap.patient_appointment_id AND (pap.voided=0 OR pap.voided IS NULL)
   LEFT JOIN provider prov ON prov.provider_id = pap.provider_id AND prov.retired IS FALSE
   LEFT JOIN person_name pn ON pn.person_id = prov.person_id AND pn.voided IS FALSE
   LEFT JOIN appointment_service_type app_service_type
     ON app_service_type.appointment_service_type_id = pa.appointment_service_type_id
 WHERE p.uuid = ${patientUuid} AND start_date_time < CURDATE() AND (app_service_type.voided IS FALSE OR app_service_type.voided IS NULL)
 ORDER BY start_date_time DESC
 LIMIT 5;' AS property_value,
        'Past appointments for patient' AS description,
        uuid() AS uuid
) AS tmp
WHERE NOT EXISTS (
    SELECT 1 FROM openmrs.global_property WHERE property = 'bahmni.sqlGet.pastAppointments'
);

-- Insert upcoming appointments global property (if it doesn't exist)
INSERT INTO openmrs.global_property (property, property_value, description, uuid)
SELECT * FROM (
    SELECT
        'bahmni.sqlGet.upComingAppointments' AS property,
        'SELECT
          app_service.name                                                                                AS `DASHBOARD_APPOINTMENTS_SERVICE_KEY`,
          app_service_type.name                                                                           AS `DASHBOARD_APPOINTMENTS_SERVICE_TYPE_KEY`,
          DATE_FORMAT(start_date_time, "%d/%m/%Y")                                                        AS `DASHBOARD_APPOINTMENTS_DATE_KEY`,
          CONCAT(DATE_FORMAT(start_date_time, "%l:%i %p"), " - ", DATE_FORMAT(end_date_time, "%l:%i %p")) AS `DASHBOARD_APPOINTMENTS_SLOT_KEY`,
          CONCAT(pn.given_name, " ", pn.family_name)                                                      AS `DASHBOARD_APPOINTMENTS_PROVIDER_KEY`,
  pa.status                                                                                       AS `DASHBOARD_APPOINTMENTS_STATUS_KEY`
FROM
  patient_appointment pa
  JOIN person p ON p.person_id = pa.patient_id AND pa.voided IS FALSE
  JOIN appointment_service app_service
    ON app_service.appointment_service_id = pa.appointment_service_id AND app_service.voided IS FALSE
  LEFT JOIN patient_appointment_provider pap on pa.patient_appointment_id = pap.patient_appointment_id AND (pap.voided=0 OR pap.voided IS NULL)
  LEFT JOIN provider prov ON prov.provider_id = pap.provider_id AND prov.retired IS FALSE
  LEFT JOIN person_name pn ON pn.person_id = prov.person_id AND pn.voided IS FALSE
  LEFT JOIN appointment_service_type app_service_type
    ON app_service_type.appointment_service_type_id = pa.appointment_service_type_id
WHERE p.uuid = ${patientUuid} AND
      start_date_time >= CURDATE() AND
      (app_service_type.voided IS FALSE OR app_service_type.voided IS NULL)
ORDER BY start_date_time ASC;' AS property_value,
        'Upcoming appointments for patient' AS description,
        uuid() AS uuid
) AS tmp
WHERE NOT EXISTS (
    SELECT 1 FROM openmrs.global_property WHERE property = 'bahmni.sqlGet.upComingAppointments'
);

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

