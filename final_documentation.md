# MIT 8103 – Advanced Database Systems: Final Portfolio Documentation & Technical Reflection

**Student Name:** Patrick Filima  
**Student ID:** 301900778  
**Institution:** Miva Open University  
**Degree Programme:** Master of Information Technology (MIT)  
**Course Code & Title:** MIT 8103 – Advanced Database Systems  
**Academic Session:** 2026/2027 (September 2026 Cohort)  
**Assessment Weighting:** 40 Marks (Continuous Assessment Portfolio)  
**Private GitHub Repository:** [https://github.com/filimapatrick/patrick_filima_MIT8103-Advanced-Database-Portfolio](https://github.com/filimapatrick/patrick_filima_MIT8103-Advanced-Database-Portfolio)  

---

## 1. Selected Organisation & Case Study Statement

### 1.1 Organisation & Context
The selected case study is the **African Neuroimaging Research Data Management System (ANRDMS)**, an enterprise-grade medical research database designed to support multi-site neuroimaging cohorts across Nigeria. Clinical neuroscience research in West Africa addresses major public health burdens—including stroke, vascular dementia, Alzheimer's disease, traumatic brain injury, and neuro-infectious conditions. However, neuroimaging initiatives face systemic infrastructure challenges: high-dimensional data, heterogeneous scanner hardware, inter-city WAN latency, and strict data protection laws.

ANRDMS federates five premier clinical teaching institutions:
1. **Lagos University Teaching Hospital (LUTH, Lagos)** – South West Regional Node (`SITE-LOS-01`)
2. **National Hospital Abuja (NHA, Abuja)** – North Central National Coordination Hub (`SITE-ABJ-01`)
3. **University College Hospital (UCH, Ibadan)** – South West Regional Node (`SITE-IBD-01`)
4. **University of Nigeria Teaching Hospital (UNTH, Enugu)** – South East Regional Node (`SITE-ENU-01`)
5. **Ahmadu Bello University Teaching Hospital (ABUTH, Zaria)** – North West Regional Node (`SITE-ZAR-01`)

### 1.2 System Users
- **Neuroimaging Researchers & PIs:** Query multi-site cohorts by diagnosis, demographics, and imaging sequence to conduct epidemiological studies.
- **Radiologists & MRI Technicians:** Register scanners, log scan acquisition parameters, and record clinical radiological reports.
- **Neuroinformatics Developers & Pipeline Engineers:** Track automated computational image processing pipelines (e.g., FreeSurfer, FSL, QSIPrep) and log execution telemetry.
- **Quality Control (QC) Officers:** Perform visual quality audits and assign pass/fail grades on raw and derived scans.
- **Database Administrators (DBAs):** Monitor ACID transactions, manage horizontal partitioning, maintain replication slots, and enforce data security.

### 1.3 Major Data Stored & Key Database Operations
- **Core Entities:** Research participants, hospital research sites, MRI scanner hardware specifications, neurological diagnoses, scan acquisition metadata, research projects, image processing jobs, and quality control evaluations.
- **High-Dimensional Artifacts:** BIDS-compliant (Brain Imaging Data Structure) imaging metadata, diffusion MRI gradient tables (`b_values`, `b_vectors`), fMRI slice timing, and automated morphometric measurements (hippocampal volumes, cortical thickness).
- **Core Operations:** Multi-table atomic clinical registration, high-throughput sequence filtering, automated job scheduling with pessimistic row locking, BIDS document validation and aggregation, horizontal list partition pruning, Two-Phase Commit (2PC) participant transfers, and cross-node foreign data federation.

---

## 2. Executive Summary of the Five Portfolio Activities

```
+----------------------------------------------------------------------------------------------------------+
|                                    ANRDMS CONTINUOUS ASSESSMENT ARCHITECTURE                             |
|                                                                                                          |
|   Portfolio 1: Database Design & 3NF Relational Backbone (PostgreSQL 16)                                  |
|   ├── 11 Normalized Tables, BCNF/3NF Decomposition, Declarative Constraints & Seed Data                  |
|                                                                                                          |
|   Portfolio 2: Query Processing & Index Optimisation (Cost-Based Optimizer)                             |
|   ├── 5 Analytical Queries, B-tree/Composite/Partial Indexes, 13.1%–87.4% Execution Time Reduction       |
|                                                                                                          |
|   Portfolio 3: Transactions & Concurrency Control (ACID & MVCC)                                          |
|   ├── Atomic Commits, Savepoints, MVCC Tuple Versioning, 'FOR UPDATE' Locking, Deadlock Resolution       |
|                                                                                                          |
|   Portfolio 4: NoSQL & Advanced Data Models (Polyglot Persistence)                                       |
|   ├── MongoDB 7.0 BIDS Documents, $jsonSchema Validation, Multikey Indexes, PostgreSQL JSONB + GIN       |
|                                                                                                          |
|   Portfolio 5: Distributed & Cloud Database Systems (Scale-Out & HA)                                     |
|   └── CAP/PACELC Theory, Horizontal List Partitioning, Two-Phase Commit (2PC), postgres_fdw, Streaming HA|
+----------------------------------------------------------------------------------------------------------+
```

### Portfolio 1: Database Design and Modelling (7 Marks)
- **Deliverables:** [`schema.sql`](./portfolio-1-database-design/schema.sql), [`seed_data.sql`](./portfolio-1-database-design/seed_data.sql), [`er_diagram.mermaid`](./portfolio-1-database-design/er_diagram.mermaid), [`data_dictionary.md`](./portfolio-1-database-design/data_dictionary.md), [`normalisation_report.md`](./portfolio-1-database-design/normalisation_report.md).
- **Technical Implementation:** Designed a normalized relational schema in PostgreSQL comprising 11 interrelated entities. Applied Boyce-Codd (BCNF) and Third Normal Form (3NF) principles to decompose functional dependencies, eliminating insert, update, and deletion anomalies.
- **Data Integrity:** Enforced surrogate primary keys, natural candidate keys (`UNIQUE`), foreign key referential integrity with cascading controls, and domain constraints (e.g., non-negative MRI repetition times `ck_scans_tr`, valid magnetic field strengths `ck_scanners_magnetic_field`). Populated the database with realistic synthetic clinical cohorts representing 37 MRI scans across 5 Nigerian hospitals.

### Portfolio 2: Query Processing and Optimisation (7 Marks)
- **Deliverables:** [`queries.sql`](./portfolio-2-query-optimisation/queries.sql), [`benchmark_data.sql`](./portfolio-2-query-optimisation/benchmark_data.sql), [`indexes.sql`](./portfolio-2-query-optimisation/indexes.sql), [`execution_plans.sql`](./portfolio-2-query-optimisation/execution_plans.sql), [`performance_analysis.md`](./portfolio-2-query-optimisation/performance_analysis.md).
- **Technical Implementation:** Established a scaled benchmark database (`anrdms_benchmark`) with 100,000 synthetic MRI scans. Developed five core business queries covering sequence filtering, diagnostic cohort aggregations, scanner utilization, QC pass rates, and compute backlog tracking.
- **Empirical Optimization:** Profiled queries using `EXPLAIN (ANALYZE, BUFFERS)`. Deployed tailored index structures: single-column B-tree, composite B-tree (`site_id, sequence_type, acquisition_date DESC`), and partial indexes (`WHERE overall_quality = 'Pass'`, `WHERE job_status = 'Pending'`).
- **Results:** Sequence retrieval execution time dropped from 23.36 ms to 2.95 ms (**87.4% faster**); QC retrieval dropped from 15.68 ms to 13.62 ms (**13.1% faster**); backlog processing dropped from 3.72 ms to 3.07 ms (**17.5% faster**). Detailed why Bitmap Heap Scans still require explicit Sort steps due to physical heap block visitation order.

### Portfolio 3: Transactions and Concurrency (7 Marks)
- **Deliverables:** [`transactions.sql`](./portfolio-3-transactions-concurrency/transactions.sql), [`concurrency_tests.sql`](./portfolio-3-transactions-concurrency/concurrency_tests.sql), [`run_concurrency_tests.py`](./portfolio-3-transactions-concurrency/run_concurrency_tests.py), [`transaction_analysis.md`](./portfolio-3-transactions-concurrency/transaction_analysis.md).
- **Technical Implementation:** Implemented multi-statement ACID transactions demonstrating atomic commits across 4 tables, automatic rollback upon constraint violation (`ck_scans_tr`), intermediate `SAVEPOINT` recovery, and PostgreSQL MVCC tuple versioning (`ctid`, `xmin`, `xmax`).
- **Concurrency & Contention:** Automated multi-threaded testing using a custom Python harness. Simulated concurrent worker races over queued processing jobs; demonstrated that uncoordinated `SELECT` followed by `UPDATE` caused Lost Updates. Resolved this using pessimistic row-level locking (`SELECT ... FOR UPDATE SKIP LOCKED`), achieving 100% throughput with zero lock contention. Induced and resolved mutual deadlocks via PostgreSQL's deadlock detector (`deadlock_timeout = 1000ms`).

### Portfolio 4: NoSQL and Advanced Data Models (7 Marks)
- **Deliverables:** [`scans_bids.json`](./portfolio-4-nosql/documents/scans_bids.json), [`pipeline_metrics.json`](./portfolio-4-nosql/documents/pipeline_metrics.json), [`mongodb_queries.js`](./portfolio-4-nosql/scripts/mongodb_queries.js), [`run_mongo.js`](./portfolio-4-nosql/scripts/run_mongo.js), [`hybrid_jsonb.sql`](./portfolio-4-nosql/scripts/hybrid_jsonb.sql), [`nosql_modeling.md`](./portfolio-4-nosql/nosql_modeling.md).
- **Technical Implementation:** Addressed the relational impedance mismatch for polymorphous neuroimaging data by implementing a Document NoSQL model in MongoDB 7.0 and a polyglot `JSONB` schema in PostgreSQL. Designed collections adhering to BIDS specifications with nested array structures for diffusion gradient tables (`b_values: [0, 1000, 2000]`) and slice timings.
- **Document Governance & Analytics:** Enforced strict database-level `$jsonSchema` validation, verified via live negative tests trapping range errors (Code 121) and duplicate keys (Code 11000). Created multikey indexes and verified `IXSCAN` plans. Executed advanced aggregation pipelines utilizing `$match`, `$unwind`, `$group`, `$project`, and `$facet` to compute subcortical volumetry and cortical thinning across clinical cohorts. Demonstrated PostgreSQL `JSONB` containment queries (`@>`) accelerated by Generalized Inverted Indexes (`USING gin (metadata jsonb_path_ops)`).

### Portfolio 5: Distributed and Cloud Database Exercise (6 Marks)
- **Deliverables:** [`partitioning_sharding.sql`](./portfolio-5-distributed-cloud/scripts/partitioning_sharding.sql), [`two_phase_commit.sql`](./portfolio-5-distributed-cloud/scripts/two_phase_commit.sql), [`postgres_fdw_federation.sql`](./portfolio-5-distributed-cloud/scripts/postgres_fdw_federation.sql), [`replication_ha_config.sql`](./portfolio-5-distributed-cloud/scripts/replication_ha_config.sql), [`run_distributed_tests.py`](./portfolio-5-distributed-cloud/scripts/run_distributed_tests.py), [`distributed_architecture.md`](./portfolio-5-distributed-cloud/distributed_architecture.md).
- **Technical Implementation:** Evaluated CAP and PACELC trade-offs under Nigerian telecommunication conditions, establishing a CP architecture for patient identity and an AP architecture for hospital edge scan acquisition. Implemented horizontal list partitioning on `mri_scans_partitioned` by `site_id` across 5 hospital partitions; verified that single-site queries pruned **80% of partitions**, executing in **0.015 ms**.
- **Distributed Transactions & Federation:** Configured `max_prepared_transactions = 20` and executed Two-Phase Commit (2PC) protocols (`PREPARE TRANSACTION`, `COMMIT PREPARED`, `ROLLBACK PREPARED`), verifying atomic multi-site participant transfers and clean recovery with 0 orphan records. Configured SQL/MED database federation via `postgres_fdw`, empirically proving **Remote Filter Pushdown** (`Remote SQL: WHERE sequence_type = 'T1w'`) in **0.75 ms**. Audited streaming replication parameters, managed physical replication slots (`standby_abuja_slot`), and architected a sovereign Hybrid Edge-Cloud deployment reducing WAN bandwidth by **98.4%**.

---

## 3. Comprehensive Summary of Deliverables & Empirical Evidence

| Portfolio Activity | Primary Implementation Script | Academic Report / Analysis | Live Recorded Evidence Transcript | Verified Key Result |
| :--- | :--- | :--- | :--- | :--- |
| **Portfolio 1:** Database Design & 3NF Modelling | [`schema.sql`](./portfolio-1-database-design/schema.sql)<br/>[`seed_data.sql`](./portfolio-1-database-design/seed_data.sql) | [`normalisation_report.md`](./portfolio-1-database-design/normalisation_report.md)<br/>[`data_dictionary.md`](./portfolio-1-database-design/data_dictionary.md) | [`verification_evidence.md`](./portfolio-1-database-design/verification_evidence.md) | 11 tables normalized to BCNF/3NF; 100% foreign key constraints validated. |
| **Portfolio 2:** Query Optimisation & Benchmarking | [`queries.sql`](./portfolio-2-query-optimisation/queries.sql)<br/>[`indexes.sql`](./portfolio-2-query-optimisation/indexes.sql) | [`performance_analysis.md`](./portfolio-2-query-optimisation/performance_analysis.md) | [`execution_plans.sql`](./portfolio-2-query-optimisation/execution_plans.sql)<br/>[`query_results.md`](./portfolio-2-query-optimisation/query_results.md) | Sequence filtering latency reduced by **87.4%**; partial indexes saved **33.7%–37.6%** disk space. |
| **Portfolio 3:** Transactions & Concurrency Control | [`transactions.sql`](./portfolio-3-transactions-concurrency/transactions.sql)<br/>[`run_concurrency_tests.py`](./portfolio-3-transactions-concurrency/run_concurrency_tests.py) | [`transaction_analysis.md`](./portfolio-3-transactions-concurrency/transaction_analysis.md) | [`transaction_outputs.txt`](./portfolio-3-transactions-concurrency/evidence/transaction_outputs.txt)<br/>[`concurrency_outputs.txt`](./portfolio-3-transactions-concurrency/evidence/concurrency_outputs.txt) | Multi-table atomic commit, partial savepoint rollback, and lost update prevention via `FOR UPDATE`. |
| **Portfolio 4:** NoSQL & Advanced Data Models | [`mongodb_queries.js`](./portfolio-4-nosql/scripts/mongodb_queries.js)<br/>[`hybrid_jsonb.sql`](./portfolio-4-nosql/scripts/hybrid_jsonb.sql) | [`nosql_modeling.md`](./portfolio-4-nosql/nosql_modeling.md) | [`mongodb_live_outputs.txt`](./portfolio-4-nosql/evidence/mongodb_live_outputs.txt)<br/>[`jsonb_hybrid_outputs.txt`](./portfolio-4-nosql/evidence/jsonb_hybrid_outputs.txt) | Live MongoDB 7.0 validation (Codes 121 & 11000); multikey `IXSCAN`; hybrid PostgreSQL JSONB GIN index. |
| **Portfolio 5:** Distributed & Cloud Systems | [`partitioning_sharding.sql`](./portfolio-5-distributed-cloud/scripts/partitioning_sharding.sql)<br/>[`run_distributed_tests.py`](./portfolio-5-distributed-cloud/scripts/run_distributed_tests.py) | [`distributed_architecture.md`](./portfolio-5-distributed-cloud/distributed_architecture.md) | [`partitioning_outputs.txt`](./portfolio-5-distributed-cloud/evidence/partitioning_outputs.txt)<br/>[`2pc_outputs.txt`](./portfolio-5-distributed-cloud/evidence/2pc_outputs.txt)<br/>[`federation_outputs.txt`](./portfolio-5-distributed-cloud/evidence/federation_outputs.txt) | **80% partition pruning**; 2PC atomic transfer & abort recovery; `postgres_fdw` remote filter pushdown in 0.75 ms. |

---

## 4. Individual Technical Reflection: Engineering Choices & Lessons Learned

Developing the ANRDMS portfolio across the semester provided profound insights into the engineering trade-offs governing modern data systems.

### 4.1 Key Design Choices & Trade-Offs
1. **Relational Normalization vs. Distributed Partitioning Constraints:**
   In Portfolio 1, strict Third Normal Form (3NF) dictated that `mri_scans` must not store `site_id` directly, because site affiliation is transitively dependent through `mri_scanners(scanner_id)`. However, when implementing declarative horizontal list partitioning in Portfolio 5, PostgreSQL required the partition key (`site_id`) to be part of the composite primary key (`PRIMARY KEY (scan_id, site_id)`). This demonstrated a fundamental real-world principle: **distributed scalability and partition pruning occasionally justify intentional denormalization of partition keys**.
2. **Pessimistic Locking vs. Optimistic Concurrency:**
   In Portfolio 3, testing concurrent HPC workers competing for processing jobs revealed that naive `SELECT ... UPDATE` loops caused severe Lost Updates. While optimistic concurrency (version numbers) is popular in web applications, it causes excessive transaction aborts and retries under high contention. Implementing pessimistic row-level locking (`SELECT ... FOR UPDATE SKIP LOCKED`) allowed workers to reserve jobs instantly with zero collision, providing deterministic throughput for neuroimaging pipelines.
3. **Polyglot Persistence vs. Relational Bloat:**
   Attempting to model multi-shell diffusion MRI gradient tables and FreeSurfer parcellations in a purely relational schema leads to either massive sparse tables (hundreds of `NULL` columns) or the dreaded Entity-Attribute-Value (EAV) anti-pattern. Adopting a polyglot persistence strategy—using MongoDB documents and PostgreSQL `JSONB` for polymorphic metadata, while retaining 3NF relational tables for clinical identity and billing—achieved optimal balance between relational rigor and document flexibility.

### 4.2 Engineering Challenges Faced & Solutions Implemented
- **Bitmap Heap Scans and Sorting Overhead:** During Portfolio 2 benchmarking, creating a composite index (`site_id, sequence_type, acquisition_date DESC`) did not eliminate the query execution plan's `Sort` node. By investigating the PostgreSQL storage engine, I discovered that Bitmap Heap Scans visit heap pages in physical block order to optimize disk I/O, destroying index sort order. Understanding this distinction between index-ordered scans and bitmap scans was a major theoretical breakthrough.
- **Prepared Transactions & System Catalog Hazards:** In Portfolio 5, enabling Two-Phase Commit required modifying `postgresql.conf` to set `max_prepared_transactions = 20`. During failure simulation, I observed that prepared transactions remain locked in `pg_prepared_xacts` across server restarts. Left unmanaged, in-doubt transactions hold exclusive table locks and prevent `VACUUM` from truncating dead tuples. This highlighted the imperative need for automated coordinator watchdog daemons.

### 4.3 Core Lessons Learned
Through hands-on empirical experimentation, I learned that database administration is not merely about writing syntactically correct SQL; it is about understanding how the database engine interacts with hardware, memory buffers, network topologies, and concurrency semantics. Moving beyond standard textbook descriptions to capture live execution plans, examine lock queues, and evaluate distributed failure recovery has significantly strengthened my engineering capabilities as a Master of Information Technology student.

---

## 5. Academic Integrity & Formal AI Use Declaration

In accordance with Section 11 of the MIT 8103 Continuous Assessment specification, this declaration outlines the use of artificial intelligence tools in this portfolio:

1. **AI Tools Used:**  
   Google Antigravity Agentic Assistant (powered by Gemini models).
2. **Purpose of AI Use:**  
   - Brainstorming synthetic neuroimaging metadata structures aligned with international BIDS standards.
   - Assisting in the authoring of boilerplate test harnesses and complex Bash/Python orchestration scripts.
   - Providing peer-review feedback on draft explanations of PostgreSQL query execution plans and distributed protocols.
3. **Review, Verification, and Testing Process:**  
   - **Independent Verification:** All SQL scripts, MongoDB queries, Python test runners, and configuration commands were executed locally by the student against live PostgreSQL 16 and MongoDB 7.0 database daemons running on macOS.
   - **Correction of Theoretical Inaccuracies:** The student critically reviewed all generated content, actively correcting misconceptions (such as explaining why Bitmap Heap Scans retain sorting operations, clarifying buffer hits versus disk reads, enforcing valid foreign key relationships, and ensuring strict adherence to Nigerian clinical research contexts).
   - **Empirical Grounding:** Every numerical metric, query execution time, memory buffer count, and log sequence number reported in this portfolio reflects actual, unedited experimental transcripts captured from live database engines. The student takes full ownership and intellectual responsibility for all submitted work.

---

## References

1. Abadi, D. J. (2012). Consistency tradeoffs in modern distributed database system design: CAP is only part of the story. *Computer*, 45(2), 37–42.
2. Brewer, E. A. (2000). Towards robust distributed systems. *Keynote at the ACM Symposium on Principles of Distributed Computing (PODC)*, Portland, OR.
3. Codd, E. F. (1970). A relational model of data for large shared data banks. *Communications of the ACM*, 13(6), 377–387.
4. Gorgolewski, K. J., Auer, T., Calhoun, V. D., et al. (2016). The brain imaging data structure, a format for organizing and describing outputs of neuroimaging experiments. *Scientific Data*, 3, 160044.
5. Gray, J. (1978). Notes on data base operating systems. *Operating Systems: An Advanced Course*, Lecture Notes in Computer Science, vol 60, pp. 393–481. Springer, Berlin.
6. ISO/IEC 9075-9:2016. *Information technology — Database languages — SQL — Part 9: Management of External Data (SQL/MED)*.
7. MongoDB Inc. (2024). *MongoDB 7.0 Manual: Document Validation, Multikey Indexes, and Aggregation Pipeline Operations*. https://www.mongodb.com/docs/manual/
8. Nigeria Data Protection Commission (NDPC). (2023). *Nigeria Data Protection Act (NDPA) 2023*. Official Gazette of the Federal Republic of Nigeria.
9. PostgreSQL Global Development Group. (2024). *PostgreSQL 16 Documentation: Indexes, MVCC, Table Partitioning, Two-Phase Transactions, and postgres_fdw*. https://www.postgresql.org/docs/16/
