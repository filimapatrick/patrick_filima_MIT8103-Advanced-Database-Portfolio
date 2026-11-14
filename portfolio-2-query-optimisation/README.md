# Portfolio 2: Query Processing and Optimisation

**Course:** MIT 8103 – Advanced Database Systems  
**Institution:** Miva Open University  
**Student:** Patrick Filima  
**Cohort:** September 2026  
**Assessment:** Continuous Assessment (7 Marks)

---

## 1. Introduction

This portfolio builds directly upon the African Neuroimaging Research Data Management System (ANRDMS) developed in Portfolio 1.

The relational database contains interconnected tables for research sites, MRI scanners, participants, neurological diagnoses, research projects, MRI scans, processing pipelines, processing jobs, and quality control evaluations.

As the volume of neuroimaging data increases across multi-site hospital networks in Nigeria (LUTH, NHA, UCH, UNTH, ABUTH), efficient query processing becomes essential for clinical cohort selection, imaging biomarker retrieval, computational workflow monitoring, and data governance.

This portfolio investigates how advanced SQL queries, query execution plans, and indexing strategies can optimize database retrieval performance.

---

## 2. Objectives

- Develop advanced SQL queries utilizing multi-table joins, aggregations, subqueries, common table expressions (CTEs), and window functions.
- Retrieve meaningful clinical and neuroimaging research metrics from the ANRDMS database.
- Examine and interpret PostgreSQL query execution plans using `EXPLAIN ANALYZE`.
- Generate a high-volume synthetic benchmark dataset for scalability and performance testing.
- Empirically compare query performance before and after targeted indexing.
- Evaluate the engineering trade-offs between query latency, index storage overhead, and write performance.

---

## 3. Database Environment

- **DBMS:** PostgreSQL 16 (Homebrew, aarch64-apple-darwin)
- **Primary Database:** `anrdms` (Portfolio 1 schema with 11 relational tables)
- **Benchmark Database:** `anrdms_benchmark` (Volumetric performance testing)
- **Operating System:** macOS (Apple Silicon)
- **Data Domain:** Multi-site neuroimaging records and pulse sequence acquisitions

---

## 4. Research Questions

The advanced SQL queries address seven foundational neuroimaging research questions:

1. **Multi-Site Scanner Utilization:** How many MRI scans have been acquired at each research hospital site?
2. **Pathological Cohort Distribution:** How are research participants distributed across neurological conditions?
3. **Quality-Certified Cohort Retrieval:** Which T1-weighted MRI scans have passed radiologist quality control for structural morphometry?
4. **Computational Pipeline Failure Rate:** Which image processing workflows exhibit the highest failure rates across compute clusters?
5. **Multi-Modal Imaging Diversity:** Which participants have undergone multiple distinct imaging pulse sequences?
6. **Processing Pipeline Backlog:** Which MRI scans currently lack a successfully completed computational processing run?
7. **Longitudinal Session Ranking:** What is the most recent MRI scan acquisition for each participant?

---

## 5. Query Optimisation Methodology

A dedicated benchmark database (`anrdms_benchmark`) is utilized to evaluate query performance under scale without compromising the verified Portfolio 1 dataset.

The optimisation experiments proceed through the following stages:

1. **Data Scaling:** Generate a realistic volumetric dataset (100,000+ synthetic MRI scan records) using PostgreSQL's `generate_series()`.
2. **Optimizer Statistics:** Update table distribution statistics using `ANALYZE`.
3. **Baseline Measurement:** Execute target analytical queries without secondary indexes and record `EXPLAIN (ANALYZE, BUFFERS)` execution plans.
4. **Index Design & Implementation:** Construct targeted B-Tree, composite, and partial indexes tailored to the query filter and join predicates.
5. **Post-Optimization Measurement:** Re-run the identical queries under identical cache conditions.
6. **Performance Audit:** Compute speedup factors, buffer page reductions, and plan tree changes (`Seq Scan` $\to$ `Index Scan` / `Bitmap Heap Scan`).
7. **Trade-off Analysis:** Analyze the maintenance overhead and storage footprint of the introduced index structures.

---

## 6. Portfolio File Manifest

| File | Description | Status |
| :--- | :--- | :--- |
| [`queries.sql`](./queries.sql) | Seven research-oriented analytical SQL queries | **Completed** |
| [`benchmark_data.sql`](./benchmark_data.sql) | Large-scale synthetic data generator (100,000+ records) | **Completed** |
| [`indexes.sql`](./indexes.sql) | Index creation, tuning, and removal scripts | **Completed** |
| [`execution_plans.sql`](./execution_plans.sql) | `EXPLAIN (ANALYZE, BUFFERS)` benchmark scripts | **Completed** |
| [`query_results.md`](./query_results.md) | Verified output datasets for all seven research queries | **Completed** |
| [`performance_analysis.md`](./performance_analysis.md) | Quantitative benchmark comparison and performance findings | **Completed** |
| [`evidence/query_outputs.txt`](./evidence/query_outputs.txt) | Raw execution outputs of the 7 research queries | **Completed** |
| [`evidence/execution_plan_outputs.txt`](./evidence/execution_plan_outputs.txt) | Raw `EXPLAIN (ANALYZE, BUFFERS)` execution plan logs | **Completed** |

---

## 7. Benchmark Reproduction Instructions

To reproduce the 100,000-record optimization benchmarks on a local PostgreSQL instance from scratch:

```bash
# 1. Create a dedicated benchmark database
createdb anrdms_benchmark

# 2. Initialize the relational schema (11 tables and constraints)
psql -d anrdms_benchmark -v ON_ERROR_STOP=1 \
  -f portfolio-1-database-design/schema.sql

# 3. Load baseline lookup entities (sites, scanners, pipelines, diagnoses)
psql -d anrdms_benchmark -v ON_ERROR_STOP=1 \
  -f portfolio-1-database-design/seed_data.sql

# 4. Generate the high-volume synthetic benchmark dataset (100k scans, 80k jobs, 70k QC)
psql -d anrdms_benchmark -v ON_ERROR_STOP=1 \
  -f portfolio-2-query-optimisation/benchmark_data.sql

# 5. Execute the automated A/B indexing experiments (drops indexes, benchmarks baseline, creates indexes, re-benchmarks)
psql -d anrdms_benchmark -v ON_ERROR_STOP=1 \
  -P pager=off \
  -f portfolio-2-query-optimisation/execution_plans.sql
```

> [!NOTE]
> `execution_plans.sql` is completely self-contained: it explicitly drops existing secondary indexes, runs the unindexed baseline `EXPLAIN (ANALYZE, BUFFERS)` queries, constructs the targeted composite and partial indexes, refreshes planner statistics with `ANALYZE`, and re-runs the identical queries under optimized conditions. Running `indexes.sql` beforehand is not required.

---

## 8. Academic Integrity & Reproducibility

All participant identifiers, acquisition logs, and quality scores used in this portfolio are synthetic and intended solely for academic demonstration in MIT 8103. The 100,000-record benchmark dataset represents a synthetic database workload generated to test PostgreSQL query optimizer scaling characteristics.

All performance metrics, execution plans, and timing numbers represent actual, reproducible PostgreSQL 16 engine measurements.

---

## 9. Development Status Checklist

- [x] Folder structure and manifest initialization
- [x] Advanced SQL queries authored and checked against schema
- [x] Live query execution and result verification (`anrdms`)
- [x] Volumetric benchmark dataset generation (`anrdms_benchmark`: 100,000+ scans)
- [x] Baseline execution plan capture (`Seq Scan` + Quicksort)
- [x] Index creation and query optimization (Composite B-Tree & Partial Indexes)
- [x] Post-indexing execution plan capture (`Index Scan` / `Bitmap Scan` / `Index Only Scan`)
- [x] Performance analysis, buffer reduction audit, and trade-off documentation
