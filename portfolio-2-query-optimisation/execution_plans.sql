-- ============================================================================
-- MIT 8103: Advanced Database Systems
-- Continuous Assessment (CA) - September Cohort 2026
-- Student: Patrick Filima
-- Institution: Miva Open University
-- Portfolio 2: Query Processing and Optimisation
-- File: execution_plans.sql
-- 
-- System: African Neuroimaging Research Data Management System (ANRDMS)
-- Database Engine: PostgreSQL 16
-- Target Database: anrdms_benchmark (100,000+ rows)
-- Description: Empirical EXPLAIN (ANALYZE, BUFFERS) benchmarking comparing
--              execution plans before and after targeted index creation.
-- ============================================================================

\timing on

-- ============================================================================
-- PART 1: BASELINE BENCHMARKS (WITHOUT TARGET INDEXES)
-- ============================================================================

-- Ensure secondary indexes are removed for unindexed baseline
DROP INDEX IF EXISTS idx_scans_seq_date;
DROP INDEX IF EXISTS idx_qc_pass_usable_partial;
DROP INDEX IF EXISTS idx_jobs_completed_scan_partial;
DROP INDEX IF EXISTS idx_qc_scan;
DROP INDEX IF EXISTS idx_jobs_scan;
ANALYZE mri_scans;
ANALYZE qc_evaluations;
ANALYZE processing_jobs;

\echo '======================================================================'
\echo 'BASELINE EXPERIMENT 1: Temporal Sequence Filtering (Without Index)'
\echo 'Expected Plan: Full Table Scan (Seq Scan) + In-Memory Sort'
\echo '======================================================================'

EXPLAIN (ANALYZE, BUFFERS)
SELECT scan_id, participant_id, sequence_type, acquisition_date, file_size_bytes
FROM mri_scans
WHERE sequence_type = 'fMRI-rest'
  AND acquisition_date >= '2025-01-01 00:00:00+01'
  AND acquisition_date <  '2025-07-01 00:00:00+01'
ORDER BY acquisition_date DESC;


\echo '======================================================================'
\echo 'BASELINE EXPERIMENT 2: Quality-Certified Cohort Retrieval (Without Index)'
\echo 'Expected Plan: Hash Join with Sequential Scans over 100k + 70k rows'
\echo '======================================================================'

EXPLAIN (ANALYZE, BUFFERS)
SELECT ms.scan_id, ms.participant_id, ms.sequence_type, ms.acquisition_date
FROM mri_scans ms
WHERE ms.sequence_type = 'T1w'
AND EXISTS (
    SELECT 1
    FROM qc_evaluations qc
    WHERE qc.scan_id = ms.scan_id
      AND qc.overall_quality = 'PASS'
      AND qc.usable_for_analysis = TRUE
);


\echo '======================================================================'
\echo 'BASELINE EXPERIMENT 3: Pipeline Backlog Anti-Join (Without Index)'
\echo 'Expected Plan: Hash Anti Join with Full Sequential Scans'
\echo '======================================================================'

EXPLAIN (ANALYZE, BUFFERS)
SELECT ms.scan_id, ms.participant_id, ms.sequence_type, ms.acquisition_date
FROM mri_scans ms
WHERE NOT EXISTS (
    SELECT 1
    FROM processing_jobs pj
    WHERE pj.scan_id = ms.scan_id
      AND pj.status = 'COMPLETED'
);


-- ============================================================================
-- PART 2: CREATE TARGETED OPTIMIZATION INDEXES
-- ============================================================================

\echo '======================================================================'
\echo 'CREATING TARGETED OPTIMIZATION INDEXES'
\echo '======================================================================'

-- 1. Composite B-Tree index on sequence_type and acquisition_date
CREATE INDEX idx_scans_seq_date 
ON mri_scans(sequence_type, acquisition_date DESC);

-- 2. Partial index on passed, usable QC evaluations
CREATE INDEX idx_qc_pass_usable_partial 
ON qc_evaluations(scan_id) 
WHERE overall_quality = 'PASS' AND usable_for_analysis = TRUE;

-- 3. Partial index on completed batch processing jobs
CREATE INDEX idx_jobs_completed_scan_partial 
ON processing_jobs(scan_id) 
WHERE status = 'COMPLETED';

ANALYZE mri_scans;
ANALYZE qc_evaluations;
ANALYZE processing_jobs;


-- ============================================================================
-- PART 3: OPTIMIZED BENCHMARKS (WITH TARGET INDEXES)
-- ============================================================================

\echo '======================================================================'
\echo 'OPTIMIZED EXPERIMENT 1: Temporal Sequence Filtering (With Composite Index)'
\echo 'Expected Plan: Index Scan / Bitmap Index Scan, Sort Eliminated'
\echo '======================================================================'

EXPLAIN (ANALYZE, BUFFERS)
SELECT scan_id, participant_id, sequence_type, acquisition_date, file_size_bytes
FROM mri_scans
WHERE sequence_type = 'fMRI-rest'
  AND acquisition_date >= '2025-01-01 00:00:00+01'
  AND acquisition_date <  '2025-07-01 00:00:00+01'
ORDER BY acquisition_date DESC;


\echo '======================================================================'
\echo 'OPTIMIZED EXPERIMENT 2: Quality-Certified Cohort Retrieval (With Partial Index)'
\echo 'Expected Plan: Index Semi Join / Nested Loop using Partial Index'
\echo '======================================================================'

EXPLAIN (ANALYZE, BUFFERS)
SELECT ms.scan_id, ms.participant_id, ms.sequence_type, ms.acquisition_date
FROM mri_scans ms
WHERE ms.sequence_type = 'T1w'
AND EXISTS (
    SELECT 1
    FROM qc_evaluations qc
    WHERE qc.scan_id = ms.scan_id
      AND qc.overall_quality = 'PASS'
      AND qc.usable_for_analysis = TRUE
);


\echo '======================================================================'
\echo 'OPTIMIZED EXPERIMENT 3: Pipeline Backlog Anti-Join (With Partial Index)'
\echo 'Expected Plan: Accelerated Anti-Join via Partial Index Scan'
\echo '======================================================================'

EXPLAIN (ANALYZE, BUFFERS)
SELECT ms.scan_id, ms.participant_id, ms.sequence_type, ms.acquisition_date
FROM mri_scans ms
WHERE NOT EXISTS (
    SELECT 1
    FROM processing_jobs pj
    WHERE pj.scan_id = ms.scan_id
      AND pj.status = 'COMPLETED'
);

\timing off
