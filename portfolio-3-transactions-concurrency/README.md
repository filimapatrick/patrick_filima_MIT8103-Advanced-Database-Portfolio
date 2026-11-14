# Portfolio 3: Transactions and Concurrency (7 Marks)

**Course:** MIT 8103 – Advanced Database Systems  
**Institution:** Miva Open University  
**Student:** Patrick Filima  
**System:** African Neuroimaging Research Data Management System (ANRDMS)  
**Database Engine:** PostgreSQL 16.16 (Homebrew, Apple Silicon macOS)  

---

## 1. Overview and Assessment Alignment

Portfolio 3 focuses on the practical implementation, empirical verification, and theoretical analysis of **Transaction Processing and Concurrency Control** for the African Neuroimaging Research Data Management System (ANRDMS).

While Portfolios 1 and 2 established the relational architecture and query optimization baseline for multi-site neuroimaging across Nigeria (LUTH, NHA, UCH, UNTH, ABUTH), Portfolio 3 evaluates how the database engine guarantees data integrity and high availability under concurrent clinical and computational workloads.

### Key Learning Outcomes Demonstrated:
1. **Practical ACID Properties:** Multi-table transactions preserving clinical invariants, constraint-enforced rollbacks eliminating orphan records, and hierarchical fault recovery via `SAVEPOINT`.
2. **PostgreSQL MVCC Internals:** Inspection of internal tuple headers (`xmin`, `xmax`, `ctid`), demonstrating physical non-overwriting storage, version chaining, and Write-Ahead Logging (WAL).
3. **ANSI Isolation Levels & Concurrency Phenomena:** Live empirical reproduction of Non-Repeatable Reads under `READ COMMITTED`, snapshot preservation under `REPEATABLE READ`, and Serializable Snapshot Isolation (SSI) detecting Write Skew under `SERIALIZABLE` (SQLSTATE `40001`).
4. **Pessimistic Concurrency & High-Throughput Queueing:** Eliminating race conditions and lost updates on HPC pipeline workers using `SELECT ... FOR UPDATE` and contention-free `FOR UPDATE SKIP LOCKED`.
5. **Deadlock Detection and Resolution:** Interleaved cross-table updates generating wait-for graph cycles, engine cycle resolution via `deadlock_timeout` (SQLSTATE `40P01`), and application retry patterns.

---

## 2. Directory Layout and Deliverables

```
portfolio-3-transactions-concurrency/
├── README.md                      # Consolidated portfolio overview and reproduction instructions
├── transactions.sql               # Practical ACID transaction scripts (Commit, Rollback, Savepoint, MVCC)
├── concurrency_tests.sql          # Dual-session interactive SQL concurrency experiments
├── run_concurrency_tests.py       # Automated Python test harness driving parallel interactive sessions
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
| **Transaction 1** | Atomicity & Consistency | Multi-table atomic commit spanning `participants`, `diagnoses`, `scans`, and `qc`. | **Committed in 8.67 ms**. All 4 entities materialized simultaneously. |
| **Transaction 2** | Integrity Rollback | Scan insertion with negative TR (`-2300 ms`) violates check constraint `ck_scans_tr`. | Aborted with constraint error; **0 orphan records** remained post-rollback. |
| **Transaction 3** | Savepoints (`SAVEPOINT`) | Invalid HPC job status fails; `ROLLBACK TO SAVEPOINT` recovers without losing scan. | Scan and participant preserved; valid fallback job committed cleanly. |
| **Transaction 4** | MVCC Tuple Inspection | Update on `handedness` creates new physical tuple version; `ctid` shifts from `(0,26)` to `(0,29)`. | Verified non-overwriting storage; WAL flushed at LSN `0/EB43B38`. |
| **Experiment 1A** | Lost Update Prevention | Concurrent workers claim Job 101; Worker 2 blocks on `SELECT ... FOR UPDATE`. | Worker 2 held until Worker 1 commits; zero duplicate job dispatches. |
| **Experiment 1B** | Non-Blocking Queue | Both workers execute `SELECT ... FOR UPDATE SKIP LOCKED` on pending jobs. | **Zero wait time**. Worker 2 skipped locked Job 101 and claimed Job 102. |
| **Experiment 2A** | `READ COMMITTED` | Query 1 counts 2 running jobs; concurrent session completes Job 101. Query 2 counts 1. | **Non-Repeatable Read observed** due to statement-level snapshot re-acquisition. |
| **Experiment 2B** | `REPEATABLE READ` | Query 1 counts 1 running job; concurrent session completes Job 102. Query 2 counts 1. | **Consistency preserved**. Transaction-level snapshot ignored concurrent commit. |
| **Experiment 2C** | `SERIALIZABLE` | Both sessions attempt to take the last operational scanner offline (Write Skew). | SSI detected rw-antidependency; aborted Session 2 with **SQLSTATE 40001**. |
| **Experiment 3** | Deadlock Resolution | Circular dependency: Session 1 locks scan, requests QC; Session 2 locks QC, requests scan. | Engine triggered at `deadlock_timeout = 1s`; aborted Session 1 with **SQLSTATE 40P01**. |

---

## 4. Instructions for Reproduction

### Prerequisites
- PostgreSQL 14+ installed and running locally.
- Target database: `anrdms` populated with the Portfolio 1 schema and seed dataset.
- Python 3.8+ (for automated concurrency test runner).

### Step 1: Execute Practical ACID Transactions
Run the automated script using `psql`:

```bash
# From the repository root:
psql -d anrdms -f portfolio-3-transactions-concurrency/transactions.sql
```

*Expected output:* Confirms successful multi-table insert, rolls back constraint violation, demonstrates savepoint recovery, and prints internal tuple headers (`xmin`, `xmax`, `ctid`).

### Step 2: Execute Parallel Concurrency Test Suite
You can execute the automated test harness which spawns two synchronized `psql` interactive subprocesses:

```bash
python3 portfolio-3-transactions-concurrency/run_concurrency_tests.py
```

*Expected output:* Prints the interactive timeline of both sessions, demonstrating row lock blocking, non-repeatable reads, serializable write-skew abortion, and the 1-second deadlock timeout detection.

### Step 3: Manual Step-by-Step Reproduction (Dual Terminal)
If you wish to test the concurrency experiments manually in two terminals:
1. Open **Terminal 1**: `psql -d anrdms` (Session 1)
2. Open **Terminal 2**: `psql -d anrdms` (Session 2)
3. Follow the numbered steps in [`concurrency_tests.sql`](./concurrency_tests.sql).

---

## 5. Navigation

- ⬅️ **Previous:** [Portfolio 2 – Query Processing & Optimisation](../portfolio-2-query-optimisation/README.md)
- ➡️ **Next:** [Portfolio 4 – NoSQL & Advanced Data Models](../portfolio-4-nosql/README.md)
- 🏠 **Repository Root:** [Master ANRDMS Documentation](../README.md)
