-- ============================================================================
-- MIT 8103: Advanced Database Systems
-- Continuous Assessment (CA) - September Cohort 2026
-- Student: Patrick Filima
-- Institution: Miva Open University
-- Portfolio 4: NoSQL and Advanced Data Models
-- File: hybrid_jsonb.sql
-- 
-- System: African Neuroimaging Research Data Management System (ANRDMS)
-- Target DBMS: PostgreSQL 14+
-- Description: Polyglot persistence bridge implementing semi-structured BIDS
--              documents and hierarchical FreeSurfer metrics using PostgreSQL JSONB
--              and Generalized Inverted Indexes (GIN).
-- ============================================================================

\set ECHO all
\timing on

-- ============================================================================
-- 1. HYBRID SCHEMA DEFINITION (RELATIONAL ANCHOR + JSONB PAYLOAD)
-- ============================================================================

DROP TABLE IF EXISTS scans_bids_jsonb CASCADE;
DROP TABLE IF EXISTS pipeline_metrics_jsonb CASCADE;

-- Scans table combining relational primary keys with a flexible BIDS document payload
-- Foreign keys link directly to core relational backbone (participants & research_sites)
CREATE TABLE scans_bids_jsonb (
    scan_id VARCHAR(30) PRIMARY KEY,
    participant_id VARCHAR(25) NOT NULL REFERENCES participants(participant_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    site_id VARCHAR(15) NOT NULL REFERENCES research_sites(site_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    sequence_type VARCHAR(25) NOT NULL,
    acquisition_date TIMESTAMPTZ NOT NULL,
    metadata JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Pipeline outputs table storing polymorphic hierarchical computational statistics
CREATE TABLE pipeline_metrics_jsonb (
    metric_id VARCHAR(30) PRIMARY KEY,
    scan_id VARCHAR(30) NOT NULL REFERENCES scans_bids_jsonb(scan_id) ON DELETE CASCADE,
    pipeline_name VARCHAR(50) NOT NULL,
    runtime_seconds INT NOT NULL,
    results JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- ============================================================================
-- 2. GIN INDEXING STRATEGY FOR HIGH-PERFORMANCE DOCUMENT RETRIEVAL
-- ============================================================================

-- Fast path containment indexing using jsonb_path_ops (optimal for @> containment queries)
CREATE INDEX idx_scans_bids_metadata_gin ON scans_bids_jsonb USING gin (metadata jsonb_path_ops);

-- General GIN index on results supporting arbitrary key and path existence operators (?, ?&, @>)
CREATE INDEX idx_pipeline_results_gin ON pipeline_metrics_jsonb USING gin (results);

-- B-Tree expression index for nested scanner field strength
CREATE INDEX idx_scans_bids_field_strength ON scans_bids_jsonb (((metadata->'scanner_hardware'->>'magnetic_field_tesla')::numeric));


-- ============================================================================
-- 3. SEEDING HYBRID DOCUMENT DATASET
-- ============================================================================

INSERT INTO scans_bids_jsonb (scan_id, participant_id, site_id, sequence_type, acquisition_date, metadata)
VALUES
(
    'SCN-LOS-001-T1',
    'ANRDMS-LOS-001',
    'SITE-LOS-01',
    'T1w',
    '2025-01-15 08:30:00+00',
    '{
        "scanner_hardware": {
            "vendor": "Siemens Healthineers",
            "model": "Magnetom Skyra",
            "magnetic_field_tesla": 3.0,
            "receive_coil": "32-Channel Head Matrix"
        },
        "acquisition_parameters": {
            "repetition_time_ms": 2300.0,
            "echo_time_ms": 2.98,
            "inversion_time_ms": 900.0,
            "flip_angle_deg": 9.0,
            "voxel_size_mm": {"x": 1.0, "y": 1.0, "z": 1.0}
        },
        "clinical_cohort": {
            "diagnosis_category": "Cerebrovascular",
            "condition_name": "Acute ischemic stroke",
            "severity": "Moderate"
        }
    }'::jsonb
),
(
    'SCN-LOS-001-DM',
    'ANRDMS-LOS-001',
    'SITE-LOS-01',
    'dMRI',
    '2025-01-15 09:15:00+00',
    '{
        "scanner_hardware": {
            "vendor": "Siemens Healthineers",
            "model": "Magnetom Skyra",
            "magnetic_field_tesla": 3.0,
            "receive_coil": "32-Channel Head Matrix"
        },
        "diffusion_protocol": {
            "b_values": [0, 1000, 2000],
            "gradient_directions_count": 64,
            "multiband_acceleration_factor": 2
        },
        "clinical_cohort": {
            "diagnosis_category": "Cerebrovascular",
            "condition_name": "Acute ischemic stroke"
        }
    }'::jsonb
),
(
    'SCN-ABJ-001-T1',
    'ANRDMS-ABJ-001',
    'SITE-ABJ-01',
    'T1w',
    '2025-02-10 10:00:00+00',
    '{
        "scanner_hardware": {
            "vendor": "GE Healthcare",
            "model": "Signa Premier",
            "magnetic_field_tesla": 3.0,
            "receive_coil": "48-Channel Head Coil"
        },
        "acquisition_parameters": {
            "repetition_time_ms": 2400.0,
            "echo_time_ms": 3.12,
            "inversion_time_ms": 920.0,
            "flip_angle_deg": 8.0,
            "voxel_size_mm": {"x": 0.9, "y": 0.9, "z": 1.0}
        },
        "clinical_cohort": {
            "diagnosis_category": "Neurodegenerative",
            "condition_name": "Early-onset Alzheimer''s dementia",
            "severity": "Mild"
        }
    }'::jsonb
),
(
    'SCN-ENU-001-T1',
    'ANRDMS-ENU-001',
    'SITE-ENU-01',
    'T1w',
    '2025-04-12 14:10:00+00',
    '{
        "scanner_hardware": {
            "vendor": "GE Healthcare",
            "model": "Optima MR450w",
            "magnetic_field_tesla": 1.5,
            "receive_coil": "16-Channel Head Array"
        },
        "clinical_cohort": {
            "diagnosis_category": "Healthy Control",
            "condition_name": "Healthy Control Benchmark"
        }
    }'::jsonb
);

INSERT INTO pipeline_metrics_jsonb (metric_id, scan_id, pipeline_name, runtime_seconds, results)
VALUES
(
    'MET-FS-LOS-001',
    'SCN-LOS-001-T1',
    'FreeSurfer',
    26840,
    '{
        "subcortical_structures": {
            "left_hippocampus_mm3": 4150.2,
            "right_hippocampus_mm3": 4210.8,
            "ventricles_total_mm3": 32890.6
        },
        "cortical_parcellations": [
            {"region": "superiorfrontal", "hemisphere": "lh", "thickness_mm": 2.76},
            {"region": "superiorfrontal", "hemisphere": "rh", "thickness_mm": 2.78},
            {"region": "entorhinal", "hemisphere": "lh", "thickness_mm": 3.42},
            {"region": "entorhinal", "hemisphere": "rh", "thickness_mm": 3.45}
        ],
        "quality_metrics": {
            "euler_number_lh": -2,
            "euler_number_rh": -4
        }
    }'::jsonb
),
(
    'MET-FS-ABJ-001',
    'SCN-ABJ-001-T1',
    'FreeSurfer',
    29410,
    '{
        "subcortical_structures": {
            "left_hippocampus_mm3": 3120.4,
            "right_hippocampus_mm3": 3210.1,
            "ventricles_total_mm3": 58400.0
        },
        "cortical_parcellations": [
            {"region": "superiorfrontal", "hemisphere": "lh", "thickness_mm": 2.38},
            {"region": "superiorfrontal", "hemisphere": "rh", "thickness_mm": 2.40},
            {"region": "entorhinal", "hemisphere": "lh", "thickness_mm": 2.65},
            {"region": "entorhinal", "hemisphere": "rh", "thickness_mm": 2.68}
        ],
        "quality_metrics": {
            "euler_number_lh": -8,
            "euler_number_rh": -10
        }
    }'::jsonb
);


-- ============================================================================
-- 4. HYBRID JSONB ADVANCED QUERIES & EXECUTION PLANS
-- ============================================================================

-- Query 1: JSON Containment Operator (@>) Accelerated by GIN Index
-- Find all scans acquired on a Siemens 3.0T scanner
-- 
-- Query Planning Analysis:
-- With small tables (4 demonstration records residing in 1 disk/buffer page), PostgreSQL's
-- cost-based optimizer rationally chooses a Sequential Scan (estimated cost 1.05) rather than
-- a Bitmap Index Scan via idx_scans_bids_metadata_gin (estimated cost 12.05).
-- Initializing the GIN index structure, scanning index posting lists, and constructing a bitmap
-- incurs higher startup overhead than scanning four contiguous tuples on a single cached page.
-- Below, we show both the default cost-based plan and the plan when sequential scans are disabled
-- (simulating behavior on a scaled production corpus where index selectivity dominates).

\echo '=== Query 1: Default Optimizer Plan (Sequential Scan on 4-row demonstration seed) ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    scan_id,
    participant_id,
    site_id,
    metadata->'scanner_hardware'->>'model' AS scanner_model,
    (metadata->'scanner_hardware'->>'magnetic_field_tesla')::numeric AS field_tesla
FROM scans_bids_jsonb
WHERE metadata @> '{"scanner_hardware": {"vendor": "Siemens Healthineers", "magnetic_field_tesla": 3.0}}';

\echo '=== Query 1: Forced Index Plan (Bitmap Index Scan via GIN jsonb_path_ops) ==='
SET enable_seqscan = off;
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    scan_id,
    participant_id,
    site_id,
    metadata->'scanner_hardware'->>'model' AS scanner_model,
    (metadata->'scanner_hardware'->>'magnetic_field_tesla')::numeric AS field_tesla
FROM scans_bids_jsonb
WHERE metadata @> '{"scanner_hardware": {"vendor": "Siemens Healthineers", "magnetic_field_tesla": 3.0}}';
SET enable_seqscan = on;

-- Query 2: Subcortical Volumetric Aggregation across Polymorphic Records
-- Extract left and right hippocampal volumes and compute total bilateral volume
SELECT 
    s.scan_id,
    s.participant_id,
    s.metadata->'clinical_cohort'->>'condition_name' AS clinical_condition,
    (m.results->'subcortical_structures'->>'left_hippocampus_mm3')::numeric AS left_hippo,
    (m.results->'subcortical_structures'->>'right_hippocampus_mm3')::numeric AS right_hippo,
    ROUND(
        (m.results->'subcortical_structures'->>'left_hippocampus_mm3')::numeric +
        (m.results->'subcortical_structures'->>'right_hippocampus_mm3')::numeric, 1
    ) AS total_bilateral_hippo_mm3,
    (m.results->'subcortical_structures'->>'ventricles_total_mm3')::numeric AS ventricle_vol_mm3
FROM scans_bids_jsonb s
JOIN pipeline_metrics_jsonb m ON s.scan_id = m.scan_id
ORDER BY total_bilateral_hippo_mm3 ASC;

-- Query 3: JSON Array Unnesting (Equivalent to MongoDB $unwind)
-- Unnest the cortical_parcellations JSON array and compute regional metrics
SELECT 
    s.metadata->'clinical_cohort'->>'condition_name' AS clinical_condition,
    region_elem->>'region' AS anatomical_region,
    region_elem->>'hemisphere' AS hemisphere,
    (region_elem->>'thickness_mm')::numeric AS cortical_thickness_mm
FROM scans_bids_jsonb s
JOIN pipeline_metrics_jsonb m ON s.scan_id = m.scan_id,
LATERAL jsonb_array_elements(m.results->'cortical_parcellations') AS region_elem
WHERE region_elem->>'region' = 'entorhinal'
ORDER BY region_elem->>'region', cortical_thickness_mm ASC;
