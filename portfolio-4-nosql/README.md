# Portfolio 4: NoSQL and Advanced Data Models (7 Marks)

**Course:** MIT 8103 – Advanced Database Systems  
**Institution:** Miva Open University  
**Student:** Patrick Filima  
**System:** African Neuroimaging Research Data Management System (ANRDMS)  
**Weighting:** 7 Marks  

---

## 1. Overview and Assessment Alignment

Portfolio 4 addresses the practical and theoretical challenges of managing high-dimensional, heterogeneous, and polymorphous neuroimaging data that exceed the capabilities of traditional relational schemas.

While Portfolios 1, 2, and 3 established a 3NF relational schema, query optimization benchmarks, and ACID concurrency control in PostgreSQL, Portfolio 4 implements a **Document-Oriented NoSQL Data Model** and a **Polyglot Persistence Architecture** for BIDS (Brain Imaging Data Structure) acquisition metadata and complex computational pipeline metrics (FreeSurfer and FSL TBSS).

### Key Learning Outcomes Demonstrated:
1. **Relational vs. Document Impedance Mismatch:** In-depth critique of why strict tabular normalization leads to sparse table bloat or the Entity-Attribute-Value (EAV) anti-pattern when managing multi-modal MRI sequences (T1w, dMRI, fMRI, FLAIR).
2. **BIDS-Compliant Document Design:** Authoring rich, hierarchical JSON/BSON document collections with native arrays for diffusion gradient tables (`b_values: [0, 1000, 2000]`) and fMRI slice timing.
3. **Document Schema Governance:** Implementing database-level schema validation using MongoDB `$jsonSchema` to enforce required clinical headers, identifier patterns, and physical scanner field bounds.
4. **Advanced Multi-Stage Aggregation Pipelines:** Executing analytical pipelines using `$match`, `$unwind`, `$group`, `$project`, and `$facet` to measure subcortical atrophy and cortical thinning in Alzheimer's disease cohorts.
5. **Polyglot Persistence & Hybrid PostgreSQL JSONB:** Bridging relational integrity and document flexibility via PostgreSQL `JSONB` columns with Generalized Inverted Indexes (`USING gin (metadata jsonb_path_ops)`).
6. **Distributed Database Theory:** Evaluating CAP and PACELC theorem trade-offs across distributed hospital nodes in Nigeria.

---

## 2. Directory Layout and Deliverables

```
portfolio-4-nosql/
├── README.md                      # Consolidated portfolio overview and reproduction instructions
├── nosql_modeling.md              # Comprehensive academic report and comparative theoretical analysis
├── documents/
│   ├── scans_bids.json            # BIDS-compliant neuroimaging scan metadata documents
│   └── pipeline_metrics.json      # Hierarchical FreeSurfer morphometry and FSL TBSS tract statistics
├── scripts/
│   ├── mongodb_queries.js         # MongoDB shell script ($jsonSchema, indexes, and aggregation pipelines)
│   ├── hybrid_jsonb.sql           # PostgreSQL hybrid relational + JSONB schema with GIN indexing
│   └── nosql_runner.py            # Portable Python test harness executing the full pipeline suite
└── evidence/
    ├── nosql_query_outputs.txt    # Verified execution log of the 5 document aggregation pipelines
    └── jsonb_hybrid_outputs.txt   # Raw PostgreSQL execution transcript and GIN index query plans
```

### Direct Document Links
- 📄 [Comprehensive NoSQL Modeling & Architecture Report](./nosql_modeling.md)
- 📂 [BIDS Scan Documents Dataset (JSON)](./documents/scans_bids.json)
- 📂 [Pipeline Metrics Dataset (JSON)](./documents/pipeline_metrics.json)
- 📜 [MongoDB Aggregation Script (JS)](./scripts/mongodb_queries.js)
- 📜 [PostgreSQL Hybrid JSONB Script (SQL)](./scripts/hybrid_jsonb.sql)
- 🐍 [Portable NoSQL Verification Runner (Python)](./scripts/nosql_runner.py)
- 📋 [Verified Document Aggregation Output](./evidence/nosql_query_outputs.txt)
- 📋 [Raw PostgreSQL JSONB Execution Evidence](./evidence/jsonb_hybrid_outputs.txt)

---

## 3. Summary of Document Pipelines & Verified Results

| Pipeline / Experiment | Architectural Focus | Equivalent Engine Operators | Key Recorded Result / Insight |
| :--- | :--- | :--- | :--- |
| **Stage 1: Validation** | Document Governance | MongoDB `$jsonSchema` | **8/8 scan documents verified** satisfying primary key, BIDS hierarchy, and field bounds. |
| **Pipeline 1** | Subcortical Volumetry | `$match` $\to$ `$group` $\to$ `$project` $\to$ `$sort` | **Hippocampal Atrophy:** Alzheimer's bilateral volume is 6,330.5 mm³ vs 9,030.0 mm³ in Controls (-29.9%). |
| **Pipeline 2** | Cortical Thinning | `$unwind: "$cortical_parcellations"` $\to$ `$group` | **Entorhinal Thinning:** Alzheimer's mean thickness is 2.665 mm vs 3.565 mm in Controls (-25.2%). |
| **Pipeline 3** | High-Dimensional Arrays | `$match` on nested array and scanner hardware | Filtered multi-shell 3.0T dMRI with $b=2000\text{ s/mm}^2$ and 64 directions without junction tables. |
| **Pipeline 4** | Dual-Branch Analytics | `$facet` (HPC metrics + Mesh Quality) | Single-pass dashboard: FreeSurfer averaged 7.45h runtime / 11.62 GB RAM; Euler defects captured. |
| **Hybrid JSONB (SQL)** | Polyglot RDBMS Bridge | `@>` (containment), `LATERAL jsonb_array_elements` | GIN index accelerated containment lookups; array unnesting executed in **0.34 ms**. |

---

## 4. Instructions for Reproduction

### Step 1: Execute the Portable NoSQL Pipeline Suite (Python)
To verify all 5 aggregation pipelines and schema validation rules without requiring external server installations:

```bash
# From repository root:
python3 portfolio-4-nosql/scripts/nosql_runner.py
```

*Expected output:* Confirms $jsonSchema compliance, outputs formatted tabular summaries for subcortical volumetry, regional cortical thickness ($unwind), high-dimensional dMRI matching, and the $facet analytics dashboard, writing the output log to `evidence/nosql_query_outputs.txt`.

### Step 2: Execute the Hybrid PostgreSQL JSONB Script
To run the polyglot persistence bridge against the PostgreSQL database:

```bash
# Run against the isolated transactions/testing database:
psql -d anrdms_transactions -f portfolio-4-nosql/scripts/hybrid_jsonb.sql
```

*Expected output:* Creates `scans_bids_jsonb` and `pipeline_metrics_jsonb`, builds GIN indexes (`jsonb_path_ops`), inserts documents, runs `EXPLAIN (ANALYZE, BUFFERS)` for JSON containment queries, and performs lateral array unnesting.

### Step 3: Optional Execution in MongoDB Shell (`mongosh`)
If you have MongoDB installed locally or access to a MongoDB Atlas cluster:

```bash
# Connect and execute the schema validator, indexes, and aggregation queries:
mongosh anrdms_nosql portfolio-4-nosql/scripts/mongodb_queries.js
```

---

## 5. Navigation

- ⬅️ **Previous:** [Portfolio 3 – Transactions & Concurrency](../portfolio-3-transactions-concurrency/README.md)
- ➡️ **Next:** [Portfolio 5 – Distributed & Cloud Database Exercise](../portfolio-5-distributed-cloud/README.md)
- 🏠 **Repository Root:** [Master ANRDMS Documentation](../README.md)
