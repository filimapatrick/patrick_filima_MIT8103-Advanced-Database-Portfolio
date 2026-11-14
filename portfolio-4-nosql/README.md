# Portfolio 4: NoSQL and Advanced Data Models (7 Marks)

**Course:** MIT 8103 – Advanced Database Systems  
**Institution:** Miva Open University  
**Student:** Patrick Filima  
**System:** African Neuroimaging Research Data Management System (ANRDMS)  
**Weighting:** 7 Marks  

---

## 1. Overview and Assessment Alignment

Portfolio 4 addresses the practical and theoretical challenges of managing high-dimensional, heterogeneous, and polymorphous neuroimaging data that exceed the capabilities of traditional relational schemas.

While Portfolios 1, 2, and 3 established a 3NF relational schema, query optimization benchmarks, and ACID concurrency control in PostgreSQL, Portfolio 4 implements a **Document-Oriented NoSQL Data Model** and a **Polyglot Persistence Architecture** for BIDS-inspired (Brain Imaging Data Structure) acquisition metadata and complex computational pipeline metrics (FreeSurfer and FSL TBSS).

### Key Learning Outcomes Demonstrated:
1. **Relational vs. Document Impedance Mismatch:** In-depth critique of why strict tabular normalization leads to sparse table bloat or the Entity-Attribute-Value (EAV) anti-pattern when managing multi-modal MRI sequences (T1w, dMRI, fMRI, FLAIR).
2. **BIDS-Inspired Document Design:** Authoring rich, hierarchical JSON/BSON document collections with native arrays for diffusion gradient tables (`b_values: [0, 1000, 2000]`) and fMRI slice timing.
3. **Document Schema Governance:** Implementing database-level schema validation using MongoDB `$jsonSchema` to enforce required clinical headers, identifier patterns, and physical scanner field bounds, validated via live negative rejection tests (Error codes 121 and 11000).
4. **Multikey Indexing & Execution Plan Verification:** Implementing multikey indexes over array elements (`diffusion_protocol.b_values`) and verifying `IXSCAN` index usage via `explain("executionStats")`.
5. **Advanced Multi-Stage Aggregation Pipelines:** Executing analytical pipelines using `$match`, `$unwind`, `$group`, `$project`, and `$facet` to measure subcortical volumetry and cortical thinning in synthetic demo profiles.
6. **Polyglot Persistence & Hybrid PostgreSQL JSONB:** Bridging relational integrity and document flexibility via PostgreSQL `JSONB` columns with foreign keys linking to the relational backbone (`participants` and `research_sites`) and Generalized Inverted Indexes (`USING gin (metadata jsonb_path_ops)`).
7. **Distributed Database Theory:** Evaluating CAP and PACELC theorem trade-offs across distributed hospital nodes in Nigeria.

---

## 2. Directory Layout and Deliverables

```
portfolio-4-nosql/
├── README.md                      # Consolidated portfolio overview and reproduction instructions
├── nosql_modeling.md              # Comprehensive academic report and comparative theoretical analysis
├── documents/
│   ├── scans_bids.json            # BIDS-inspired neuroimaging scan metadata documents (8 documents)
│   └── pipeline_metrics.json      # Hierarchical FreeSurfer morphometry and FSL TBSS tract statistics (4 documents)
├── scripts/
│   ├── mongodb_queries.js         # Canonical MongoDB script ($jsonSchema, indexes, tests, aggregations)
│   ├── run_mongo.js               # Automated Node.js runner executing queries live against MongoDB 7.0 engine
│   ├── hybrid_jsonb.sql           # PostgreSQL hybrid relational + JSONB schema with GIN indexing
│   └── nosql_runner.py            # Portable Python test harness executing the full pipeline suite
└── evidence/
    ├── mongodb_live_outputs.txt   # Live transcript from running MongoDB 7.0 server daemon
    ├── jsonb_hybrid_outputs.txt   # Raw PostgreSQL 16 execution transcript and query plan comparisons
    └── nosql_query_outputs.txt    # Verified execution log of the Python document aggregation suite
```

### Direct Document Links
- 📄 [Comprehensive NoSQL Modeling & Architecture Report](./nosql_modeling.md)
- 📂 [BIDS Scan Documents Dataset (JSON)](./documents/scans_bids.json)
- 📂 [Pipeline Metrics Dataset (JSON)](./documents/pipeline_metrics.json)
- 📜 [Canonical MongoDB Shell Script (JS)](./scripts/mongodb_queries.js)
- 📜 [Live MongoDB Node.js Execution Runner (JS)](./scripts/run_mongo.js)
- 📜 [PostgreSQL Hybrid JSONB Script (SQL)](./scripts/hybrid_jsonb.sql)
- 🐍 [Portable NoSQL Verification Runner (Python)](./scripts/nosql_runner.py)
- 📋 [Live MongoDB 7.0 Server Execution Evidence](./evidence/mongodb_live_outputs.txt)
- 📋 [Raw PostgreSQL JSONB Execution Evidence](./evidence/jsonb_hybrid_outputs.txt)
- 📋 [Verified Document Aggregation Output (Python)](./evidence/nosql_query_outputs.txt)

---

## 3. Summary of Document Pipelines & Verified Results

| Pipeline / Experiment | Architectural Focus | Equivalent Engine Operators | Key Recorded Result / Insight |
| :--- | :--- | :--- | :--- |
| **Stage 1: Validation** | Document Governance | MongoDB `$jsonSchema` | **Verified 8/8 scans** satisfy schema rules. Live negative tests trapped range error (20.0T $\to$ Code 121) and duplicate key (`scan_id` $\to$ Code 11000). |
| **Multikey Index Plan** | Array Indexing Performance | `explain("executionStats")` | `IXSCAN` on `idx_scans_dmri_bvalues_multikey` with `isMultiKey: true` examined exactly 1 key and 1 doc in 1 ms without collection scan. |
| **Pipeline 1** | Subcortical Volumetry | `$match` $\to$ `$group` $\to$ `$project` $\to$ `$sort` | **Illustrative Demo Results:** Alzheimer's synthetic demo bilateral hippocampal volume is 6,330.5 mm³ vs 9,030.0 mm³ in Controls with enlarged ventricles (58,400 mm³). |
| **Pipeline 2** | Cortical Thinning | `$unwind: "$cortical_parcellations"` $\to$ `$group` | **Illustrative Demo Results:** Entorhinal demo thickness is 2.665 mm vs 3.565 mm in Controls, demonstrating array deconstruction. |
| **Pipeline 3** | High-Dimensional Arrays | `$match` on nested array and scanner hardware | Filtered multi-shell 3.0T dMRI with $b=2000\text{ s/mm}^2$ and 64 directions natively without relational junction tables. |
| **Pipeline 4** | Dual-Branch Analytics | `$facet` (HPC metrics + Mesh Quality) | Single-pass dashboard: FreeSurfer averaged 7.45h runtime / 11.62 GiB peak RAM. Euler numbers ($\chi = -8, -10$) captured as surface reconstruction QA metrics. |
| **Hybrid JSONB (SQL)** | Polyglot RDBMS Bridge | `@>` (containment), `LATERAL jsonb_array_elements` | Relational FKs link to `participants` & `research_sites`. Cost-based optimizer chose Seq Scan for 4 rows (cost 1.05); forced index scan verified GIN index (`shared hit=5`). |

---

## 4. Instructions for Reproduction

### Step 1: Run Live MongoDB Suite (Node.js / Live Server)
The portfolio includes an automated runner that connects directly to the local MongoDB server on port 27017:

```bash
# Execute against live local MongoDB daemon and verify outputs:
node portfolio-4-nosql/scripts/run_mongo.js
```

Or execute via the standard MongoDB shell (`mongosh`):
```bash
mongosh "mongodb://localhost:27017/anrdms_nosql" --file portfolio-4-nosql/scripts/mongodb_queries.js
```

*Expected output:* Confirms MongoDB connection, builds `$jsonSchema` validators, creates 6 indexes, imports all JSON documents, executes both negative validation tests, captures the multikey execution plan, and prints all 4 aggregation results (matching [`evidence/mongodb_live_outputs.txt`](./evidence/mongodb_live_outputs.txt)).

### Step 2: Execute the Hybrid PostgreSQL JSONB Script
To run the polyglot persistence bridge against the PostgreSQL database:

```bash
# Run against the anrdms database:
psql -d anrdms -f portfolio-4-nosql/scripts/hybrid_jsonb.sql
```

*Expected output:* Creates `scans_bids_jsonb` (with foreign keys to `participants` and `research_sites`) and `pipeline_metrics_jsonb`, builds GIN indexes (`jsonb_path_ops`), inserts documents, runs `EXPLAIN (ANALYZE, BUFFERS)` showing both default optimizer Seq Scan and forced GIN index plan, and executes lateral array unnesting (matching [`evidence/jsonb_hybrid_outputs.txt`](./evidence/jsonb_hybrid_outputs.txt)).

### Step 3: Run the Portable Python Pipeline Suite
To verify the aggregation pipeline mathematical transformations independently without database dependencies:

```bash
# From repository root:
python3 portfolio-4-nosql/scripts/nosql_runner.py
```

*Expected output:* Validates document keys, outputs formatted tables for hippocampal volumetry, cortical thinning, multi-shell dMRI matching, and dual-facet HPC/quality metrics, writing to [`evidence/nosql_query_outputs.txt`](./evidence/nosql_query_outputs.txt).

---

## 5. Navigation

- ⬅️ **Previous:** [Portfolio 3 – Transactions & Concurrency](../portfolio-3-transactions-concurrency/README.md)
- ➡️ **Next:** [Portfolio 5 – Distributed & Cloud Database Exercise](../portfolio-5-distributed-cloud/README.md)
- 🏠 **Repository Root:** [Master ANRDMS Documentation](../README.md)
