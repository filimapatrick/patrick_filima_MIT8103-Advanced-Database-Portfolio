-- ============================================================================
-- MIT 8103: Advanced Database Systems
-- Continuous Assessment (CA) - September Cohort 2026
-- Student: Patrick Filima
-- Institution: Miva Open University
-- Portfolio 3: Transactions and Concurrency
-- File: concurrency_tests.sql
-- 
-- System: African Neuroimaging Research Data Management System (ANRDMS)
-- Target DBMS: PostgreSQL 14+
-- Description: Interactive dual-session concurrency experiments demonstrating:
--              1. Lost Update Prevention using SELECT FOR UPDATE and SKIP LOCKED
--              2. ANSI Isolation Levels & Anomalies (READ COMMITTED vs REPEATABLE READ vs SERIALIZABLE)
--              3. Deadlock Detection, Wait-For Graph Cycle, and Resolution
-- ============================================================================

-- Note for manual reproduction in psql:
-- Open two terminal windows connected to the ANRDMS database:
--   Terminal 1: psql -d anrdms  (Session 1)
--   Terminal 2: psql -d anrdms  (Session 2)
-- Execute statements in the interleaved chronological order numbered below.


-- ============================================================================
-- EXPERIMENT 1: LOST UPDATE ANOMALY & PESSIMISTIC LOCKING (FOR UPDATE)
-- ============================================================================
-- Scenario:
--   Two HPC cluster worker daemons (Worker 1 in Lagos and Worker 2 in Abuja)
--   poll the processing_jobs table concurrently to claim pending jobs.
--   Without row locking, both workers read the same job as PENDING and both
--   dispatch it, resulting in duplicate compute and lost status updates.
--
-- Solution:
--   PostgreSQL's SELECT ... FOR UPDATE acquires an Exclusive tuple lock,
--   forcing concurrent sessions to wait until the first transaction commits.
--   Additionally, SELECT ... FOR UPDATE SKIP LOCKED provides a non-blocking
--   queue pattern where Worker 2 automatically claims the next available job.
-- ============================================================================

-- Setup test jobs for the queue experiment
DELETE FROM processing_jobs WHERE job_id IN (101, 102);
INSERT INTO processing_jobs (job_id, scan_id, pipeline_id, submitted_by_id, submission_time, status)
VALUES 
    (101, 'SCN-LOS-006-T1', 'PIP-FS-741', 'RES-002', CURRENT_TIMESTAMP - INTERVAL '30 minutes', 'PENDING'),
    (102, 'SCN-LOS-006-T1', 'PIP-FSL-607', 'RES-002', CURRENT_TIMESTAMP - INTERVAL '30 minutes', 'PENDING');

-- --- Phase 1A: Pessimistic Row Lock (FOR UPDATE - Serialised Blocking) ---
-- [Session 1 - Step 1.1] Begin transaction and lock Job 101
BEGIN;
SELECT job_id, scan_id, pipeline_id, status 
FROM processing_jobs 
WHERE job_id = 101 AND status = 'PENDING'
FOR UPDATE;

-- [Session 2 - Step 1.2] Concurrently attempt to claim Job 101
BEGIN;
SELECT job_id, scan_id, pipeline_id, status 
FROM processing_jobs 
WHERE job_id = 101 AND status = 'PENDING'
FOR UPDATE;
-- --> RESULT IN SESSION 2: BLOCKED! Session 2 hangs waiting for Session 1 to release tuple lock.

-- [Session 1 - Step 1.3] Worker 1 assigns job to its compute node and commits
UPDATE processing_jobs 
SET status = 'RUNNING',
    compute_node = 'hpc-node-01.luth.edu.ng',
    start_time = CURRENT_TIMESTAMP
WHERE job_id = 101;
COMMIT;

-- --> RESULT IN SESSION 2: IMMEDIATELY UNBLOCKS! 
-- Session 2 now re-evaluates the locked row and discovers status is no longer 'PENDING'.
-- Session 2 aborts or rolls back cleanly without overwriting Worker 1.
ROLLBACK;


-- --- Phase 1B: Non-Blocking High-Throughput Queue (FOR UPDATE SKIP LOCKED) ---
-- Reset Job 101 and 102 to PENDING
UPDATE processing_jobs 
SET status = 'PENDING', compute_node = NULL, start_time = NULL 
WHERE job_id IN (101, 102);

-- [Session 1 - Step 1.4] Worker 1 claims first available pending job
BEGIN;
SELECT job_id, pipeline_id, status 
FROM processing_jobs 
WHERE job_id IN (101, 102) AND status = 'PENDING' 
ORDER BY job_id 
LIMIT 1 
FOR UPDATE SKIP LOCKED;
-- Returns Job 101

-- [Session 2 - Step 1.5] Worker 2 concurrently requests an available job
BEGIN;
SELECT job_id, pipeline_id, status 
FROM processing_jobs 
WHERE job_id IN (101, 102) AND status = 'PENDING' 
ORDER BY job_id 
LIMIT 1 
FOR UPDATE SKIP LOCKED;
-- --> RESULT IN SESSION 2: ZERO WAITING! Session 2 skips locked Job 101 and immediately claims Job 102!

-- [Both Sessions Commit]
UPDATE processing_jobs 
SET status = 'RUNNING', compute_node = 'hpc-node-01.luth.edu.ng', start_time = CURRENT_TIMESTAMP 
WHERE job_id = 101;
COMMIT; -- Session 1

UPDATE processing_jobs 
SET status = 'RUNNING', compute_node = 'hpc-node-02.nha.gov.ng', start_time = CURRENT_TIMESTAMP 
WHERE job_id = 102;
COMMIT; -- Session 2


-- ============================================================================
-- EXPERIMENT 2: TRANSACTION ISOLATION LEVELS & ANOMALY RESOLUTION
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Test 2A: Non-Repeatable Read (Fuzzy Read) under READ COMMITTED (Default)
-- ----------------------------------------------------------------------------
-- Scenario:
--   A clinical data manager runs an audit on running test jobs.
--   Under READ COMMITTED, each query in a transaction takes a fresh MVCC snapshot.
--   When Session 2 commits a status modification between queries, the same query
--   returns differing results within the same transaction block.
-- ----------------------------------------------------------------------------

-- [Session 1 - Step 2A.1] Begin transaction in default READ COMMITTED mode
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
-- Read individual row status and aggregate count
SELECT job_id, status FROM processing_jobs WHERE job_id = 101;
SELECT count(*) AS running_test_jobs 
FROM processing_jobs 
WHERE job_id IN (101, 102) AND status = 'RUNNING';
-- Returns status = 'RUNNING', count = 2

-- [Session 2 - Step 2A.2] Concurrent session completes Job 101 and commits
BEGIN;
UPDATE processing_jobs 
SET status = 'COMPLETED', end_time = CURRENT_TIMESTAMP, exit_code = 0 
WHERE job_id = 101;
COMMIT;

-- [Session 1 - Step 2A.3] Re-execute identical queries within the same transaction
SELECT job_id, status FROM processing_jobs WHERE job_id = 101;
SELECT count(*) AS running_test_jobs 
FROM processing_jobs 
WHERE job_id IN (101, 102) AND status = 'RUNNING';
-- --> RESULT IN SESSION 1: Non-repeatable read observed!
--     Row-level status changed from 'RUNNING' to 'COMPLETED' and count decreased from 2 to 1
--     within the same transaction because READ COMMITTED obtains a new snapshot per statement.
COMMIT;


-- ----------------------------------------------------------------------------
-- Test 2B: Prevention of Non-Repeatable Read under REPEATABLE READ
-- ----------------------------------------------------------------------------
-- Scenario:
--   The data manager repeats the audit under REPEATABLE READ.
--   PostgreSQL freezes the transaction snapshot at the first relational query.
--   Subsequent concurrent commits remain invisible to Session 1.
-- ----------------------------------------------------------------------------

-- [Session 1 - Step 2B.1] Begin transaction in REPEATABLE READ mode
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT job_id, status FROM processing_jobs WHERE job_id = 102;
SELECT count(*) AS running_test_jobs 
FROM processing_jobs 
WHERE job_id IN (101, 102) AND status = 'RUNNING';
-- Returns status = 'RUNNING', count = 1 (Job 102)

-- [Session 2 - Step 2B.2] Concurrent session completes the second job (102) and commits
BEGIN;
UPDATE processing_jobs 
SET status = 'COMPLETED', end_time = CURRENT_TIMESTAMP, exit_code = 0 
WHERE job_id = 102;
COMMIT;

-- [Session 1 - Step 2B.3] Re-execute queries within the same transaction
SELECT job_id, status FROM processing_jobs WHERE job_id = 102;
SELECT count(*) AS running_test_jobs 
FROM processing_jobs 
WHERE job_id IN (101, 102) AND status = 'RUNNING';
-- --> RESULT IN SESSION 1: Consistent snapshot preserved!
--     Row-level status remains 'RUNNING' and count remains 1 despite Session 2's commit.
COMMIT;


-- ----------------------------------------------------------------------------
-- Test 2C: Serialization Anomaly / Write Skew Resolution under SERIALIZABLE
-- ----------------------------------------------------------------------------
-- Scenario:
--   Clinical Constraint: Site 'SITE-LOS-01' must maintain at least one operational
--   scanner at all times.
--   Currently, SITE-LOS-01 has two operational scanners: SCN-LOS-3T01 and SCN-LOS-15T1.
--
--   Under REPEATABLE READ:
--     Session 1 checks count (2) and takes SCN-LOS-3T01 offline for maintenance.
--     Session 2 concurrently checks count (2) and takes SCN-LOS-15T1 offline.
--     Both commit! Invariant violated: ZERO scanners operational (Write Skew).
--
--   Under SERIALIZABLE (SSI):
--     PostgreSQL tracks SIREAD locks on predicates and rows. When both transactions
--     attempt to commit, PostgreSQL detects the rw-antidependency cycle and aborts
--     one transaction with SQLSTATE 40001 (serialization_failure).
-- ----------------------------------------------------------------------------

-- Ensure both scanners at Lagos site are operational
UPDATE mri_scanners SET is_operational = TRUE WHERE site_id = 'SITE-LOS-01';

-- [Session 1 - Step 2C.1] Start SERIALIZABLE transaction and inspect operational scanners
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT count(*) AS operational_count 
FROM mri_scanners 
WHERE site_id = 'SITE-LOS-01' AND is_operational = TRUE;

-- [Session 2 - Step 2C.2] Concurrently start SERIALIZABLE transaction and inspect
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT count(*) AS operational_count 
FROM mri_scanners 
WHERE site_id = 'SITE-LOS-01' AND is_operational = TRUE;

-- [Session 1 - Step 2C.3] Since count is 2 (>= 2), Session 1 takes SCN-LOS-3T01 offline
UPDATE mri_scanners 
SET is_operational = FALSE 
WHERE scanner_id = 'SCN-LOS-3T01';

-- [Session 2 - Step 2C.4] Since Session 2 also saw count 2, it takes SCN-LOS-15T1 offline
UPDATE mri_scanners 
SET is_operational = FALSE 
WHERE scanner_id = 'SCN-LOS-15T1';

-- [Session 1 - Step 2C.5] Session 1 commits first
COMMIT;
-- Session 1 commits successfully.

-- [Session 2 - Step 2C.6] Session 2 attempts to commit
COMMIT;
-- --> RESULT IN SESSION 2: 
--     ERROR: could not serialize access due to read/write dependencies among transactions
--     DETAIL: Reason code: Canceled on identification as a pivot, during commit attempt.
--     HINT: The transaction might succeed if retried.
--     SQLSTATE: 40001
-- PostgreSQL's Serializable Snapshot Isolation (SSI) successfully protected the invariant!

-- Restore scanner operational states
UPDATE mri_scanners SET is_operational = TRUE WHERE site_id = 'SITE-LOS-01';


-- ============================================================================
-- EXPERIMENT 3: DEADLOCK DETECTION, GRAPH CYCLES, AND ENGINE RESOLUTION
-- ============================================================================
-- Scenario:
--   Session 1 locks Row A in mri_scans and then requests Row B in qc_evaluations.
--   Session 2 locks Row B in qc_evaluations and then requests Row A in mri_scans.
--   This forms a mutual circular dependency in the database wait-for graph:
--     Session 1 -> waits for Session 2 -> waits for Session 1
--
-- PostgreSQL Engine Response:
--   PostgreSQL activates its deadlock detector after deadlock_timeout (default 1000ms).
--   It traverses the Lock Wait Graph, identifies the directed cycle, selects one
--   transaction as the victim, and cancels it with error 40P01.
--   The non-victim transaction unblocks and successfully commits.
-- ============================================================================

-- Ensure test rows exist
UPDATE mri_scans SET file_size_bytes = 25482310 WHERE scan_id = 'SCN-LOS-006-T1';
UPDATE qc_evaluations SET snr_score = 19.85 WHERE scan_id = 'SCN-LOS-006-T1';

-- [Session 1 - Step 3.1] Lock scan record in Session 1
BEGIN;
UPDATE mri_scans 
SET file_size_bytes = file_size_bytes + 1024 
WHERE scan_id = 'SCN-LOS-006-T1';

-- [Session 2 - Step 3.2] Lock QC evaluation record in Session 2
BEGIN;
UPDATE qc_evaluations 
SET snr_score = snr_score + 0.1 
WHERE scan_id = 'SCN-LOS-006-T1';

-- [Session 1 - Step 3.3] Session 1 attempts to lock the QC record (BLOCKED by Session 2)
UPDATE qc_evaluations 
SET snr_score = snr_score + 0.2 
WHERE scan_id = 'SCN-LOS-006-T1';
-- Session 1 hangs, waiting for Session 2's lock on qc_evaluations.

-- [Session 2 - Step 3.4] Session 2 attempts to lock the scan record (BLOCKED by Session 1)
UPDATE mri_scans 
SET file_size_bytes = file_size_bytes + 2048 
WHERE scan_id = 'SCN-LOS-006-T1';
-- Both sessions are now cross-blocked!

-- --> RESULT AFTER deadlock_timeout (1 second):
-- PostgreSQL detects circular dependency in LockManager:
--   ERROR: deadlock detected
--   DETAIL: Process X waits for ExclusiveLock on tuple ... blocked by Process Y.
--           Process Y waits for ExclusiveLock on tuple ... blocked by Process X.
--   HINT: See server log for query details.
--   SQLSTATE: 40P01
--
-- One session receives the ERROR and rolls back:
ROLLBACK;

-- The other surviving session unblocks, executes, and commits:
COMMIT;

-- Clean up any residual test jobs
DELETE FROM processing_jobs WHERE job_id IN (101, 102);
