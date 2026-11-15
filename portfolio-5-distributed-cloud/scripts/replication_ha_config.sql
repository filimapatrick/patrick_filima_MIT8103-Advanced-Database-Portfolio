-- ============================================================================
-- MIT 8103: Advanced Database Systems
-- Continuous Assessment (CA) - September Cohort 2026
-- Student: Patrick Filima
-- Institution: Miva Open University
-- Portfolio 5: Distributed and Cloud Database Exercise
-- File: replication_ha_config.sql
-- 
-- System: African Neuroimaging Research Data Management System (ANRDMS)
-- Target DBMS: PostgreSQL 14+
-- Description: Physical streaming replication configuration, replication slot
--              lifecycle management, WAL archiving parameters, and high-availability
--              failover inspection for multi-region hospital deployments.
-- ============================================================================

\set ECHO all
\timing on

-- ============================================================================
-- 1. REPLICATION PARAMETERS & HIGH-AVAILABILITY AUDIT
-- ============================================================================
-- Physical streaming replication in PostgreSQL uses continuous Write-Ahead Log
-- (WAL) streaming from the Primary node to one or more Standby nodes.
-- In ANRDMS, this provides:
--   1. Read Scalability: Offloading heavy research aggregations to read replicas.
--   2. High Availability: Automatic failover if the primary Lagos node experiences outage.
--   3. Disaster Recovery: Asynchronous replication to geographically distant Abuja.
-- ============================================================================

\echo '=== 1. AUDITING POSTGRESQL STREAMING REPLICATION PARAMETERS ==='

SELECT 
    name AS parameter_name,
    setting AS configured_value,
    unit AS parameter_unit,
    short_desc AS architectural_description
FROM pg_settings
WHERE name IN (
    'wal_level',
    'max_wal_senders',
    'max_replication_slots',
    'synchronous_commit',
    'hot_standby',
    'hot_standby_feedback',
    'archive_mode',
    'max_standby_archive_delay',
    'max_standby_streaming_delay'
)
ORDER BY name;

-- ============================================================================
-- 2. PHYSICAL REPLICATION SLOT LIFECYCLE
-- ============================================================================
-- Replication slots guarantee that the Primary node will not prematurely delete
-- WAL segments needed by a lagging standby node during network WAN interruptions.

\echo '=== 2. CREATING PHYSICAL REPLICATION SLOT FOR ABUJA STANDBY NODE ==='

-- Drop slot if it already exists from a prior test run
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_replication_slots WHERE slot_name = 'standby_abuja_slot') THEN
        PERFORM pg_drop_replication_slot('standby_abuja_slot');
    END IF;
END $$;

-- Create dedicated physical replication slot for National Hospital Abuja standby
SELECT * FROM pg_create_physical_replication_slot('standby_abuja_slot');

\echo '=== 2.1 INSPECTING ACTIVE REPLICATION SLOTS IN pg_replication_slots ==='
SELECT 
    slot_name,
    plugin,
    slot_type,
    active,
    temporary,
    restart_lsn,
    wal_status
FROM pg_replication_slots
WHERE slot_name = 'standby_abuja_slot';

-- ============================================================================
-- 3. WRITE-AHEAD LOG (WAL) LSN AND CLUSTER HEALTH TELEMETRY
-- ============================================================================

\echo '=== 3. WAL LOG SEQUENCE NUMBER (LSN) & RECOVERY STATE TELEMETRY ==='

SELECT 
    pg_is_in_recovery() AS is_standby_node,
    pg_current_wal_lsn() AS current_primary_wal_lsn,
    pg_walfile_name(pg_current_wal_lsn()) AS active_wal_filename;

-- Telemetry query used by monitoring agents (e.g. Prometheus / Patroni) to detect lag:
\echo '=== 3.1 ACTIVE REPLICATION CONNECTIONS (pg_stat_replication) ==='
SELECT 
    pid,
    usename,
    application_name,
    client_addr,
    backend_start,
    state,
    sync_state,
    sync_priority
FROM pg_stat_replication;

-- ============================================================================
-- 4. CLEANUP REPLICATION SLOT
-- ============================================================================
\echo '=== 4. CLEANING UP TEST REPLICATION SLOT ==='
SELECT pg_drop_replication_slot('standby_abuja_slot');

SELECT COUNT(*) AS active_slots_count
FROM pg_replication_slots
WHERE slot_name = 'standby_abuja_slot';

\echo '=== REPLICATION CONFIGURATION & HA TELEMETRY SUITE COMPLETE ==='
