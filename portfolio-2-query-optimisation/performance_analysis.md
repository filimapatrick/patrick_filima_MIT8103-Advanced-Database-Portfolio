# Portfolio 2: Query Processing and Optimisation
## Empirical Performance & Query Plan Analysis

**Course:** MIT 8103 – Advanced Database Systems  
**Institution:** Miva Open University  
**Student:** Patrick Filima  
**Database Engine:** PostgreSQL 16.16 (Homebrew, aarch64-apple-darwin)  
**Benchmark Database:** `anrdms_benchmark`  
**Dataset Scale:** 100,036 MRI Scans · 80,023 Processing Jobs · 70,020 QC Evaluations · 5,025 Participants  
**Benchmarking Tool:** `EXPLAIN (ANALYZE, BUFFERS)`  

---

### 1. Executive Summary

In clinical and neuroinformatics research platforms, database scalability depends heavily on the interaction between application query patterns and the database cost-based query optimizer. In small development databases (< 1,000 tuples), query optimizers frequently favor sequential table scans (`Seq Scan`) because the overhead of index page lookup and random I/O exceeds sequential block reading. However, when database volume scales to enterprise dimensions (e.g. 100,000+ imaging sessions across regional hospital networks), missing or suboptimal indexes result in severe latency bottlenecks, CPU exhaustion, and disk thrashing.

To evaluate query processing and optimization empirically, an independent benchmark database (`anrdms_benchmark`) was provisioned and populated with **100,036 synthetic MRI scan records**, **80,023 compute jobs**, and **70,020 QC evaluations** using PostgreSQL's set-based `generate_series()`. Controlled A/B experiments were executed comparing baseline query performance (unindexed) against targeted index strategies (Composite B-Tree, Partial Indexing, and Index-Only Scans).

> [!NOTE]
> **Experimental Methodology & Workload Notice:**  
> The baseline and optimised queries were executed against the same benchmark dataset using the same PostgreSQL environment. Table statistics were refreshed using `ANALYZE` before the experiments. However, cache state was not explicitly controlled, and the recorded execution times represent individual benchmark runs. The results therefore demonstrate observed performance improvements under the tested conditions rather than definitive average performance across all workloads. Furthermore, the 100,000-record benchmark dataset represents a synthetic database workload generated specifically to test query optimizer scaling characteristics, rather than a clinically calibrated multi-modal MRI cohort.

---

### 2. PostgreSQL Cost Model Fundamentals

PostgreSQL's cost-based query optimizer assigns an estimated cost metric to prospective execution paths based on expected I/O operations and CPU cycles:

$$\text{Total Cost} = (N_{\text{pages}} \times \text{seq\_page\_cost}) + (N_{\text{tuples}} \times \text{cpu\_tuple\_cost}) + (N_{\text{operators}} \times \text{cpu\_operator\_cost})$$

Where default PostgreSQL configuration parameters specify:
* `seq_page_cost = 1.0` (sequential disk block fetch)
* `random_page_cost = 4.0` (random disk block fetch, reflecting non-sequential block reads)
* `cpu_tuple_cost = 0.01` (CPU processing per record)
* `cpu_operator_cost = 0.0025` (CPU evaluation per `WHERE` condition or comparison operator)

When an index is absent, PostgreSQL must read every disk page sequentially and evaluate filter predicates across all rows. When an optimal index is constructed, the optimizer navigates balanced B-Tree structures ($O(\log N)$) to locate exact leaf pages, substantially reducing block accesses.

---

### 3. Empirical Optimization Experiments

#### Experiment 1: High-Selectivity Sequence & Temporal Range Query

**Research Use Case:** Clinicians filtering high-resolution functional MRI sessions (`fMRI-rest`) acquired during a specific six-month study window (January–June 2025) sorted chronologically.

**SQL Query:**
```sql
SELECT scan_id, participant_id, sequence_type, acquisition_date, file_size_bytes
FROM mri_scans
WHERE sequence_type = 'fMRI-rest'
  AND acquisition_date >= '2025-01-01 00:00:00+01'
  AND acquisition_date <  '2025-07-01 00:00:00+01'
ORDER BY acquisition_date DESC;
```

* **Baseline Execution Plan (Without Index):**
  ```text
  Sort (cost=5109.91..5115.81 rows=2361 width=51) (actual time=10.213..10.257 rows=2350 loops=1)
    Sort Key: acquisition_date DESC
    Sort Method: quicksort  Memory: 298kB
    Buffers: shared hit=3227
    ->  Seq Scan on mri_scans (cost=0.00..4977.63 rows=2361 width=51) (actual time=0.005..9.960 rows=2350 loops=1)
          Filter: ((acquisition_date >= ...) AND (acquisition_date < ...) AND (sequence_type = 'fMRI-rest'))
          Rows Removed by Filter: 97686
          Buffers: shared hit=3227
  Execution Time: 10.314 ms
  ```
  *Analysis:* The engine performed a full sequential scan across 3,227 shared buffer blocks, discarded 97,686 non-matching rows, and performed an in-memory Quicksort on the remaining 2,350 rows.

* **Targeted Index Strategy:**
  A composite B-Tree index on `(sequence_type, acquisition_date DESC)`:
  ```sql
  CREATE INDEX idx_scans_seq_date ON mri_scans(sequence_type, acquisition_date DESC);
  ```

* **Optimized Execution Plan (With Composite Index):**
  ```text
  Sort (cost=3355.36..3361.22 rows=2344 width=51) (actual time=1.199..1.243 rows=2350 loops=1)
    Sort Key: acquisition_date DESC
    Sort Method: quicksort  Memory: 298kB
    Buffers: shared hit=456 read=14
    ->  Bitmap Heap Scan on mri_scans (cost=70.30..3224.16 rows=2344 width=51) (actual time=0.446..0.956 rows=2350 loops=1)
          Recheck Cond: ((sequence_type = 'fMRI-rest') AND (acquisition_date >= ...) AND (acquisition_date < ...))
          Heap Blocks: exact=456
          Buffers: shared hit=456 read=14
          ->  Bitmap Index Scan on idx_scans_seq_date (cost=0.00..69.72 rows=2344 width=0) (actual time=0.420..0.420 rows=2350 loops=1)
                Index Cond: ((sequence_type = 'fMRI-rest') AND (acquisition_date >= ...) AND (acquisition_date < ...))
                Buffers: shared read=14
  Execution Time: 1.298 ms
  ```

* **Why the Sort Remained:**  
  The composite index successfully eliminated the full-table sequential scan, reducing table page reads from 3,227 to 456 blocks. However, an in-memory Quicksort remained in the plan. A `Bitmap Heap Scan` operates by first building a bitmap of matching tuple TIDs from the index and then visiting table heap pages in physical block order to minimize random disk head movement and optimize I/O locality. Because heap pages are visited in physical storage order rather than B-Tree key order, the sorted sequence of `acquisition_date DESC` is not preserved by the bitmap scan, requiring PostgreSQL to perform an explicit in-memory sort on the resulting 2,350 matching rows.

* **Empirical Gain:**
  * **Execution Time:** Dropped from **10.314 ms** to **1.298 ms** (**7.95x speedup / 87.4% latency drop**).
  * **Buffer Accesses:** Shared-buffer page accesses dropped from **3,227 blocks** (all hits) to **470 blocks** (456 hits + 14 reads), representing an **85.4% reduction in shared-buffer block accesses**.
  * **Index Physical Size:** The resulting composite index measures **3,256 kB** (3.26 MB) in storage.

---

#### Experiment 2: Quality-Certified Cohort Retrieval (Correlated Subquery)

**Research Use Case:** Automated pipeline ingestion fetching certified T1-weighted structural scans that have passed radiologist quality assurance (`overall_quality = 'PASS'` and `usable_for_analysis = TRUE`).

**SQL Query:**
```sql
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
```

* **Baseline Execution Plan (Without Index):**
  ```text
  Hash Semi Join (cost=2611.45..7320.13 rows=12925 width=43) (actual time=7.370..20.377 rows=23343 loops=1)
    Hash Cond: ((ms.scan_id)::text = (qc.scan_id)::text)
    Buffers: shared hit=4478
    ->  Seq Scan on mri_scans ms (cost=0.00..4477.45 rows=33309 width=43) (actual time=0.002..9.751 rows=33358 loops=1)
          Filter: ((sequence_type)::text = 'T1w'::text)
          Rows Removed by Filter: 66678
          Buffers: shared hit=3227
    ->  Hash (cost=2126.25..2126.25 rows=38816 width=15) (actual time=7.361..7.362 rows=46683 loops=1)
          Buckets: 65536  Batches: 1  Memory Usage: 2655kB
          Buffers: shared hit=1251
          ->  Seq Scan on qc_evaluations qc (cost=0.00..2126.25 rows=38816 width=15) (actual time=0.001..4.859 rows=46683 loops=1)
                Filter: (usable_for_analysis AND ((overall_quality)::text = 'PASS'::text))
                Rows Removed by Filter: 23337
                Buffers: shared hit=1251
  Execution Time: 20.822 ms
  ```

* **Targeted Index Strategy:**
  A **Partial Filtered Index** that indexes *only* passed, usable scans:
  ```sql
  CREATE INDEX idx_qc_pass_usable_partial 
  ON qc_evaluations(scan_id) 
  WHERE overall_quality = 'PASS' AND usable_for_analysis = TRUE;
  ```

* **Optimized Execution Plan (With Partial Index):**
  ```text
  Hash Semi Join (cost=1683.51..6392.40 rows=12972 width=43) (actual time=4.541..17.662 rows=23343 loops=1)
    Hash Cond: ((ms.scan_id)::text = (qc.scan_id)::text)
    Buffers: shared hit=3228 read=180
    ->  Seq Scan on mri_scans ms (cost=0.00..4477.45 rows=33189 width=43) (actual time=0.002..9.964 rows=33358 loops=1)
          Filter: ((sequence_type)::text = 'T1w'::text)
          Rows Removed by Filter: 66678
          Buffers: shared hit=3227
    ->  Hash (cost=1194.78..1194.78 rows=39099 width=15) (actual time=4.533..4.533 rows=46683 loops=1)
          Buckets: 65536  Batches: 1  Memory Usage: 2655kB
          Buffers: shared hit=1 read=180
          ->  Index Only Scan using idx_qc_pass_usable_partial on qc_evaluations qc (cost=0.29..1194.78 rows=39099 width=15) (actual time=0.008..1.893 rows=46683 loops=1)
                Heap Fetches: 0
                Buffers: shared hit=1 read=180
  Execution Time: 18.100 ms
  ```

* **Index-Only Scan Mechanics & Empirical Gain:**
  * **Heap Fetches = 0:** PostgreSQL obtained all required `scan_id` values directly from the partial index entries without fetching corresponding heap table tuples. This was possible because the table's visibility map confirmed tuple visibility without requiring heap tuple version checks. (Note that 180 shared reads occurred to load the required index blocks into shared buffers).
  * **Buffer Access Reduction:** Block accesses for `qc_evaluations` plummeted from **1,251 blocks** to **181 blocks** (**85.5% reduction** in QC table buffer accesses).
  * **Execution Time:** Reduced from **20.822 ms** to **18.100 ms** (**13.1% reduction**). The improvement is moderate because the large outer table (`mri_scans`) still underwent a sequential scan to filter T1w scans.
  * **Measured Physical Storage:** The partial index measures **1,448 kB**, compared to **2,184 kB** for an equivalent full-table index on `qc_evaluations(scan_id)`, demonstrating an empirical **33.7% storage saving**.

---

#### Experiment 3: Pipeline Backlog Identification (`NOT EXISTS` Anti-Join)

**Research Use Case:** Identifying uncompleted scan acquisitions awaiting dispatch to compute workers.

**SQL Query:**
```sql
SELECT ms.scan_id, ms.participant_id, ms.sequence_type, ms.acquisition_date
FROM mri_scans ms
WHERE NOT EXISTS (
    SELECT 1
    FROM processing_jobs pj
    WHERE pj.scan_id = ms.scan_id
      AND pj.status = 'COMPLETED'
);
```

* **Baseline Execution Plan (Without Index):**
  * `Hash Anti Join` over full sequential scan of `processing_jobs` (80,023 rows, 1,740 buffer blocks) and `mri_scans` (100,036 rows).
  * **Execution Time:** **25.686 ms**
  * **Total Estimated Cost:** **8412.51**
  * **Buffer Accesses:** **4,967 shared blocks**.

* **Targeted Index Strategy:**
  A **Partial Filtered Index** indexing only completed batch jobs:
  ```sql
  CREATE INDEX idx_jobs_completed_scan_partial 
  ON processing_jobs(scan_id) 
  WHERE status = 'COMPLETED';
  ```

* **Optimized Execution Plan (With Partial Index):**
  * Plan transitioned to **`Index Only Scan`** on `processing_jobs` (`Heap Fetches: 0`).
  * **Execution Time:** Dropped from **25.686 ms** to **21.183 ms** (**17.5% latency reduction**).
  * **Total Estimated Cost:** Reduced from **8412.51** to **7198.32** (**14.4% cost reduction**).
  * **Buffer Accesses for `processing_jobs`:** Dropped from **1,740 blocks** to **194 blocks** (**88.9% reduction** in job table block accesses).
  * **Measured Physical Storage:** The partial index measures **1,552 kB**, compared to **2,488 kB** for an equivalent full index on `processing_jobs(scan_id)`, an empirical **37.6% storage saving**.

---

### 4. Consolidated Performance Benchmark Matrix

| Experiment | Target Workload | Index Applied | Scan Type Before | Scan Type After | Buffer Accesses Before (Blocks) | Buffer Accesses After (Blocks) | Exec Time Before (ms) | Exec Time After (ms) | Speedup Factor | Cost Reduction | Measured Index Size |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Exp 1** | Temporal Sequence Filtering | Composite B-Tree `(sequence_type, acquisition_date DESC)` | `Seq Scan` + `Quicksort` | `Bitmap Index Scan` + `Sort` | 3,227 | 470 | 10.31 ms | **1.30 ms** | **7.95x** | 34.3% | 3,256 kB |
| **Exp 2** | Certified Cohort Retrieval | Partial Index `(scan_id) WHERE PASS AND usable` | `Seq Scan` on QC | `Index Only Scan` (Heap Fetches: 0) | 1,251 (QC) | 181 (QC) | 20.82 ms | **18.10 ms** | **1.15x** | 12.7% | 1,448 kB *(vs 2,184 kB full)* |
| **Exp 3** | Pipeline Backlog Anti-Join | Partial Index `(scan_id) WHERE status = 'COMPLETED'` | `Seq Scan` on Jobs | `Index Only Scan` (Heap Fetches: 0) | 1,740 (Jobs) | 194 (Jobs) | 25.69 ms | **21.18 ms** | **1.21x** | 14.4% | 1,552 kB *(vs 2,488 kB full)* |

*Note on Buffer Metrics: "Buffer Accesses" denotes total shared-buffer blocks accessed (shared hits found in memory + shared reads loaded into PostgreSQL shared buffers). A shared read does not necessarily imply a physical disk seek if the host operating system page cache already held the file blocks.*

---

### 5. Architectural Trade-offs & Engineering Recommendations

While secondary indexes dramatically accelerate read latency, database engineering requires balancing retrieval gains against write penalties:

1. **Write Overhead (Insert / Update Penalty):**
   * Every write operation (`INSERT`, `UPDATE`, `DELETE`) on an indexed table incurs overhead because PostgreSQL must update the underlying table heap and every associated secondary B-Tree structure.
   * On high-throughput streaming systems (such as high-volume hospital PACS data ingest), maintaining multiple unselective secondary indexes increases Write-Ahead Logging (WAL) volume and causes B-Tree page splits. Indexes should therefore be strictly justified by query frequency and selectivity.
2. **Partial Index Advantage in Neuroinformatics:**
   * In typical research workflows, clinical queries disproportionately target *Passed QC* scans or *Completed* processing jobs rather than failed or abandoned attempts.
   * Creating **Partial Indexes** (`WHERE status = 'COMPLETED'`) prevents indexing pending, running, or failed runs. As empirically verified above, this reduced index physical storage by **33.7%** (QC) and **37.6%** (Jobs), while eliminating index update penalties when transient pending jobs are created.
3. **Covering Indexes for Index-Only Scans:**
   * When an index contains all attributes requested by a query clause (e.g. `scan_id`), PostgreSQL can satisfy query execution entirely from index leaf pages via an **Index Only Scan**, provided the visibility map confirms no concurrent uncommitted transactions.

---

### 6. Verification Artifacts

* [`benchmark_data.sql`](./benchmark_data.sql): Set-based synthetic generator populating 100,000+ records.
* [`indexes.sql`](./indexes.sql): Index creation and removal scripts for controlled A/B testing.
* [`execution_plans.sql`](./execution_plans.sql): Complete benchmarking script with `EXPLAIN (ANALYZE, BUFFERS)`.
* [`evidence/execution_plan_outputs.txt`](./evidence/execution_plan_outputs.txt): Full, unedited PostgreSQL 16 terminal execution plan transcripts.
