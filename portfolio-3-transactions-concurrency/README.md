# Portfolio 3: Transactions and Concurrency (7 Marks)

**Course:** MIT 8103 – Advanced Database Systems  
**Institution:** Miva Open University  
**Student:** Patrick Filima  
**System:** African Neuroimaging Research Data Management System (ANRDMS)  
**Database Engine:** PostgreSQL 16.16 (Homebrew, Apple Silicon macOS)  
**Dedicated Test Database:** `anrdms_transactions`  

---

## 1. Overview and Assessment Alignment

Portfolio 3 focuses on the practical implementation, empirical verification, and theoretical analysis of **Transaction Processing and Concurrency Control** for the African Neuroimaging Research Data Management System (ANRDMS).

To prevent accidental modification of the baseline Portfolio 1 dataset and ensure that Portfolio 2 query optimization benchmarks remain completely reproducible, all Portfolio 3 experiments are executed against an isolated test database: `anrdms_transactions`.

### Key Learning Outcomes Demonstrated:
1. **Practical ACID Properties:** Multi-table transactions preserving clinical invariants, constraint-enforced rollbacks eliminating orphan records, and hierarchical fault recovery via `SAVEPOINT`.
2. **PostgreSQL MVCC Internals & Durability:** Inspection of internal tuple headers (`xmin`, `xmax`, `ctid`), demonstrating physical non-overwriting storage, version chaining, and Write-Ahead Logging (WAL) write and flush alignment under `synchronous_commit = on`.
3. **ANSI Isolation Levels & Concurrency Phenomena:** Live empirical reproduction of row-level and aggregate Non-Repeatable Reads under `READ COMMITTED`, snapshot preservation under `REPEATABLE READ`, and Serializable Snapshot Isolation (SSI) detecting Write Skew under `SERIALIZABLE` (SQLSTATE `40001`).
4. **Pessimistic Concurrency & High-Throughput Queueing:** Eliminating race conditions and lost updates on HPC pipeline workers using `SELECT ... FOR UPDATE` and contention-free `FOR UPDATE SKIP LOCKED`.
5. **Deadlock Detection and Resolution:** Interleaved cross-table updates generating wait-for graph cycles, engine cycle resolution via `deadlock_timeout` (SQLSTATE `40P01`), and application retry patterns with jittered exponential backoff.
6. **Automated Verification Harness:** A portable, cross-platform Python test runner (`run_concurrency_tests.py`) that executes concurrent interactive `psql` sessions and programmatically verifies expected outcomes.

---

## 2. Directory Layout and Deliverables

```
portfolio-3-transactions-concurrency/
├── README.md                      # Consolidated portfolio overview and reproduction instructions
├── transactions.sql               # Practical ACID transaction scripts (Commit, Rollback, Savepoint, MVCC)
├── concurrency_tests.sql          # Dual-session interactive SQL concurrency experiments
├── run_concurrency_tests.py       # Portable Python test harness driving parallel interactive sessions
├── transaction_analysis.md        # Comprehensive academic report and theoretical analysis
└── evidence/
    ├── transaction_outputs.txt    # Raw PostgreSQL 16 terminal execution log of transactions.sql
    └── concurrency_outputs.txt    # Raw chronological execution transcript of dual-session concurrency tests
```

### Direct Document Links
- 📄 [Comprehensive Transaction & Concurrency Analysis Report](./transaction_analysis.md)
- 📜 [ACID Transaction Scripts (SQL)](./transactions.sql)
- 📜 [Concurrency & Locking Test Scripts (SQL)](./concurrency_tests.sql)
- 🐍 [Automated Parallel Test Harness (Python)](./run_concurrency_tests.py)
- 📋 [Raw Transaction Execution Output](./evidence/transaction_outputs.txt)
- 📋 [Raw Concurrency & Deadlock Execution Transcript](./evidence/concurrency_outputs.txt)

---

## 3. Experimental Summary & Key Results

| Experiment | Focus Area | Observed Engine Behavior | Recorded Outcome / Metric |
| :--- | :--- | :--- | :--- |
| **Transaction 1** | Atomicity & Consistency | Multi-table atomic commit spanning `participants`, `diagnoses`, `scans`, and `qc`. | **All 4 entities committed together**. `COMMIT` logged at 1.02 ms. |
| **Transaction 2** | Integrity Rollback | Scan insertion with negative TR (`-2300 ms`) violates check constraint `ck_scans_tr`. | Aborted with constraint error; **0 orphan records** remained post-rollback. |
| **Transaction 3** | Savepoints (`SAVEPOINT`) | Invalid HPC job status fails; `ROLLBACK TO SAVEPOINT` recovers without losing scan. | Scan and participant preserved; valid fallback job committed cleanly. |
| **Transaction 4** | MVCC Tuple Inspection | Update on `handedness` creates new physical tuple version; `ctid` shifts from `(0,26)` to `(0,29)`. | Non-overwriting tuple verified; WAL flushed at LSN `0/F1813F0`. |
| **Experiment 1A** | Lost Update Prevention | Concurrent workers claim Job 101; Worker 2 blocks on `SELECT ... FOR UPDATE`. | Worker 2 held until Worker 1 commits; 0 qualifying rows returned upon re-eval. |
| **Experiment 1B** | Non-Blocking Queue | Both workers execute `SELECT ... FOR UPDATE SKIP LOCKED` on pending jobs. | **Worker 2 did not wait**; skipped locked Job 101 and claimed Job 102. |
| **Experiment 2A** | `READ COMMITTED` | Query 1 reads Job 101 as `RUNNING` (count 2); Session 2 commits update. Query 2 reads `COMPLETED` (count 1). | **Non-Repeatable Read observed** at both row and aggregate levels. |
| **Experiment 2B** | `REPEATABLE READ` | Query 1 reads Job 102 as `RUNNING` (count 1); Session 2 commits update. Query 2 still reads `RUNNING` (count 1). | **Consistency preserved**. Transaction-level snapshot ignored concurrent commit. |
| **Experiment 2C** | `SERIALIZABLE` | Both sessions attempt to take the last operational scanner offline (Write Skew). | SSI detected rw-antidependency; aborted Session 2 with **SQLSTATE 40001**. |
| **Experiment 3** | Deadlock Resolution | Circular dependency: Session 1 locks scan, requests QC; Session 2 locks QC, requests scan. | Engine triggered after `deadlock_timeout` (1s); aborted Session 1 with **SQLSTATE 40P01**. |

---

## 4. Instructions for Reproduction

### Step 1: Create and Populate the Dedicated Test Database
To preserve the baseline `anrdms` database, create `anrdms_transactions` and load the Portfolio 1 schema and seed data:

```bash
# Create dedicated database for transaction experiments
createdb anrdms_transactions

# Load schema DDL
psql -d anrdms_transactions -v ON_ERROR_STOP=1 -f portfolio-1-database-design/schema.sql

# Load synthetic seed dataset
psql -d anrdms_transactions -v ON_ERROR_STOP=1 -f portfolio-1-database-design/seed_data.sql
```

### Step 2: Execute Practical ACID Transactions
Run the transaction script using `psql`:

```bash
psql -d anrdms_transactions -f portfolio-3-transactions-concurrency/transactions.sql
```

*Expected output:* Confirms successful multi-table insert, rolls back constraint violation, demonstrates savepoint recovery, and prints internal tuple headers (`xmin`, `xmax`, `ctid`) and WAL flush positions.

### Step 3: Execute Portable Concurrency Test Suite
Run the automated test runner, which discovers `psql` from `PATH`, connects to `anrdms_transactions` (configurable via `PGDATABASE`), spawns two synchronized interactive subprocesses, and asserts all expected database outcomes:

```bash
python3 portfolio-3-transactions-concurrency/run_concurrency_tests.py
```

*Expected output:* Runs all 4 concurrency experiments, outputs chronological timestamps, asserts row counts, and verifies lock acquisition, non-repeatable read, SSI abort (40001), and deadlock resolution (40P01).

### Step 4: Manual Step-by-Step Reproduction (Dual Terminal)
If you wish to test the concurrency experiments manually in two terminals:
1. Open **Terminal 1**: `psql -d anrdms_transactions` (Session 1)
2. Open **Terminal 2**: `psql -d anrdms_transactions` (Session 2)
3. Follow the numbered steps in [`concurrency_tests.sql`](./concurrency_tests.sql).

---

## 5. Navigation

- ⬅️ **Previous:** [Portfolio 2 – Query Processing & Optimisation](../portfolio-2-query-optimisation/README.md)
- ➡️ **Next:** [Portfolio 4 – NoSQL & Advanced Data Models](../portfolio-4-nosql/README.md)
- 🏠 **Repository Root:** [Master ANRDMS Documentation](../README.md)
