# Portfolio 5: Distributed and Cloud Database Architecture (6 Marks)

**Course:** MIT 8103 – Advanced Database Systems  
**Institution:** Miva Open University  
**Student:** Patrick Filima  
**Student ID:** 301900778  
**System:** African Neuroimaging Research Data Management System (ANRDMS)  
**Weighting:** 6 Marks  

---

## 1. Executive Overview and Case Study Alignment

While Portfolios 1 through 4 established a normalised 3NF relational schema, query optimisation benchmarks, ACID transaction concurrency, and a BIDS-compliant NoSQL document model within single-instance engines, real-world clinical neuroimaging infrastructure operates across geographically separated healthcare centres.

The **African Neuroimaging Research Data Management System (ANRDMS)** federates five premier clinical teaching and research institutions across Nigeria:
1. **Lagos University Teaching Hospital (LUTH, Lagos)** – South West Regional Node (`SITE-LOS-01`)
2. **National Hospital Abuja (NHA, Abuja)** – North Central National Coordination Hub (`SITE-ABJ-01`)
3. **University College Hospital (UCH, Ibadan)** – South West Regional Node (`SITE-IBD-01`)
4. **University of Nigeria Teaching Hospital (UNTH, Enugu)** – South East Regional Node (`SITE-ENU-01`)
5. **Ahmadu Bello University Teaching Hospital (ABUTH, Zaria)** – North West Regional Node (`SITE-ZAR-01`)

Portfolio 5 addresses the critical distributed database challenges of WAN latency, asymmetric data volumes (kilobyte metadata vs. gigabyte 3D imaging volumes), Nigerian data sovereignty laws (NDPA 2023), network partitioning, and disaster recovery.

---

## 2. Key Learning Outcomes Demonstrated

1. **Distributed Systems Theory (CAP & PACELC Theorems):**
   - Detailed architectural evaluation of the trade-offs between Consistency ($C$), Availability ($A$), Latency ($L$), and Partition Tolerance ($P$) in the Nigerian clinical context.
   - Justified a **CP / PC / EC** architecture for core clinical identity, consent, and neurological diagnoses to eliminate fatal medical split-brain states, paired with an **AP / PA / EL** architecture at hospital edge nodes for high-throughput local scan acquisition.

2. **Horizontal Table Partitioning & Query Optimizer Pruning:**
   - Designed and deployed horizontal list partitioning on `mri_scans_partitioned` by `site_id` across the five regional hospital nodes (37 total scans).
   - Demonstrated **Query Optimizer Partition Pruning** using `EXPLAIN (ANALYZE, BUFFERS)`: single-site queries pruned **80% of partitions** (4 of 5 tables eliminated), scanning only `mri_scans_lagos` in **0.015 ms** with a single buffer hit (`shared hit=1`).
   - Verified compile-time partition constraint enforcement (unmapped site `SITE-KAN-01` rejected with SQLSTATE 23514).

3. **Distributed Atomic Transactions (Two-Phase Commit Protocol):**
   - Configured `max_prepared_transactions = 20` in PostgreSQL 16.
   - Implemented cross-site atomic participant transfers using Phase 1 (`PREPARE TRANSACTION`), in-doubt catalog inspection via `pg_prepared_xacts`, MVCC uncommitted isolation, and Phase 2 (`COMMIT PREPARED`).
   - Simulated WAN link failure recovery via `ROLLBACK PREPARED`, confirming **0 orphan scans** and zero dangling in-doubt transactions.

4. **Cross-Node Database Federation (`postgres_fdw`):**
   - Implemented SQL/MED (ISO/IEC 9075-9) database federation using PostgreSQL's Foreign Data Wrapper (`postgres_fdw`), mounting remote hospital nodes as transparent local foreign tables.
   - Empirically verified **Remote Filter Pushdown** (`Remote SQL: WHERE sequence_type = 'T1w'`), eliminating unnecessary WAN bandwidth usage by filtering at the remote source in **0.75 ms**.
   - Executed seamless cross-node federated `JOIN` operations across 36 records in **0.94 ms**.

5. **Physical Streaming Replication, Replication Slots & High Availability:**
   - Audited PostgreSQL replication parameters (`wal_level=replica`, `max_wal_senders=10`, `synchronous_commit=on`, `hot_standby=on`).
   - Managed physical replication slot lifecycle (`standby_abuja_slot`), preventing premature WAL recycling during inter-city WAN outages.
   - Verified active Write-Ahead Log (WAL) generation and Log Sequence Number (LSN) telemetry (`0/F8BCC00`).

6. **Enterprise Cloud & Hybrid Edge-Cloud Deployment Blueprint:**
   - Compared leading DBaaS platforms (AWS Aurora, Google Cloud SQL, Azure Database for PostgreSQL) against a self-managed hybrid deployment under Nigerian data sovereignty constraints.
   - Formulated a multi-tier **Hybrid Edge-Cloud Topology** combining hospital edge compute (FreeSurfer/FSL on local NVMe) with a sovereign national cloud hub (MDX-i / Galaxy Backbone), cutting WAN bandwidth demands by **98.4%**.

---

## 3. Directory Layout and Deliverables

```
portfolio-5-distributed-cloud/
├── README.md                      # Consolidated portfolio overview, deliverables, and reproduction guide
├── distributed_architecture.md    # Comprehensive academic report and distributed systems analysis
├── scripts/
│   ├── partitioning_sharding.sql  # Horizontal list partitioning DDL, data routing, and pruning tests
│   ├── two_phase_commit.sql       # Two-Phase Commit (2PC) protocol implementation and failure recovery
│   ├── postgres_fdw_federation.sql# SQL/MED foreign data wrapper federation and filter pushdown tests
│   ├── replication_ha_config.sql  # Streaming replication audit, slot lifecycle, and WAL telemetry
│   └── run_distributed_tests.py   # Automated Python test harness validating all 4 distributed stages
└── evidence/
    ├── partitioning_outputs.txt   # Live execution transcript: partition creation and pruning plans
    ├── 2pc_outputs.txt            # Live execution transcript: 2PC prepare, isolation, commit, and rollback
    ├── federation_outputs.txt     # Live execution transcript: FDW setup, remote pushdown, and federated JOIN
    ├── replication_outputs.txt    # Live execution transcript: replication parameters and slot inspection
    └── distributed_suite_outputs.txt # Consolidated execution log from automated Python test runner
```

### Direct Links to Artifacts
- 📄 [Comprehensive Distributed & Cloud Architecture Report](./distributed_architecture.md)
- 📜 [Partitioning & Sharding Script (SQL)](./scripts/partitioning_sharding.sql)
- 📜 [Two-Phase Commit Protocol Script (SQL)](./scripts/two_phase_commit.sql)
- 📜 [Foreign Data Wrapper Federation Script (SQL)](./scripts/postgres_fdw_federation.sql)
- 📜 [Replication & High-Availability Script (SQL)](./scripts/replication_ha_config.sql)
- 🐍 [Automated Distributed Test Runner (Python)](./scripts/run_distributed_tests.py)
- 📋 [Partitioning & Pruning Evidence](./evidence/partitioning_outputs.txt)
- 📋 [Two-Phase Commit Evidence](./evidence/2pc_outputs.txt)
- 📋 [Database Federation Evidence](./evidence/federation_outputs.txt)
- 📋 [Streaming Replication Evidence](./evidence/replication_outputs.txt)
- 📋 [Automated Suite Execution Transcript](./evidence/distributed_suite_outputs.txt)

---

## 4. Summary of Empirical Experiments & Verified Results

| Stage / Experiment | Technical Mechanism | Key Verification Command | Verified Empirical Result / Finding |
| :--- | :--- | :--- | :--- |
| **Stage 1: Partitioning** | Horizontal List Partitioning (`site_id`) | `\d+ mri_scans_partitioned` | **37 scans** routed across 5 child tables (Lagos 9, Abuja 9, Ibadan 7, Enugu 6, Zaria 6). Unmapped site `SITE-KAN-01` rejected. |
| **Stage 1: Pruning** | Query Optimizer Partition Pruning | `EXPLAIN (ANALYZE, BUFFERS)` | Single-site query pruned **80% of partitions** (4 of 5 eliminated); scanned only `mri_scans_lagos` in **0.015 ms** (`shared hit=1`). |
| **Stage 2: 2PC Commit** | Distributed Atomic Commit | `PREPARE TRANSACTION` $\to$ `COMMIT PREPARED` | Transaction logged in `pg_prepared_xacts`; uncommitted changes isolated under MVCC; successfully applied atomically. |
| **Stage 2: 2PC Abort** | WAN Disconnect Recovery | `ROLLBACK PREPARED` | Coordinator aborted prepared transaction after simulated network drop; verified **0 orphan scans** and zero lingering locks. |
| **Stage 3: Pushdown** | SQL/MED Remote Filter Pushdown | `EXPLAIN VERBOSE` on foreign table | `Remote SQL: WHERE sequence_type = 'T1w'` pushed to remote node; filtered remotely in **0.75 ms** without transferring unneeded scans. |
| **Stage 3: Federation** | Cross-Node Federated JOIN | Local `participants` $\bowtie$ Foreign `mri_scans` | Nested loop join retrieved 36 matching records across nodes in **0.94 ms**. |
| **Stage 4: HA Audit** | Physical Streaming Replication | `SELECT name, setting FROM pg_settings` | Audited `wal_level=replica`, `max_wal_senders=10`, `synchronous_commit=on`, `hot_standby=on`. |
| **Stage 4: Slots** | Replication Slot Lifecycle | `pg_create_physical_replication_slot` | Successfully created `standby_abuja_slot` to prevent WAL segment recycling during WAN severance; LSN advanced to `0/F8BCC00`. |
| **Stage 5: Test Suite** | Automated End-to-End Suite | `python3 run_distributed_tests.py` | **100% assertions passed** across all 4 experimental domains in 0.14 seconds. |

---

## 5. Step-by-Step Reproduction Instructions

All experiments can be reproduced on any macOS or Linux workstation with PostgreSQL 14+ installed.

### Prerequisites: Enable Prepared Transactions
PostgreSQL disables Two-Phase Commit by default (`max_prepared_transactions = 0`). To enable it:
```bash
# Append to postgresql.conf (e.g., /opt/homebrew/var/postgresql@16/postgresql.conf):
echo "max_prepared_transactions = 20" >> $(psql -U $(whoami) -d postgres -t -A -c "SHOW config_file;")

# Restart PostgreSQL service (macOS Homebrew example):
brew services restart postgresql@16
```

### Option A: Run the Automated Python Verification Harness (Recommended)
The automated Python test runner executes all four distributed stages, performs rigorous programmatic assertions, and prints a formatted test report:

```bash
# From the repository root:
python3 portfolio-5-distributed-cloud/scripts/run_distributed_tests.py
```

*Expected Terminal Output:*
```text
================================================================================
ANRDMS DISTRIBUTED & CLOUD DATABASE TEST SUITE
Course: MIT 8103 - Advanced Database Systems
Student: Patrick Filima | Miva Open University
================================================================================
Connecting to database: anrdms_distributed ...
[SUCCESS] Connected to PostgreSQL 16.x

=== STAGE 1: TESTING HORIZONTAL PARTITIONING & PRUNING ===
[PASS] Correctly verified 5 regional site partitions.
[PASS] Total scans correctly distributed across partitions: 37
[PASS] Partition pruning verified: single-site query scanned only 'mri_scans_lagos'
[PASS] Multi-site query pruned to exactly 2 partitions ('mri_scans_abuja', 'mri_scans_lagos')
[PASS] Invalid partition insert correctly rejected with error 23514

=== STAGE 2: TESTING TWO-PHASE COMMIT (2PC) PROTOCOL ===
[PASS] Prepared transaction correctly registered in pg_prepared_xacts.
[PASS] Strict MVCC isolation verified: uncommitted transfer invisible.
[PASS] COMMIT PREPARED successfully finalized distributed transaction.
[PASS] Participant transfer successfully verified in primary table.
[PASS] Simulated WAN failure: ROLLBACK PREPARED cleanly removed prepared state.
[PASS] Rollback verification: 0 orphan scans found after abort.

=== STAGE 3: TESTING POSTGRES_FDW DATABASE FEDERATION ===
[PASS] postgres_fdw extension and foreign server verified.
[PASS] Remote filter pushdown confirmed: WHERE sequence_type = 'T1w' pushed to remote.
[PASS] Federated cross-node JOIN returned 36 matched records.

=== STAGE 4: TESTING REPLICATION & HIGH AVAILABILITY CONFIGURATION ===
[PASS] Replication parameter 'wal_level' = replica
[PASS] Replication parameter 'synchronous_commit' = on
[PASS] Replication slot 'standby_abuja_slot' created and verified active.
[PASS] Current WAL insert LSN verified.
[PASS] Cleaned up test replication slot.

================================================================================
ALL 4 DISTRIBUTED DATABASE EXPERIMENTAL STAGES PASSED SUCCESSFULLY (100%)
================================================================================
```

### Option B: Execute Individual SQL Scripts via `psql`
You can also run each SQL demonstration individually using the PostgreSQL command-line client:

```bash
# 1. Horizontal List Partitioning & Pruning:
psql -d anrdms_distributed -f portfolio-5-distributed-cloud/scripts/partitioning_sharding.sql

# 2. Two-Phase Commit (2PC) Atomic Transactions:
psql -d anrdms_distributed -f portfolio-5-distributed-cloud/scripts/two_phase_commit.sql

# 3. Cross-Node postgres_fdw Federation & Filter Pushdown:
psql -d anrdms_distributed -f portfolio-5-distributed-cloud/scripts/postgres_fdw_federation.sql

# 4. Physical Streaming Replication & High Availability Audit:
psql -d anrdms_distributed -f portfolio-5-distributed-cloud/scripts/replication_ha_config.sql
```
