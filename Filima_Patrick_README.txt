================================================================================
MIT 8103 – ADVANCED DATABASE SYSTEMS: CONTINUOUS ASSESSMENT PORTFOLIO
================================================================================
Student Name:     Patrick Filima
Student ID:       301900778
Student Email:    p.filima0778@miva.edu.ng
Institution:      Miva Open University
Degree Programme: Master of Information Technology (MIT)
Course Code:      MIT 8103 – Advanced Database Systems
Cohort:           September 2026 Cohort
Academic Session: 2026/2027
Total Marks:      40 Marks
GitHub Repo:      https://github.com/filimapatrick/patrick_filima_MIT8103-Advanced-Database-Portfolio
================================================================================

1. CASE STUDY STATEMENT & SELECTED ORGANISATION
--------------------------------------------------------------------------------
Organisation Name:
African Neuroimaging Research Data Management System (ANRDMS)

Context & Nature of System:
ANRDMS is an enterprise-grade medical research database designed to manage multi-site
neuroimaging cohorts across Nigeria. Clinical neuroscience research in West Africa
addresses major public health burdens—including stroke, vascular dementia, Alzheimer's
disease, traumatic brain injury, and neuro-infectious conditions. However, neuroimaging
initiatives face systemic infrastructure challenges: high-dimensional data, heterogeneous
scanner hardware, inter-city WAN latency, and strict data protection laws.

Federated Clinical Institutions (Research Sites):
1. Lagos University Teaching Hospital (LUTH, Lagos) – South West Regional Node (SITE-LOS-01)
2. National Hospital Abuja (NHA, Abuja) – North Central National Coordination Hub (SITE-ABJ-01)
3. University College Hospital (UCH, Ibadan) – South West Regional Node (SITE-IBD-01)
4. University of Nigeria Teaching Hospital (UNTH, Enugu) – South East Regional Node (SITE-ENU-01)
5. Ahmadu Bello University Teaching Hospital (ABUTH, Zaria) – North West Regional Node (SITE-ZAR-01)

System Users:
- Neuroimaging Researchers & Principal Investigators (PIs)
- Radiologists and MRI Radiographers / Technicians
- Neuroinformatics Developers and Computational Pipeline Engineers
- Quality Control (QC) Officers
- Database Administrators (DBAs)

Major Data Stored:
- Research participant demographics and clinical diagnoses
- Research hospital sites and MRI scanner hardware specifications
- BIDS-compliant (Brain Imaging Data Structure) MRI acquisition metadata
- Computational pipeline metrics (FreeSurfer morphometry, FSL TBSS tract metrics)
- Image processing jobs and automated quality control evaluations

Key Database Operations:
- Multi-table atomic clinical registration (participants, diagnoses, scans, QC)
- High-throughput sequence filtering and multi-site cohort discovery
- Queue-based HPC compute job dispatching with pessimistic concurrency control
- Flexible, high-dimensional document validation and aggregation in MongoDB
- Horizontal list partition pruning and cross-node foreign data federation
- Two-Phase Commit (2PC) distributed participant transfers across hospital nodes


2. PORTFOLIO COMPONENTS & ASSESSMENT DELIVERABLES (40 MARKS)
--------------------------------------------------------------------------------
Component       | Description                         | Marks | Status
----------------+-------------------------------------+-------+----------
Portfolio 1     | Database Design and Modelling       | 7     | COMPLETED
Portfolio 2     | Query Processing and Optimisation   | 7     | COMPLETED
Portfolio 3     | Transactions and Concurrency        | 7     | COMPLETED
Portfolio 4     | NoSQL and Advanced Data Models      | 7     | COMPLETED
Portfolio 5     | Distributed and Cloud Database      | 6     | COMPLETED
Final Portfolio | Technical Reflection & AI Decl.     | 6     | COMPLETED
----------------+-------------------------------------+-------+----------
TOTAL           |                                     | 40    | 100%


3. SUMMARY OF PORTFOLIO ACTIVITIES & EMPIRICAL EVIDENCE
--------------------------------------------------------------------------------
PORTFOLIO 1: DATABASE DESIGN AND MODELLING (7 MARKS)
- Implemented 11 normalised tables in PostgreSQL 16 meeting strict Boyce-Codd (BCNF)
  and Third Normal Form (3NF) requirements.
- Eliminates insert, update, and deletion anomalies.
- Enforced domain constraints (ck_scans_tr, ck_scanners_magnetic_field), surrogate
  primary keys, natural unique keys, and cascading foreign key references.
- Seeded with realistic synthetic Nigerian neuroimaging cohorts (37 scans across 5 sites).
- Deliverables: schema.sql, seed_data.sql, er_diagram.mermaid, data_dictionary.md,
  normalisation_report.md, verification_evidence.md.

PORTFOLIO 2: QUERY PROCESSING AND OPTIMISATION (7 MARKS)
- Deployed a scaled benchmark database (anrdms_benchmark) with 100,000 synthetic scans.
- Designed 5 analytical queries and evaluated execution plans using EXPLAIN (ANALYZE, BUFFERS).
- Created single-column B-tree, composite B-tree, and partial indexes.
- Recorded Empirical Performance:
  * Sequence Filtering: Execution time dropped from 23.36 ms to 2.95 ms (87.4% faster).
  * QC Retrieval: Execution time dropped from 15.68 ms to 13.62 ms (13.1% faster).
  * Backlog Processing: Execution time dropped from 3.72 ms to 3.07 ms (17.5% faster).
  * Partial indexes saved 33.7% to 37.6% disk storage relative to full-table indexes.
- In-depth theoretical analysis of why Bitmap Heap Scans still require an explicit Sort
  step due to physical heap page visitation order.
- Deliverables: queries.sql, benchmark_data.sql, indexes.sql, execution_plans.sql,
  performance_analysis.md, query_results.md.

PORTFOLIO 3: TRANSACTIONS AND CONCURRENCY (7 MARKS)
- Implemented multi-statement ACID transactions in PostgreSQL 16:
  * Transaction 1: Atomic commit across 4 interrelated tables.
  * Transaction 2: Rollback on constraint violation (0 orphan records).
  * Transaction 3: Intermediate SAVEPOINT recovery and partial rollback.
  * Transaction 4: PostgreSQL MVCC tuple versioning (ctid, xmin, xmax inspection).
- Automated Concurrency Testing via Python (run_concurrency_tests.py):
  * Demonstrated Lost Updates under uncoordinated concurrent SELECT ... UPDATE.
  * Resolved contention using pessimistic row-level locking (SELECT ... FOR UPDATE SKIP LOCKED).
  * Achieved 100% throughput with zero lock contention across concurrent HPC workers.
  * Induced and resolved mutual deadlocks via PostgreSQL's deadlock detector (1000ms timeout).
- Deliverables: transactions.sql, concurrency_tests.sql, run_concurrency_tests.py,
  transaction_analysis.md, transaction_outputs.txt, concurrency_outputs.txt.

PORTFOLIO 4: NOSQL AND ADVANCED DATA MODELS (7 MARKS)
- Overcame the relational impedance mismatch for high-dimensional, polymorphic MRI
  metadata by implementing a BIDS-compliant Document model in MongoDB 7.0.
- Implemented strict database-level schema validation via MongoDB $jsonSchema:
  * Negative Test 1: Field limit violation (20.0 Tesla scanner rejected with Error 121).
  * Negative Test 2: Unique constraint violation (duplicate scan_id rejected with Error 11000).
- Created multikey indexes and verified index plans:
  * IXSCAN on idx_scans_dmri_bvalues_multikey with isMultiKey: true (1 key examined in 1 ms).
- Executed 4 advanced multi-stage aggregation pipelines:
  * Pipeline 1: Subcortical Volumetry ($match -> $group -> $project).
  * Pipeline 2: Cortical Thinning ($unwind: "$cortical_parcellations" -> $group).
  * Pipeline 3: Multi-shell Diffusion Arrays (b=2000, 64 directions filtered natively).
  * Pipeline 4: Dual-Branch HPC Telemetry & Mesh Quality ($facet).
- Polyglot Persistence: Implemented hybrid PostgreSQL JSONB with foreign keys to relational
  participants/sites and Generalized Inverted Indexes (GIN using jsonb_path_ops).
- Deliverables: scans_bids.json, pipeline_metrics.json, mongodb_queries.js, run_mongo.js,
  hybrid_jsonb.sql, nosql_modeling.md, mongodb_live_outputs.txt, jsonb_hybrid_outputs.txt.

PORTFOLIO 5: DISTRIBUTED AND CLOUD DATABASE EXERCISE (6 MARKS)
- Distributed Systems Theory: Evaluated CAP and PACELC theorems under Nigerian telecommunication
  conditions; established CP/PC/EC for clinical identity and AP/PA/EL for hospital edge ingestion.
- Horizontal List Partitioning & Partition Pruning:
  * Partitioned mri_scans_partitioned across 5 Nigerian hospital teaching centers (37 scans).
  * Verified Query Optimizer Partition Pruning: Single-site query pruned 80% of partitions
    (4 of 5 eliminated), scanning only mri_scans_lagos in 0.015 ms (shared hit=1).
- Distributed Two-Phase Commit (2PC):
  * Configured max_prepared_transactions = 20.
  * Verified PREPARE TRANSACTION in pg_prepared_xacts, strict MVCC uncommitted isolation,
    atomic COMMIT PREPARED, and simulated WAN link failure recovery via ROLLBACK PREPARED
    (0 orphan scans, 0 lingering in-doubt locks).
- Database Federation via postgres_fdw:
  * Mounted remote hospital node as transparent foreign table.
  * Verified Remote Filter Pushdown (Remote SQL: WHERE sequence_type = 'T1w') in 0.75 ms.
  * Executed cross-node federated JOIN across 36 records in 0.94 ms.
- Streaming Replication & HA:
  * Audited wal_level=replica, max_wal_senders=10, synchronous_commit=on, hot_standby=on.
  * Provisioned physical replication slot (standby_abuja_slot) and verified WAL LSN generation.
- Hybrid Edge-Cloud Deployment: Formulated edge compute (FreeSurfer on local NVMe) + national
  sovereign cloud hub (MDX-i / Galaxy Backbone), cutting WAN bandwidth demands by 98.4%.
- Deliverables: partitioning_sharding.sql, two_phase_commit.sql, postgres_fdw_federation.sql,
  replication_ha_config.sql, run_distributed_tests.py, distributed_architecture.md,
  partitioning_outputs.txt, 2pc_outputs.txt, federation_outputs.txt, replication_outputs.txt.


4. INSTRUCTIONS FOR INDEPENDENT VERIFICATION & REPRODUCTION
--------------------------------------------------------------------------------
The entire portfolio is designed for 100% automated, push-button verification.
From the repository root:

1. Test Portfolio 5 (Distributed & Cloud Database):
   python3 portfolio-5-distributed-cloud/scripts/run_distributed_tests.py
   [Result: 100% assertions pass across all 4 distributed stages]

2. Test Portfolio 4 (MongoDB 7.0 Document Suite):
   node portfolio-4-nosql/scripts/run_mongo.js
   [Result: Connects to MongoDB, validates $jsonSchema, tests error codes 121 & 11000,
    captures multikey execution plan, and executes all 4 aggregation pipelines]

3. Test Portfolio 3 (ACID & Concurrency Suite):
   python3 portfolio-3-transactions-concurrency/run_concurrency_tests.py
   [Result: Tests atomic commit, rollback, savepoints, MVCC versions, lost updates,
    FOR UPDATE row locking, and deadlock detection]

4. Execute PostgreSQL SQL Scripts:
   psql -d anrdms -f portfolio-1-database-design/schema.sql
   psql -d anrdms -f portfolio-1-database-design/seed_data.sql
   psql -d anrdms -f portfolio-4-nosql/scripts/hybrid_jsonb.sql
   psql -d anrdms_distributed -f portfolio-5-distributed-cloud/scripts/partitioning_sharding.sql
   psql -d anrdms_distributed -f portfolio-5-distributed-cloud/scripts/two_phase_commit.sql
   psql -d anrdms_distributed -f portfolio-5-distributed-cloud/scripts/postgres_fdw_federation.sql
   psql -d anrdms_distributed -f portfolio-5-distributed-cloud/scripts/replication_ha_config.sql


5. TECHNICAL REFLECTION: ENGINEERING TRADE-OFFS & LESSONS LEARNED
--------------------------------------------------------------------------------
1. Relational Normalization vs. Partitioning Key Constraints:
   In Portfolio 1, 3NF required omitting site_id from mri_scans because it is transitively
   dependent through mri_scanners(scanner_id). However, declarative table partitioning in
   PostgreSQL requires the partition key (site_id) to be part of the composite primary key
   (PRIMARY KEY (scan_id, site_id)). This demonstrated that distributed scalability and
   partition pruning occasionally justify intentional denormalization of partition keys.

2. Concurrency Control Mechanisms:
   Simulating concurrent HPC workers revealed that uncoordinated SELECT ... UPDATE loops
   caused severe Lost Updates. Implementing pessimistic row-level locking (SELECT ... FOR
   UPDATE SKIP LOCKED) allowed workers to reserve jobs with zero collision and 100% throughput,
   avoiding the high retry/abort rate of optimistic concurrency in high-contention pipelines.

3. Polyglot Persistence:
   Modeling high-dimensional neuroimaging metadata (diffusion gradient tables and cortical
   thickness meshes) in a purely relational schema causes severe sparse table bloat or EAV
   anti-patterns. Adopting MongoDB documents and PostgreSQL JSONB for polymorphic metadata,
   while retaining 3NF tables for clinical identity, provides the optimal balance of speed,
   flexibility, and relational integrity.

4. System Catalog Management under 2PC:
   Enabling Two-Phase Commit requires max_prepared_transactions > 0. During failure simulation,
   prepared transactions persisted in pg_prepared_xacts across crashes. Unresolved prepared
   transactions hold exclusive locks and block database VACUUM processes indefinitely,
   proving the imperative need for automated coordinator watchdog daemons.


6. ACADEMIC INTEGRITY & FORMAL AI-USE DECLARATION
--------------------------------------------------------------------------------
In accordance with Section 11 of the MIT 8103 Continuous Assessment specification:
1. AI Tool Used: Google Antigravity Agentic Assistant (powered by Gemini models).
2. Purpose of AI Use:
   - Brainstorming synthetic neuroimaging metadata structures aligned with international BIDS standards.
   - Authoring boilerplate test harnesses and Bash/Python orchestration scripts.
   - Providing peer-review feedback on draft explanations of execution plans and distributed protocols.
3. Student Review, Verification, and Testing:
   - Every script, query, and configuration command was executed and verified locally by the
     student against live PostgreSQL 16 and MongoDB 7.0 database daemons running on macOS.
   - The student critically reviewed all generated content, actively correcting theoretical
     inaccuracies (explaining why Bitmap Heap Scans retain sorting operations, clarifying buffer
     hits versus disk reads, enforcing valid foreign key relationships, and ensuring strict
     adherence to Nigerian clinical research contexts).
   - Every metric, execution time, buffer count, and log sequence number reported reflects
     actual, unedited experimental transcripts captured from live database engines.
   - The student takes full ownership and intellectual responsibility for all submitted work.

================================================================================
END OF README / SUBMISSION DOCUMENT
================================================================================
