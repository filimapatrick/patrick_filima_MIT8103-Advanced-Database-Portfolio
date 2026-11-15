-- ============================================================================
-- MIT 8103: Advanced Database Systems
-- Continuous Assessment (CA) - September Cohort 2026
-- Student: Patrick Filima
-- Institution: Miva Open University
-- Portfolio 5: Distributed and Cloud Database Exercise
-- File: two_phase_commit.sql
-- 
-- System: African Neuroimaging Research Data Management System (ANRDMS)
-- Target DBMS: PostgreSQL 14+ (max_prepared_transactions > 0)
-- Description: Demonstrates distributed Two-Phase Commit (2PC) transaction
--              protocol coordination, in-doubt transaction inspection via
--              pg_prepared_xacts, and distributed abort recovery.
-- ============================================================================

\set ECHO all
\timing on

-- ============================================================================
-- 1. DISTRIBUTED TRANSACTION PROBLEM & 2PC PROTOCOL OVERVIEW
-- ============================================================================
-- In the ANRDMS multi-site neuroimaging network, clinical trial protocols
-- occasionally require atomic data updates across distinct hospital nodes.
-- For example, when a longitudinal study participant relocates from Lagos (LUTH)
-- to Abuja (NHA), their clinical profile must update while reserving imaging
-- resources on the remote hospital's scanner.
--
-- A standard local COMMIT cannot guarantee distributed atomicity: if the local
-- node commits while the remote node encounters a WAN network severance or crash,
-- the multi-site system enters an inconsistent, split-brain state.
--
-- The Two-Phase Commit (2PC) protocol solves this:
--   Phase 1 (Prepare): The coordinator instructs participating nodes to execute
--                      operations, write WAL records, lock tuples, and enter the
--                      PREPARED state. Nodes vote YES if ready, or NO if failed.
--   Phase 2 (Commit/Abort): If all nodes vote YES, the coordinator issues
--                           COMMIT PREPARED. If any node fails or times out,
--                           the coordinator issues ROLLBACK PREPARED.
-- ============================================================================

-- Clean up any lingering prepared transactions from previous runs
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT gid FROM pg_prepared_xacts WHERE gid LIKE 'anrdms_%' LOOP
        EXECUTE format('ROLLBACK PREPARED %L;', r.gid);
    END LOOP;
END $$;


-- ============================================================================
-- EXPERIMENT 1: ATOMIC DISTRIBUTED PREPARED COMMIT (HAPPY PATH)
-- ============================================================================
-- Scenario: Transfer participant ANRDMS-LOS-002 from Lagos (LUTH) to Abuja (NHA)
-- and schedule an initial baseline 3.0T scan on the Abuja scanner (SCN-ABJ-SIGNA).
-- All nodes must agree before changes become visible across the network.
-- ============================================================================

\echo '=== EXPERIMENT 1, PHASE 1: Executing Distributed Work & Preparing Transaction ==='

BEGIN;

-- Operation 1: Update participant primary site affiliation to Abuja
UPDATE participants
SET primary_site_id = 'SITE-ABJ-01'
WHERE participant_id = 'ANRDMS-LOS-002';

-- Operation 2: Schedule baseline research scan on Abuja 3.0T MAGNETOM Prisma
INSERT INTO mri_scans (
    scan_id, participant_id, scanner_id, project_id, sequence_type,
    acquisition_date, repetition_time_ms, echo_time_ms, flip_angle_deg,
    voxel_size_x_mm, voxel_size_y_mm, voxel_size_z_mm, matrix_x, matrix_y, slices_count,
    dicom_series_uid, bids_relative_path, file_size_bytes
) VALUES (
    'SCN-ABJ-901-T1',
    'ANRDMS-LOS-002',
    'SCN-ABJ-3T01',
    'PRJ-WASCS-2024',
    'T1w',
    CURRENT_TIMESTAMP + INTERVAL '1 day',
    2400.00,
    3.12,
    8.0,
    0.90, 0.90, 1.00,
    256, 256, 176,
    '1.3.12.2.1107.5.2.32.9001.20250601100000',
    'sub-LOS002/ses-02/anat/sub-LOS002_T1w.nii.gz',
    48500000
);

-- Complete Phase 1 (Prepare): Persist transaction locks and state to WAL
PREPARE TRANSACTION 'anrdms_xact_transfer_los_to_abj_001';

\echo '=== EXPERIMENT 1, VERIFICATION: Inspecting pg_prepared_xacts System Catalog ==='
-- The transaction is now in the "PREPARED" state on disk.
-- It survives client disconnects and server restarts until explicitly committed or aborted.
SELECT 
    gid AS transaction_identifier,
    prepared AS prepared_timestamp,
    owner AS transaction_owner,
    database AS database_name
FROM pg_prepared_xacts
WHERE gid = 'anrdms_xact_transfer_los_to_abj_001';

\echo '=== EXPERIMENT 1, ISOLATION CHECK: Verifying Uncommitted Changes are Hidden ==='
-- Under MVCC isolation, other concurrent sessions cannot see the prepared changes:
SELECT participant_id, primary_site_id
FROM participants
WHERE participant_id = 'ANRDMS-LOS-002';

SELECT scan_id, scanner_id, sequence_type
FROM mri_scans
WHERE scan_id = 'SCN-ABJ-901-T1';

\echo '=== EXPERIMENT 1, PHASE 2: Coordinator Issues COMMIT PREPARED ==='
-- All distributed participants acknowledged readiness; coordinator commits:
COMMIT PREPARED 'anrdms_xact_transfer_los_to_abj_001';

\echo '=== EXPERIMENT 1, POST-COMMIT VERIFICATION: Verifying Atomic Persistence ==='
-- Confirm changes are now durably committed and visible:
SELECT participant_id, primary_site_id
FROM participants
WHERE participant_id = 'ANRDMS-LOS-002';

SELECT scan_id, participant_id, scanner_id, sequence_type, file_size_bytes
FROM mri_scans
WHERE scan_id = 'SCN-ABJ-901-T1';

-- Confirm prepared transactions table is cleared:
SELECT COUNT(*) AS active_prepared_transactions
FROM pg_prepared_xacts
WHERE gid = 'anrdms_xact_transfer_los_to_abj_001';


-- ============================================================================
-- EXPERIMENT 2: DISTRIBUTED RECOVERY & ROLLBACK PREPARED (FAILURE SCENARIO)
-- ============================================================================
-- Scenario: Coordinator initiates multi-site transfer for participant ANRDMS-IBD-001
-- to Zaria (ABUTH). Phase 1 prepares the transaction, but before Phase 2 commit,
-- a simulated network partition severing connectivity to the North West region occurs.
-- The coordinator detects consensus failure and must issue ROLLBACK PREPARED
-- to guarantee that no orphaned records or lingering locks corrupt the database.
-- ============================================================================

\echo '=== EXPERIMENT 2, PHASE 1: Initiating Transaction & Reaching PREPARED State ==='

BEGIN;

-- Attempted transfer to Zaria node
UPDATE participants
SET primary_site_id = 'SITE-ZAR-01'
WHERE participant_id = 'ANRDMS-IBD-001';

INSERT INTO mri_scans (
    scan_id, participant_id, scanner_id, project_id, sequence_type,
    acquisition_date, repetition_time_ms, echo_time_ms, flip_angle_deg,
    voxel_size_x_mm, voxel_size_y_mm, voxel_size_z_mm, matrix_x, matrix_y, slices_count,
    dicom_series_uid, bids_relative_path, file_size_bytes
) VALUES (
    'SCN-ZAR-902-FL',
    'ANRDMS-IBD-001',
    'SCN-ZAR-15T1',
    'PRJ-NPEPP-2025',
    'FLAIR',
    CURRENT_TIMESTAMP + INTERVAL '2 days',
    9000.00,
    120.00,
    150.0,
    1.00, 1.00, 4.00,
    256, 256, 36,
    '1.3.12.2.1107.5.2.32.9002.20250602120000',
    'sub-IBD001/ses-02/anat/sub-IBD001_FLAIR.nii.gz',
    42000000
);

PREPARE TRANSACTION 'anrdms_xact_simulated_wan_failure_002';

\echo '=== EXPERIMENT 2, VERIFICATION: Inspecting Prepared State Before Abort ==='
SELECT gid, prepared, owner, database
FROM pg_prepared_xacts
WHERE gid = 'anrdms_xact_simulated_wan_failure_002';

\echo '=== EXPERIMENT 2, PHASE 2: WAN Timeout Detected -> Issuing ROLLBACK PREPARED ==='
-- Regional node unreachable; coordinator safely aborts the prepared transaction:
ROLLBACK PREPARED 'anrdms_xact_simulated_wan_failure_002';

\echo '=== EXPERIMENT 2, POST-ABORT VERIFICATION: Verifying Complete Rollback ==='
-- Confirm participant affiliation was NOT updated:
SELECT participant_id, primary_site_id
FROM participants
WHERE participant_id = 'ANRDMS-IBD-001';

-- Confirm uncommitted scan was NOT created:
SELECT COUNT(*) AS orphan_scans_count
FROM mri_scans
WHERE scan_id = 'SCN-ZAR-902-FL';

-- Confirm prepared transactions queue is completely clean:
SELECT COUNT(*) AS remaining_prepared_transactions
FROM pg_prepared_xacts
WHERE gid LIKE 'anrdms_%';

\echo '=== TWO-PHASE COMMIT SUITE COMPLETED SUCCESSFULLY ==='
