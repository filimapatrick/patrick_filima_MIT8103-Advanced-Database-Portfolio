-- ============================================================================
-- MIT 8103: Advanced Database Systems
-- Continuous Assessment (CA) - September Cohort 2026
-- Student: Patrick Filima
-- Institution: Miva Open University
-- Portfolio 2: Query Processing and Optimisation
-- File: indexes.sql
-- 
-- System: African Neuroimaging Research Data Management System (ANRDMS)
-- Database Engine: PostgreSQL 16
-- Target Database: anrdms_benchmark
-- Description: Controlled index management scripts for empirical A/B query
--              optimization testing (Baseline vs Optimized).
-- ============================================================================

-- ============================================================================
-- 1. DROP SECONDARY INDEXES FOR BASELINE MEASUREMENTS (A/B TESTING)
-- ============================================================================
-- Dropping specific secondary indexes forces the PostgreSQL query planner
-- to evaluate cost-based Sequential Scans (Seq Scan) across 100,000+ rows.

DROP INDEX IF EXISTS idx_scans_seq_date;
DROP INDEX IF EXISTS idx_qc_quality_usable;
DROP INDEX IF EXISTS idx_jobs_status;
DROP INDEX IF EXISTS idx_qc_scan;
DROP INDEX IF EXISTS idx_jobs_scan;

-- Re-analyze to ensure catalog statistics reflect index absence
ANALYZE mri_scans;
ANALYZE qc_evaluations;
ANALYZE processing_jobs;


-- ============================================================================
-- 2. CREATE TARGETED OPTIMIZATION INDEXES
-- ============================================================================

-- Optimization for Experiment 1: Composite B-Tree Index on Sequence & Date
-- Reduces full-table scanning for temporal sequence queries.
-- PostgreSQL may select a Bitmap Heap Scan followed by a Sort
-- depending on query selectivity and estimated execution cost.
CREATE INDEX idx_scans_seq_date 
ON mri_scans(sequence_type, acquisition_date DESC);

-- Optimization for Experiment 2: Partial Filtered Index on Passing QC Scans
-- Indexes only usable passed scans, reducing physical index footprint (1,448 kB vs 2,184 kB full index)
CREATE INDEX idx_qc_pass_usable_partial 
ON qc_evaluations(scan_id) 
WHERE overall_quality = 'PASS' AND usable_for_analysis = TRUE;

-- Optimization for Experiment 3: Partial Index on Completed Processing Jobs
-- Accelerates NOT EXISTS subqueries and anti-joins (1,552 kB vs 2,488 kB full index)
CREATE INDEX idx_jobs_completed_scan_partial 
ON processing_jobs(scan_id) 
WHERE status = 'COMPLETED';

-- Re-analyze to update catalog index distributions
ANALYZE mri_scans;
ANALYZE qc_evaluations;
ANALYZE processing_jobs;
