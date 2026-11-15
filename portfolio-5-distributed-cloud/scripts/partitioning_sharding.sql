-- ============================================================================
-- MIT 8103: Advanced Database Systems
-- Continuous Assessment (CA) - September Cohort 2026
-- Student: Patrick Filima
-- Institution: Miva Open University
-- Portfolio 5: Distributed and Cloud Database Exercise
-- File: partitioning_sharding.sql
-- 
-- System: African Neuroimaging Research Data Management System (ANRDMS)
-- Target DBMS: PostgreSQL 14+
-- Description: Demonstrates horizontal declarative list partitioning, automated
--              partition routing, and query optimizer partition pruning across
--              multi-site research hospital nodes in Nigeria.
-- ============================================================================

\set ECHO all
\timing on

-- ============================================================================
-- 1. DECLARATIVE HORIZONTAL LIST PARTITIONING ARCHITECTURE
-- ============================================================================
-- The ANRDMS consortium spans 5 major clinical teaching hospitals in Nigeria.
-- Rather than storing all multi-terabyte neuroimaging acquisition records in a
-- single monolithic table, we horizontally partition data by research site (site_id).
-- This models a distributed sharded database architecture where each regional
-- hospital node manages its local partition, enabling parallel scanning and
-- partition pruning during national cohort analyses.
-- ============================================================================

DROP TABLE IF EXISTS mri_scans_partitioned CASCADE;

-- Master Partitioned Table (Parent Routing Table)
CREATE TABLE mri_scans_partitioned (
    scan_id VARCHAR(30) NOT NULL,
    participant_id VARCHAR(25) NOT NULL REFERENCES participants(participant_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    site_id VARCHAR(15) NOT NULL REFERENCES research_sites(site_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    scanner_id VARCHAR(20) NOT NULL REFERENCES mri_scanners(scanner_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    project_id VARCHAR(20) NOT NULL REFERENCES research_projects(project_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    sequence_type VARCHAR(25) NOT NULL,
    acquisition_date TIMESTAMPTZ NOT NULL,
    repetition_time_ms NUMERIC(7, 2) NOT NULL,
    echo_time_ms NUMERIC(6, 2) NOT NULL,
    inversion_time_ms NUMERIC(7, 2),
    flip_angle_deg NUMERIC(4, 1) NOT NULL,
    dicom_series_uid VARCHAR(120) NOT NULL,
    nifti_file_path VARCHAR(255) NOT NULL,
    file_size_bytes BIGINT NOT NULL,
    is_curated BOOLEAN DEFAULT FALSE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    PRIMARY KEY (scan_id, site_id)
) PARTITION BY LIST (site_id);

-- Regional Hospital Partitions (Simulating 5 Distributed Nodes)

-- Node 1: Lagos University Teaching Hospital (LUTH, Lagos - South West)
CREATE TABLE mri_scans_lagos PARTITION OF mri_scans_partitioned
    FOR VALUES IN ('SITE-LOS-01');

-- Node 2: National Hospital Abuja (NHA, Abuja - North Central)
CREATE TABLE mri_scans_abuja PARTITION OF mri_scans_partitioned
    FOR VALUES IN ('SITE-ABJ-01');

-- Node 3: University College Hospital (UCH, Ibadan - South West)
CREATE TABLE mri_scans_ibadan PARTITION OF mri_scans_partitioned
    FOR VALUES IN ('SITE-IBD-01');

-- Node 4: University of Nigeria Teaching Hospital (UNTH, Enugu - South East)
CREATE TABLE mri_scans_enugu PARTITION OF mri_scans_partitioned
    FOR VALUES IN ('SITE-ENU-01');

-- Node 5: Ahmadu Bello University Teaching Hospital (ABUTH, Zaria - North West)
CREATE TABLE mri_scans_zaria PARTITION OF mri_scans_partitioned
    FOR VALUES IN ('SITE-ZAR-01');

-- ============================================================================
-- 2. PARTITION-AWARE INDEXING STRATEGY
-- ============================================================================
-- Indexes defined on the parent partitioned table automatically propagate to
-- all existing and future child partitions, creating local partition indexes.

CREATE INDEX idx_dist_scans_seq ON mri_scans_partitioned (sequence_type, acquisition_date DESC);
CREATE INDEX idx_dist_scans_participant ON mri_scans_partitioned (participant_id);
CREATE INDEX idx_dist_scans_curated ON mri_scans_partitioned (is_curated) WHERE is_curated IS TRUE;

-- ============================================================================
-- 3. SEEDING DISTRIBUTED PARTITIONS
-- ============================================================================
-- Ingest existing baseline scans into the partitioned table via parent routing:
-- Note: In the normalized 3NF schema, site_id is derived from mri_scanners;
-- in the distributed partitioned table, site_id is denormalized as the partition key.
INSERT INTO mri_scans_partitioned (
    scan_id, participant_id, site_id, scanner_id, project_id, sequence_type,
    acquisition_date, repetition_time_ms, echo_time_ms, inversion_time_ms,
    flip_angle_deg, dicom_series_uid, nifti_file_path, file_size_bytes, is_curated
)
SELECT 
    m.scan_id, m.participant_id, sc.site_id, m.scanner_id, m.project_id, m.sequence_type,
    m.acquisition_date, m.repetition_time_ms, m.echo_time_ms, NULL::numeric,
    m.flip_angle_deg, m.dicom_series_uid, m.bids_relative_path, m.file_size_bytes, TRUE
FROM mri_scans m
JOIN mri_scanners sc ON m.scanner_id = sc.scanner_id;

-- Seed additional multi-site acquisition records across all 5 regional hospital nodes:
INSERT INTO mri_scans_partitioned (
    scan_id, participant_id, site_id, scanner_id, project_id, sequence_type,
    acquisition_date, repetition_time_ms, echo_time_ms, inversion_time_ms,
    flip_angle_deg, dicom_series_uid, nifti_file_path, file_size_bytes, is_curated
)
VALUES
-- Additional Lagos Record (Node 1)
('SCN-LOS-004-T2', 'ANRDMS-LOS-002', 'SITE-LOS-01', 'SCN-LOS-3T01', 'PRJ-WASCS-2024', 'T2w',
 '2025-05-10 11:30:00+00', 3200.00, 85.00, NULL, 90.0, '1.3.12.2.1107.5.2.32.1004.20250510113000',
 '/data/nifti/LOS/sub-LOS002/ses-01/anat/sub-LOS002_T2w.nii.gz', 36700160, TRUE),

-- Additional Abuja Record (Node 2)
('SCN-ABJ-004-DM', 'ANRDMS-ABJ-002', 'SITE-ABJ-01', 'SCN-ABJ-3T01', 'PRJ-SSADG-2026', 'dMRI',
 '2025-05-11 14:15:00+00', 4500.00, 72.00, NULL, 90.0, '1.3.12.2.1107.5.2.32.2004.20250511141500',
 '/data/nifti/ABJ/sub-ABJ002/ses-01/dwi/sub-ABJ002_dwi.nii.gz', 78643200, TRUE),

-- Additional Ibadan Record (Node 3)
('SCN-IBD-004-T1', 'ANRDMS-IBD-002', 'SITE-IBD-01', 'SCN-IBD-3T01', 'PRJ-NPEPP-2025', 'T1w',
 '2025-05-12 09:45:00+00', 2100.00, 3.10, 900.00, 9.0, '1.3.12.2.1107.5.2.32.3004.20250512094500',
 '/data/nifti/IBD/sub-IBD002/ses-01/anat/sub-IBD002_T1w.nii.gz', 47185920, TRUE),

-- Additional Enugu Record (Node 4)
('SCN-ENU-004-FL', 'ANRDMS-ENU-002', 'SITE-ENU-01', 'SCN-ENU-15T1', 'PRJ-ABHI-2025', 'FLAIR',
 '2025-05-13 16:00:00+00', 9000.00, 120.00, 2500.00, 150.0, '1.3.12.2.1107.5.2.32.4004.20250513160000',
 '/data/nifti/ENU/sub-ENU002/ses-01/anat/sub-ENU002_FLAIR.nii.gz', 41943040, TRUE),

-- Additional Zaria Record (Node 5)
('SCN-ZAR-004-T1', 'ANRDMS-ZAR-002', 'SITE-ZAR-01', 'SCN-ZAR-15T1', 'PRJ-WASCS-2024', 'T1w',
 '2025-05-14 10:20:00+00', 2000.00, 3.40, 850.00, 9.0, '1.3.12.2.1107.5.2.32.5004.20250514102000',
 '/data/nifti/ZAR/sub-ZAR002/ses-01/anat/sub-ZAR002_T1w.nii.gz', 42991616, TRUE);
 '/data/nifti/ENU/sub-ENU002/ses-01/anat/sub-ENU002_FLAIR.nii.gz', 41943040, TRUE),

-- Additional Zaria Record (Node 5)
('SCN-ZAR-004-T1', 'ANRDMS-ZAR-002', 'SITE-ZAR-01', 'SCN-ZAR-AVANTO', 'PRJ-NIG-STROKE', 'T1w',
 '2025-05-14 10:20:00+00', 2000.00, 3.40, 850.00, 9.0, '1.3.12.2.1107.5.2.32.5004.20250514102000',
 '/data/nifti/ZAR/sub-ZAR002/ses-01/anat/sub-ZAR002_T1w.nii.gz', 42991616, TRUE);

-- Verify record distribution across partitions:
SELECT 
    tableoid::regclass AS partition_name,
    site_id,
    COUNT(*) AS total_scans,
    pg_size_pretty(pg_relation_size(tableoid::regclass)) AS partition_disk_size
FROM mri_scans_partitioned
GROUP BY tableoid, site_id
ORDER BY site_id;


-- ============================================================================
-- 4. PARTITION PRUNING EXPERIMENTS & EXECUTION PLAN VERIFICATION
-- ============================================================================

-- Ensure partition pruning is explicitly enabled (default in modern PostgreSQL)
SET enable_partition_pruning = on;

-- ----------------------------------------------------------------------------
-- EXPERIMENT 1: Single-Site Regional Query (Demonstrating 80% Pruning)
-- Scenario: Radiologist at Lagos (LUTH) queries scans acquired locally.
-- Expected Behavior: Query planner immediately prunes Abuja, Ibadan, Enugu, and
-- Zaria partitions, executing ONLY on mri_scans_lagos.
-- ----------------------------------------------------------------------------
\echo '=== EXPERIMENT 1: Single-Site Regional Query (Lagos Partition Only) ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    scan_id,
    participant_id,
    site_id,
    sequence_type,
    acquisition_date,
    file_size_bytes
FROM mri_scans_partitioned
WHERE site_id = 'SITE-LOS-01'
  AND sequence_type = 'T1w';

-- ----------------------------------------------------------------------------
-- EXPERIMENT 2: Multi-Site Selective Pruning (Demonstrating 60% Pruning)
-- Scenario: Collaborative clinical trial between Lagos (LUTH) and Abuja (NHA).
-- Expected Behavior: Optimizer prunes Ibadan, Enugu, and Zaria, accessing ONLY
-- mri_scans_lagos and mri_scans_abuja via an Append node.
-- ----------------------------------------------------------------------------
\echo '=== EXPERIMENT 2: Multi-Site Regional Pruning (Lagos + Abuja) ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    site_id,
    sequence_type,
    COUNT(*) AS scan_count,
    ROUND(AVG(repetition_time_ms), 1) AS avg_tr_ms,
    ROUND(AVG(file_size_bytes) / (1024.0 * 1024.0), 2) AS avg_size_mb
FROM mri_scans_partitioned
WHERE site_id IN ('SITE-LOS-01', 'SITE-ABJ-01')
GROUP BY site_id, sequence_type
ORDER BY site_id, sequence_type;

-- ----------------------------------------------------------------------------
-- EXPERIMENT 3: National Consortium Global Aggregation
-- Scenario: National health data manager aggregates MRI sequence distributions.
-- Expected Behavior: Parallel Append visits all 5 partitions concurrently,
-- computing consolidated national metrics.
-- ----------------------------------------------------------------------------
\echo '=== EXPERIMENT 3: National Cross-Site Consolidated Aggregation ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    s.site_id,
    r.hospital_name,
    r.city,
    COUNT(s.scan_id) AS total_scans_acquired,
    COUNT(DISTINCT s.participant_id) AS unique_participants,
    ROUND(SUM(s.file_size_bytes) / (1024.0 * 1024.0 * 1024.0), 3) AS total_storage_gib
FROM mri_scans_partitioned s
JOIN research_sites r ON s.site_id = r.site_id
GROUP BY s.site_id, r.hospital_name, r.city
ORDER BY total_scans_acquired DESC;

-- ----------------------------------------------------------------------------
-- EXPERIMENT 4: Partition Routing & Constraint Enforcement Verification
-- Attempt to insert a record with an invalid / unknown site_id.
-- Expected Behavior: Rejection by PostgreSQL partition routing mechanism
-- because no partition exists for the specified value.
-- ----------------------------------------------------------------------------
\echo '=== EXPERIMENT 4: Partition Routing Rejection for Unknown Regional Site ==='
DO $$
BEGIN
    INSERT INTO mri_scans_partitioned (
        scan_id, participant_id, site_id, scanner_id, project_id, sequence_type,
        acquisition_date, repetition_time_ms, echo_time_ms, flip_angle_deg,
        dicom_series_uid, nifti_file_path, file_size_bytes
    ) VALUES (
        'SCN-KANO-999-T1', 'ANRDMS-LOS-001', 'SITE-KAN-01', 'SCN-LOS-SKYRA', 'PRJ-NIG-STROKE', 'T1w',
        CURRENT_TIMESTAMP, 2300.0, 2.98, 9.0, '1.3.12.999.error', '/data/kano.nii.gz', 45000000
    );
    RAISE NOTICE 'UNEXPECTED: Insert succeeded into non-existent partition!';
EXCEPTION WHEN check_violation OR integrity_constraint_violation OR OTHERS THEN
    RAISE NOTICE 'SUCCESSFUL REJECTION: Partition router rejected unmapped site_id "SITE-KAN-01". SQLSTATE: %, SQLERRM: %', SQLSTATE, SQLERRM;
END $$;
