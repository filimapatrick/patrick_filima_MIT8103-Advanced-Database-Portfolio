-- ============================================================================
-- MIT 8103: Advanced Database Systems
-- Continuous Assessment (CA) - September Cohort 2026
-- Student: Patrick Filima
-- Institution: Miva Open University
-- Portfolio 2: Query Processing and Optimisation
-- File: queries.sql
-- 
-- System: African Neuroimaging Research Data Management System (ANRDMS)
-- Database Engine: PostgreSQL 16
-- Description: Seven research-oriented analytical SQL queries addressing
--              multi-site clinical, hardware, workflow, and QC questions.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- QUERY 1: Multi-Site Scanner Utilization & Total Acquisitions
-- Research Question: How many MRI scans have been acquired at each research site?
-- SQL Techniques: Multi-table LEFT JOIN, GROUP BY, Aggregation (COUNT), ORDER BY
-- Clinical Purpose: Monitors multi-site recruitment throughput across Nigerian
--                   hospitals, ensuring sites without scans are retained in output.
-- ----------------------------------------------------------------------------
SELECT
    rs.site_id,
    rs.hospital_name,
    COUNT(ms.scan_id) AS total_scans
FROM research_sites rs
LEFT JOIN mri_scanners sc
    ON rs.site_id = sc.site_id
LEFT JOIN mri_scans ms
    ON sc.scanner_id = ms.scanner_id
GROUP BY rs.site_id, rs.hospital_name
ORDER BY total_scans DESC;


-- ----------------------------------------------------------------------------
-- QUERY 2: Participant Cohort Distribution by Neurological Diagnosis
-- Research Question: How are research participants distributed across diagnoses?
-- SQL Techniques: Multi-table JOIN, COUNT(DISTINCT), GROUP BY, ORDER BY
-- Clinical Purpose: Audits pathology representation (e.g. Stroke, Alzheimer's)
--                   preventing duplicate counting of multi-session participants.
-- ----------------------------------------------------------------------------
SELECT
    nd.condition_name,
    nd.category,
    COUNT(DISTINCT pd.participant_id) AS total_participants
FROM neurological_diagnoses nd
LEFT JOIN participant_diagnoses pd
    ON nd.diagnosis_code = pd.diagnosis_code
GROUP BY nd.diagnosis_code,
         nd.condition_name,
         nd.category
ORDER BY total_participants DESC;


-- ----------------------------------------------------------------------------
-- QUERY 3: Quality-Certified Structural MRI Cohort Retrieval
-- Research Question: Which T1-weighted MRI scans have passed quality control?
-- SQL Techniques: Multi-table INNER JOIN, Correlated Subquery with EXISTS, Filtering
-- Clinical Purpose: Extracts high-fidelity structural scans verified by radiologists
--                   (overall_quality = 'PASS') for downstream FreeSurfer morphometry.
-- ----------------------------------------------------------------------------
SELECT
    ms.scan_id,
    ms.participant_id,
    ms.sequence_type,
    rs.hospital_name,
    ms.acquisition_date
FROM mri_scans ms
JOIN mri_scanners sc
    ON ms.scanner_id = sc.scanner_id
JOIN research_sites rs
    ON sc.site_id = rs.site_id
WHERE ms.sequence_type = 'T1w'
AND EXISTS (
    SELECT 1
    FROM qc_evaluations qc
    WHERE qc.scan_id = ms.scan_id
      AND qc.overall_quality = 'PASS'
      AND qc.usable_for_analysis = TRUE
)
ORDER BY ms.acquisition_date DESC;


-- ----------------------------------------------------------------------------
-- QUERY 4: Computational Pipeline Failure Rate & Reliability Audit
-- Research Question: Which processing pipelines have the highest failure rates?
-- SQL Techniques: LEFT JOIN, Modern Conditional Aggregation (FILTER), NULLIF, ROUND
-- Clinical Purpose: Identifies algorithmic instability and HPC resource exhaustion
--                   across FreeSurfer, FSL, and QSIPrep neuroimaging containers.
-- ----------------------------------------------------------------------------
SELECT
    pp.pipeline_id,
    pp.name,
    pp.version,
    COUNT(pj.job_id) AS total_jobs,
    COUNT(pj.job_id) FILTER (
        WHERE pj.status = 'FAILED'
    ) AS failed_jobs,
    COUNT(pj.job_id) FILTER (
        WHERE pj.status IN ('COMPLETED', 'FAILED')
    ) AS completed_or_failed_jobs,
    ROUND(
        100.0 * COUNT(pj.job_id) FILTER (
            WHERE pj.status = 'FAILED'
        )
        / NULLIF(
            COUNT(pj.job_id) FILTER (
                WHERE pj.status IN ('COMPLETED', 'FAILED')
            ), 0
        ), 2
    ) AS failure_rate_percent
FROM processing_pipelines pp
LEFT JOIN processing_jobs pj
    ON pp.pipeline_id = pj.pipeline_id
GROUP BY pp.pipeline_id, pp.name, pp.version
ORDER BY failure_rate_percent DESC NULLS LAST;


-- ----------------------------------------------------------------------------
-- QUERY 5: Multi-Modal Acquisition Diversity
-- Research Question: Which participants have undergone multiple distinct MRI sequences?
-- SQL Techniques: INNER JOIN, GROUP BY, Aggregate Filtering (HAVING), STRING_AGG
-- Clinical Purpose: Discovers multi-modal participants possessing both structural
--                   (T1w/FLAIR) and functional/diffusion (dMRI, fMRI) acquisitions.
-- ----------------------------------------------------------------------------
SELECT
    p.participant_id,
    COUNT(DISTINCT ms.sequence_type) AS sequence_count,
    STRING_AGG(
        DISTINCT ms.sequence_type,
        ', ' ORDER BY ms.sequence_type
    ) AS available_sequences
FROM participants p
JOIN mri_scans ms
    ON p.participant_id = ms.participant_id
GROUP BY p.participant_id
HAVING COUNT(DISTINCT ms.sequence_type) > 1
ORDER BY sequence_count DESC;


-- ----------------------------------------------------------------------------
-- QUERY 6: Computational Backlog Identification (Unprocessed Scans)
-- Research Question: Which MRI scans lack a successfully completed processing job?
-- SQL Techniques: Correlated Subquery with NOT EXISTS, Temporal Sorting
-- Clinical Purpose: Drives automated queue dispatchers by identifying acquired
--                   imaging datasets awaiting initial batch feature extraction.
-- ----------------------------------------------------------------------------
SELECT
    ms.scan_id,
    ms.participant_id,
    ms.sequence_type,
    ms.acquisition_date
FROM mri_scans ms
WHERE NOT EXISTS (
    SELECT 1
    FROM processing_jobs pj
    WHERE pj.scan_id = ms.scan_id
      AND pj.status = 'COMPLETED'
)
ORDER BY ms.acquisition_date DESC;


-- ----------------------------------------------------------------------------
-- QUERY 7: Longitudinal Session Stratification (Most Recent Scan per Subject)
-- Research Question: What is the most recent MRI scan acquisition for each participant?
-- SQL Techniques: Common Table Expression (CTE), Window Function (ROW_NUMBER() OVER PARTITION BY)
-- Clinical Purpose: Selects the latest imaging baseline for disease progression
--                   tracking without requiring expensive nested self-joins.
-- ----------------------------------------------------------------------------
WITH ranked_scans AS (
    SELECT
        scan_id,
        participant_id,
        sequence_type,
        acquisition_date,
        ROW_NUMBER() OVER (
            PARTITION BY participant_id
            ORDER BY acquisition_date DESC,
                     scan_id DESC
        ) AS scan_rank
    FROM mri_scans
)
SELECT
    participant_id,
    scan_id,
    sequence_type,
    acquisition_date
FROM ranked_scans
WHERE scan_rank = 1
ORDER BY participant_id;
