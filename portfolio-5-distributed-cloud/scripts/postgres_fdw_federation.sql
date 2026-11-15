-- ============================================================================
-- MIT 8103: Advanced Database Systems
-- Continuous Assessment (CA) - September Cohort 2026
-- Student: Patrick Filima
-- Institution: Miva Open University
-- Portfolio 5: Distributed and Cloud Database Exercise
-- File: postgres_fdw_federation.sql
-- 
-- System: African Neuroimaging Research Data Management System (ANRDMS)
-- Target DBMS: PostgreSQL 14+ (postgres_fdw extension)
-- Description: Demonstrates cross-node distributed database federation using
--              PostgreSQL Foreign Data Wrapper (postgres_fdw), remote query
--              pushdown optimization, and cross-site analytical federation.
-- ============================================================================

\set ECHO all
\timing on

-- ============================================================================
-- 1. FEDERATED DATABASE ARCHITECTURE & POSTGRES_FDW MOTIVATION
-- ============================================================================
-- In developing economies with distributed clinical infrastructure, centralizing
-- all raw neuroimaging data into a single physical database can cause severe
-- bandwidth bottlenecks across Nigerian WAN networks.
--
-- Foreign Data Wrapper (postgres_fdw, ISO/IEC 9075-9 SQL/MED standard) allows a
-- central national coordination portal to mount remote hospital database nodes
-- as transparent local foreign tables.
--
-- Crucially, postgres_fdw implements "Filter & Aggregation Pushdown":
-- Instead of dragging gigabytes of uncurated scan records across the WAN to
-- filter them locally, the central coordinator pushes the WHERE clause down
-- to the remote hospital node. Only matching rows are transferred over the wire.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- Drop foreign objects if they exist
DROP FOREIGN TABLE IF EXISTS foreign_abuja_mri_scans CASCADE;
DROP USER MAPPING IF EXISTS FOR CURRENT_USER SERVER remote_abuja_hospital_node;
DROP SERVER IF EXISTS remote_abuja_hospital_node CASCADE;

-- ============================================================================
-- 2. CONFIGURING REMOTE FOREIGN SERVER & USER MAPPING
-- ============================================================================
-- Simulate remote regional hospital node: National Hospital Abuja (NHA)
-- Connecting via local loopback to anrdms_transactions database

CREATE SERVER remote_abuja_hospital_node
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (
        dbname 'anrdms_transactions',
        host 'localhost',
        port '5432',
        fetch_size '100',
        use_remote_estimate 'true'
    );

CREATE USER MAPPING FOR CURRENT_USER
    SERVER remote_abuja_hospital_node
    OPTIONS (
        user 'patrick'
    );

-- ============================================================================
-- 3. MOUNTING REMOTE FOREIGN TABLE
-- ============================================================================
-- Transparently map the remote hospital node's mri_scans table

CREATE FOREIGN TABLE foreign_abuja_mri_scans (
    scan_id VARCHAR(30) NOT NULL,
    participant_id VARCHAR(25) NOT NULL,
    scanner_id VARCHAR(20) NOT NULL,
    project_id VARCHAR(20) NOT NULL,
    acquisition_date TIMESTAMPTZ NOT NULL,
    modality VARCHAR(10) NOT NULL,
    sequence_type VARCHAR(25) NOT NULL,
    repetition_time_ms NUMERIC(8,2) NOT NULL,
    echo_time_ms NUMERIC(6,2) NOT NULL,
    flip_angle_deg NUMERIC(4,1),
    voxel_size_x_mm NUMERIC(4,2) NOT NULL,
    voxel_size_y_mm NUMERIC(4,2) NOT NULL,
    voxel_size_z_mm NUMERIC(4,2) NOT NULL,
    matrix_x INT NOT NULL,
    matrix_y INT NOT NULL,
    slices_count INT NOT NULL,
    dicom_series_uid VARCHAR(120) NOT NULL,
    bids_relative_path VARCHAR(255) NOT NULL,
    file_size_bytes BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
)
SERVER remote_abuja_hospital_node
OPTIONS (
    table_name 'mri_scans'
);


-- ============================================================================
-- 4. FEDERATED QUERY EXECUTION & PUSHDOWN VERIFICATION
-- ============================================================================

-- ----------------------------------------------------------------------------
-- EXPERIMENT 1: Remote Filter Pushdown Demonstration
-- Expected Plan: Foreign Scan on foreign_abuja_mri_scans showing:
--   "Remote SQL: SELECT ... WHERE ((sequence_type = 'T1w'))"
-- Proves that filtering occurs on the remote node prior to WAN data transit.
-- ----------------------------------------------------------------------------
\echo '=== EXPERIMENT 1: Verifying Remote Filter Pushdown via EXPLAIN VERBOSE ==='
EXPLAIN (ANALYZE, VERBOSE, BUFFERS)
SELECT 
    scan_id,
    participant_id,
    sequence_type,
    repetition_time_ms,
    echo_time_ms,
    ROUND(file_size_bytes / (1024.0 * 1024.0), 2) AS file_size_mb
FROM foreign_abuja_mri_scans
WHERE sequence_type = 'T1w';

-- ----------------------------------------------------------------------------
-- EXPERIMENT 2: Cross-Node Distributed JOIN
-- Scenario: Join local national participant ethics registry with remote
-- hospital imaging scans.
-- ----------------------------------------------------------------------------
\echo '=== EXPERIMENT 2: Cross-Node Federated JOIN (Local Participants + Remote Scans) ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    p.participant_id,
    p.biological_sex,
    p.birth_year,
    f.scan_id,
    f.sequence_type,
    f.acquisition_date
FROM participants p
JOIN foreign_abuja_mri_scans f ON p.participant_id = f.participant_id
ORDER BY f.acquisition_date DESC
LIMIT 5;

-- Execute the federated query to inspect actual rows returned:
SELECT 
    p.participant_id,
    p.biological_sex,
    p.birth_year,
    f.scan_id,
    f.sequence_type,
    f.acquisition_date
FROM participants p
JOIN foreign_abuja_mri_scans f ON p.participant_id = f.participant_id
ORDER BY f.acquisition_date DESC
LIMIT 5;

\echo '=== POSTGRES_FDW FEDERATION DEMONSTRATION COMPLETE ==='
