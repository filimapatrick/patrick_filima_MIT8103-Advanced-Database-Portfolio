-- ============================================================================
-- MIT 8103: Advanced Database Systems
-- Continuous Assessment (CA) - September Cohort 2026
-- Student: Patrick Filima
-- Institution: Miva Open University
-- Portfolio 2: Query Processing and Optimisation
-- File: benchmark_data.sql
-- 
-- System: African Neuroimaging Research Data Management System (ANRDMS)
-- Database Engine: PostgreSQL 16
-- Target Database: anrdms_benchmark
-- Description: Scalable synthetic data generator using set-based generate_series()
--              to populate 5,000 participants and 100,000 MRI scans for realistic
--              query execution plan analysis and index benchmarking.
-- ============================================================================

\timing on

-- ============================================================================
-- 1. POPULATE 5,000 PARTICIPANTS
-- ============================================================================
INSERT INTO participants (
    participant_id,
    primary_site_id,
    enrollment_date,
    birth_year,
    biological_sex,
    handedness,
    education_years,
    consent_obtained
)
SELECT
    'ANRDMS-BM-' || lpad(i::text, 5, '0') AS participant_id,
    (ARRAY['SITE-LOS-01', 'SITE-ABJ-01', 'SITE-IBD-01', 'SITE-ENU-01', 'SITE-ZAR-01'])[1 + (i % 5)] AS primary_site_id,
    '2022-01-01'::date + (i % 1200) AS enrollment_date,
    1945 + (i % 60) AS birth_year,
    (ARRAY['Female', 'Male'])[1 + (i % 2)] AS biological_sex,
    (ARRAY['Right', 'Right', 'Right', 'Left', 'Ambidextrous'])[1 + (i % 5)] AS handedness,
    6 + (i % 16) AS education_years,
    TRUE AS consent_obtained
FROM generate_series(1, 5000) AS i
ON CONFLICT (participant_id) DO NOTHING;

-- ============================================================================
-- 2. POPULATE 5,000 PARTICIPANT DIAGNOSES
-- ============================================================================
INSERT INTO participant_diagnoses (
    participant_id,
    diagnosis_code,
    diagnosing_researcher_id,
    diagnosis_date,
    severity_stage,
    is_primary_diagnosis,
    clinical_notes
)
SELECT
    'ANRDMS-BM-' || lpad(i::text, 5, '0') AS participant_id,
    (ARRAY[
        'DX-CTL-001',
        'DX-STR-001',
        'DX-STR-002',
        'DX-DEM-001',
        'DX-DEM-002',
        'DX-EPI-001',
        'DX-PD-001'
    ])[1 + (i % 7)] AS diagnosis_code,
    (ARRAY['RES-001', 'RES-002', 'RES-003', 'RES-005', 'RES-006'])[1 + (i % 5)] AS diagnosing_researcher_id,
    '2022-01-05'::date + (i % 1200) AS diagnosis_date,
    (ARRAY['Subclinical', 'Mild', 'Moderate', 'Severe', 'Not Applicable'])[1 + (i % 5)] AS severity_stage,
    TRUE AS is_primary_diagnosis,
    'Synthetic longitudinal benchmark clinical entry.' AS clinical_notes
FROM generate_series(1, 5000) AS i
ON CONFLICT (participant_id, diagnosis_code) DO NOTHING;

-- ============================================================================
-- 3. POPULATE 100,000 MRI SCANS
-- ============================================================================
INSERT INTO mri_scans (
    scan_id,
    participant_id,
    scanner_id,
    project_id,
    acquisition_date,
    modality,
    sequence_type,
    repetition_time_ms,
    echo_time_ms,
    flip_angle_deg,
    voxel_size_x_mm,
    voxel_size_y_mm,
    voxel_size_z_mm,
    matrix_x,
    matrix_y,
    slices_count,
    dicom_series_uid,
    bids_relative_path,
    file_size_bytes
)
SELECT
    'SCN-BM-' || lpad(i::text, 7, '0') AS scan_id,
    'ANRDMS-BM-' || lpad((1 + (i % 5000))::text, 5, '0') AS participant_id,
    (ARRAY[
        'SCN-LOS-3T01',
        'SCN-LOS-15T1',
        'SCN-ABJ-3T01',
        'SCN-IBD-3T01',
        'SCN-ENU-15T1',
        'SCN-ZAR-15T1'
    ])[1 + (i % 6)] AS scanner_id,
    (ARRAY[
        'PRJ-ABHI-2025',
        'PRJ-WASCS-2024',
        'PRJ-SSADG-2026',
        'PRJ-NPEPP-2025'
    ])[1 + (i % 4)] AS project_id,
    '2022-01-01 08:00:00+01'::timestamptz + ((i * 18.5) || ' minutes')::interval AS acquisition_date,
    'MRI' AS modality,
    (ARRAY['T1w', 'T1w', 'FLAIR', 'dMRI', 'fMRI-rest', 'T2w'])[1 + (i % 6)] AS sequence_type,
    CASE 
        WHEN (i % 6) IN (0, 1) THEN 2300.00
        WHEN (i % 6) = 2 THEN 9000.00
        WHEN (i % 6) = 3 THEN 3800.00
        WHEN (i % 6) = 4 THEN 2000.00
        ELSE 2500.00
    END AS repetition_time_ms,
    CASE 
        WHEN (i % 6) IN (0, 1) THEN 2.98
        WHEN (i % 6) = 2 THEN 85.00
        WHEN (i % 6) = 3 THEN 75.00
        WHEN (i % 6) = 4 THEN 30.00
        ELSE 80.00
    END AS echo_time_ms,
    9.0 AS flip_angle_deg,
    1.00 AS voxel_size_x_mm,
    1.00 AS voxel_size_y_mm,
    1.00 AS voxel_size_z_mm,
    256 AS matrix_x,
    256 AS matrix_y,
    176 AS slices_count,
    '1.3.12.2.1107.5.2.99.BM.' || i AS dicom_series_uid,
    'sub-ANRDMSBM' || lpad((1 + (i % 5000))::text, 5, '0') || '/ses-' || lpad((1 + ((i / 5000) % 5))::text, 2, '0') || '/anat/sub-BM' || lpad((1 + (i % 5000))::text, 5, '0') || '_scan' || i || '.nii.gz' AS bids_relative_path,
    (15000000 + (i % 80000000))::bigint AS file_size_bytes
FROM generate_series(1, 100000) AS i
ON CONFLICT (scan_id) DO NOTHING;

-- ============================================================================
-- 4. POPULATE 70,000 QUALITY CONTROL (QC) EVALUATIONS
-- ============================================================================
INSERT INTO qc_evaluations (
    scan_id,
    evaluator_id,
    evaluation_date,
    overall_quality,
    snr_score,
    cnr_score,
    head_motion_fd_mean_mm,
    usable_for_analysis,
    artifact_notes
)
SELECT
    'SCN-BM-' || lpad(i::text, 7, '0') AS scan_id,
    (ARRAY['RES-002', 'RES-003', 'RES-005', 'RES-006', 'RES-007'])[1 + (i % 5)] AS evaluator_id,
    '2022-01-02 09:00:00+01'::timestamptz + ((i * 20) || ' minutes')::interval AS evaluation_date,
    (ARRAY['PASS', 'PASS', 'PASS', 'PASS', 'WARN', 'FAIL'])[1 + (i % 6)] AS overall_quality,
    15.00 + ((i % 2500) / 100.0) AS snr_score,
    2.00 + ((i % 300) / 100.0) AS cnr_score,
    0.05 + ((i % 50) / 100.0) AS head_motion_fd_mean_mm,
    CASE WHEN (i % 6) = 5 THEN FALSE ELSE TRUE END AS usable_for_analysis,
    CASE 
        WHEN (i % 6) = 5 THEN 'Severe participant motion artifact detected.'
        WHEN (i % 6) = 4 THEN 'Mild motion artifact noted; acceptable for review.'
        ELSE 'Passed quality assurance threshold.'
    END AS artifact_notes
FROM generate_series(1, 70000) AS i
ON CONFLICT (scan_id, evaluator_id) DO NOTHING;

-- ============================================================================
-- 5. POPULATE 80,000 PROCESSING JOBS
-- ============================================================================
INSERT INTO processing_jobs (
    scan_id,
    pipeline_id,
    submitted_by_id,
    submission_time,
    start_time,
    end_time,
    status,
    exit_code,
    compute_node,
    output_directory
)
SELECT
    'SCN-BM-' || lpad(i::text, 7, '0') AS scan_id,
    (ARRAY['PIP-FS-741', 'PIP-QSIPREP-020', 'PIP-FLAIR-WML', 'PIP-FMRIPREP-23'])[1 + (i % 4)] AS pipeline_id,
    (ARRAY['RES-003', 'RES-004', 'RES-007'])[1 + (i % 3)] AS submitted_by_id,
    '2022-01-02 10:00:00+01'::timestamptz + ((i * 19) || ' minutes')::interval AS submission_time,
    '2022-01-02 10:05:00+01'::timestamptz + ((i * 19) || ' minutes')::interval AS start_time,
    '2022-01-02 14:00:00+01'::timestamptz + ((i * 19) || ' minutes')::interval AS end_time,
    (ARRAY['COMPLETED', 'COMPLETED', 'COMPLETED', 'COMPLETED', 'COMPLETED', 'FAILED', 'RUNNING', 'PENDING'])[1 + (i % 8)] AS status,
    CASE WHEN (i % 8) = 5 THEN 1 ELSE 0 END AS exit_code,
    'hpc-worker-node-' || lpad((1 + (i % 32))::text, 2, '0') AS compute_node,
    '/data/derivatives/sub-BM' || lpad((1 + (i % 5000))::text, 5, '0') AS output_directory
FROM generate_series(1, 80000) AS i;

-- Refresh PostgreSQL table planner statistics
ANALYZE participants;
ANALYZE participant_diagnoses;
ANALYZE mri_scans;
ANALYZE qc_evaluations;
ANALYZE processing_jobs;

\timing off
