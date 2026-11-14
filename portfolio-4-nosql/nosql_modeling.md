# Portfolio 4: NoSQL and Advanced Data Models

**Course:** MIT 8103 – Advanced Database Systems  
**Institution:** Miva Open University  
**Student:** Patrick Filima  
**System:** African Neuroimaging Research Data Management System (ANRDMS)  
**Weighting:** 7 Marks  

---

## 1. Executive Summary

While Portfolios 1, 2, and 3 successfully designed, optimized, and verified a relational database architecture in PostgreSQL for the African Neuroimaging Research Data Management System (ANRDMS), real-world neuroinformatics systems encounter data structures that severely strain the relational model. 

Neuroimaging research generates high-dimensional, heterogeneous, and polymorphous data governed by the international **Brain Imaging Data Structure (BIDS)** standard. A 3.0T structural scan (T1w), a multi-shell diffusion tensor scan (dMRI), and a functional MRI scan (fMRI) possess radically different acquisition parameters, gradient vectors, and slice-timing arrays. Furthermore, downstream computational pipelines—such as FreeSurfer, FSL TBSS, and QSIPrep—generate deeply nested, hierarchical morphometric and tractographic statistics that vary by pipeline version and modality.

In this portfolio, we examine the limits of relational normalization, design a document-oriented NoSQL model in MongoDB, implement schema validation via `$jsonSchema`, construct advanced multi-stage aggregation pipelines, and demonstrate a **Polyglot Persistence** architecture that bridges relational integrity with document flexibility using PostgreSQL's native `JSONB` and Generalized Inverted Indexes (GIN).

---

## 2. The Relational vs. Document Impedance Mismatch in Neuroinformatics

### 2.1 The Limits of 3NF Relational Schemas in BIDS Imaging

In a purely relational database (3NF/BCNF), every tuple in a relation must adhere to a fixed, predefined set of attributes. In clinical neuroimaging, however, pulse sequence parameters differ fundamentally by imaging sequence and scanner vendor:

```
+---------------------------------------------------------------------------------------------------------+
|                                  THE RELATIONAL SCHEMA CHALLENGE                                        |
|                                                                                                         |
|  [T1w Structural]      --> TR, TE, Inversion Time (TI), Flip Angle, Matrix Read/Phase                   |
|  [dMRI Diffusion]       --> b-values array, 64-dir Gradient Vectors, Phase Encoding, Echo Spacing        |
|  [fMRI Functional]      --> Task Name, 240 Volumes, Slice Timing Array (36 slices), Triggers            |
|  [Siemens Skyra 3.0T]   --> TotalReadoutTime, MultibandFactor, CoilElementSelect                        |
|  [GE Signa 3.0T]        --> AssetRFactor, ReceiveCoilName, EchoTrainLength                              |
+---------------------------------------------------------------------------------------------------------+
```

Attempting to model this diversity in a traditional relational database forces database architects into three suboptimal anti-patterns:

1. **The Sparse Wide Table Anti-Pattern:**  
   Adding all possible vendor and sequence attributes to `mri_scans` results in a table with 150+ columns where 85–90% of the cells are `NULL`. This wastes physical disk storage, increases page buffer churn, and invalidates statistical distribution estimators.
2. **The Entity-Attribute-Value (EAV) Anti-Pattern:**  
   Creating a generic relational table `scan_attributes(scan_id, attribute_name, attribute_value)` destroys database type safety (everything becomes `VARCHAR`), loses foreign key enforcement, and requires 10 to 15 expensive self-joins just to reconstruct a single scan's header metadata.
3. **Over-Normalization (Class Hierarchies):**  
   Splitting the schema into `t1_scans`, `dmri_scans`, `fmri_scans`, `siemens_params`, and `ge_params` introduces high schema complexity, breaks polymorphic queries, and requires constant DDL alterations whenever new neuroimaging sequences are deployed in research protocols.

### 2.2 The Document Model Solution

Document-oriented NoSQL databases (e.g. MongoDB BSON) resolve this impedance mismatch by treating the document as the basic unit of storage:
- **Hierarchical Nesting:** Scanner hardware, pulse sequence parameters, and clinical profiles are embedded naturally within subdocuments.
- **First-Class Arrays:** Multi-shell diffusion gradient values (`b_values: [0, 1000, 2000]`) and fMRI slice acquisition timings (`slice_timing: [0.0, 68.9, 137.9, ...]`) are stored natively rather than requiring junction tables.
- **Polymorphism:** A T1w document and a dMRI document live in the same `scans_bids` collection, sharing common clinical headers while freely storing modality-specific parameters.

---

## 3. NoSQL Document Model Design & Schema Governance

### 3.1 Document Schemas

We designed two complementary NoSQL collections in [`documents/scans_bids.json`](./documents/scans_bids.json) and [`documents/pipeline_metrics.json`](./documents/pipeline_metrics.json):

#### Collection 1: `scans_bids` (BIDS Acquisition Metadata)
```json
{
  "scan_id": "SCN-LOS-001-DM",
  "participant_id": "ANRDMS-LOS-001",
  "site_id": "SITE-LOS-01",
  "modality": "MRI",
  "sequence_type": "dMRI",
  "acquisition_date": "2025-01-15T09:15:00Z",
  "scanner_hardware": {
    "vendor": "Siemens Healthineers",
    "model": "Magnetom Skyra",
    "magnetic_field_tesla": 3.0,
    "receive_coil": "32-Channel Head Matrix"
  },
  "diffusion_protocol": {
    "b_values": [0, 1000, 2000],
    "gradient_directions_count": 64,
    "shells": [
      { "bval": 0, "volumes_count": 6 },
      { "bval": 1000, "volumes_count": 32 },
      { "bval": 2000, "volumes_count": 32 }
    ]
  },
  "clinical_profile": {
    "diagnosis_category": "Cerebrovascular",
    "condition_name": "Acute ischemic stroke",
    "severity": "Moderate"
  }
}
```

#### Collection 2: `pipeline_metrics` (Hierarchical Computational Outputs)
Stores FreeSurfer cortical morphometry (subcortical structures, Desikan-Killiany parcellations, Euler numbers) and FSL TBSS fractional anisotropy statistics without tabular decomposition.

```json
{
  "metric_id": "MET-FS-ABJ-001",
  "scan_id": "SCN-ABJ-001-T1",
  "participant_id": "ANRDMS-ABJ-001",
  "pipeline_info": { "pipeline_name": "FreeSurfer", "version": "7.4.1" },
  "subcortical_structures": {
    "left_hippocampus_mm3": 3120.4,
    "right_hippocampus_mm3": 3210.1,
    "ventricular_system_volume_mm3": 58400.0
  },
  "cortical_parcellations": [
    { "region_name": "superiorfrontal", "hemisphere": "lh", "mean_thickness_mm": 2.38 },
    { "region_name": "entorhinal", "hemisphere": "lh", "mean_thickness_mm": 2.65 }
  ],
  "quality_metrics": { "euler_number_lh": -8, "euler_number_rh": -10, "contrast_to_noise_ratio": 7.15 },
  "clinical_cohort": { "diagnosis_category": "Neurodegenerative", "condition_name": "Early-onset Alzheimer's dementia" }
}
```

### 3.2 Schema Governance with MongoDB `$jsonSchema`

Contrary to common misconception, production NoSQL databases are **schema-flexible**, not "schema-less". In [`scripts/mongodb_queries.js`](./scripts/mongodb_queries.js) and [`scripts/run_mongo.js`](./scripts/run_mongo.js), we implement strict database-level validation using JSON Schema:

```javascript
db.createCollection("scans_bids", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["scan_id", "participant_id", "site_id", "modality", "sequence_type", "bids_metadata", "scanner_hardware"],
      properties: {
        scan_id: { bsonType: "string", pattern: "^SCN-[A-Z]{3}-[0-9]{3}-[A-Z0-9]+$" },
        participant_id: { bsonType: "string", pattern: "^ANRDMS-[A-Z]{3}-[0-9]{3}$" },
        sequence_type: { enum: ["T1w", "T2w", "FLAIR", "dMRI", "fMRI-rest", "fMRI-task", "MRA"] },
        scanner_hardware: {
          bsonType: "object",
          required: ["vendor", "model", "magnetic_field_tesla"],
          properties: {
            magnetic_field_tesla: { bsonType: ["double", "int", "decimal"], minimum: 0.2, maximum: 7.5 }
          }
        }
      }
    }
  }
});
```

#### Negative Validation Tests (Live Database Governance)
To prove that MongoDB enforces these rules at the database engine level rather than relying solely on client-side application logic, we executed two explicit negative validation tests against the live engine (recorded in [`evidence/mongodb_live_outputs.txt`](./evidence/mongodb_live_outputs.txt)):

1. **Negative Test 1: $jsonSchema Field Range Violation (Static Magnetic Field > 7.5T)**  
   - *Attempt:* Inserting an unphysical 20.0 Tesla scanner (`magnetic_field_tesla: 20.0`).  
   - *Engine Response:* Trapped by MongoDB server validator and rejected with `MongoServerError: Document failed validation` (Error Code: **121**). No invalid document was persisted.
2. **Negative Test 2: Primary Key Unique Constraint Violation (`scan_id`)**  
   - *Attempt:* Inserting a duplicate document with existing key `SCN-LOS-001-T1`.  
   - *Engine Response:* Trapped by unique index `idx_scans_scan_id_unique` and rejected with `MongoServerError: E11000 duplicate key error` (Error Code: **11000**).

---

## 4. Advanced NoSQL Indexing Strategies

In document databases, secondary indexes must index into nested subdocuments and arrays:

1. **Unique Primary Index:**  
   `db.scans_bids.createIndex({ "scan_id": 1 }, { unique: true, name: "idx_scans_scan_id_unique" })` ensures global uniqueness of BIDS scan identifiers.
2. **Compound Multi-Site Index:**  
   `db.scans_bids.createIndex({ "site_id": 1, "sequence_type": 1, "acquisition_date": -1 }, { name: "idx_scans_site_seq_date" })` optimizes multi-site cohort discovery.
3. **Multikey Array Index (Diffusion b-values):**  
   `db.scans_bids.createIndex({ "diffusion_protocol.b_values": 1 }, { name: "idx_scans_dmri_bvalues_multikey" })` indexes individual numbers inside the array. A query matching `b_values: 2000` utilizes a multikey index scan (`IXSCAN`).
4. **Multikey Index on Subdocument Arrays:**  
   `db.pipeline_metrics.createIndex({ "cortical_parcellations.region_name": 1 }, { name: "idx_metrics_cortical_region_multikey" })` enables index lookups on individual anatomical regions inside the FreeSurfer parcellation array.
5. **Sparse Index:**  
   `db.pipeline_metrics.createIndex({ "execution_metrics.compute_node": 1 }, { sparse: true, name: "idx_metrics_compute_node_sparse" })` indexes compute node allocations only for documents where execution metrics exist, minimizing index memory footprint.

### Multikey Index Execution Plan Verification
We executed `explain("executionStats")` on the live MongoDB server for the array containment query `db.scans_bids.find({ "diffusion_protocol.b_values": 2000 })`. The recorded query planner output confirms:

```json
{
  "stage": "FETCH",
  "inputStage": {
    "stage": "IXSCAN",
    "indexName": "idx_scans_dmri_bvalues_multikey",
    "isMultiKey": true
  },
  "executionStats": {
    "executionSuccess": true,
    "nReturned": 1,
    "totalKeysExamined": 1,
    "totalDocsExamined": 1,
    "executionTimeMillis": 1
  }
}
```

*Architectural Significance:* The index flag `isMultiKey: true` confirms that MongoDB expanded each element of the `b_values` array (`[0, 1000, 2000]`) into distinct index leaf keys. The optimizer immediately accessed the target scan via an `IXSCAN` on `idx_scans_dmri_bvalues_multikey`, examining exactly 1 key and 1 document (`totalKeysExamined: 1`, `totalDocsExamined: 1`) in 1 ms without performing an expensive collection scan (`COLLSCAN`).

---

## 5. Multi-Stage Aggregation Pipelines Analysis

Using our test harness ([`scripts/nosql_runner.py`](./scripts/nosql_runner.py)), we executed four multi-stage aggregation pipelines. The verified outputs were captured in [`evidence/nosql_query_outputs.txt`](./evidence/nosql_query_outputs.txt).

### Pipeline 1: Subcortical Volumetric Atrophy across Cohorts (`$match` $\to$ `$group` $\to$ `$project` $\to$ `$sort`)
Computes mean bilateral hippocampal volume and ventricular expansion across diagnosis categories:

```javascript
db.pipeline_metrics.aggregate([
  { $match: { "subcortical_structures": { $exists: true } } },
  { $group: {
      _id: "$clinical_cohort.condition_name",
      avg_left_hippo: { $avg: "$subcortical_structures.left_hippocampus_mm3" },
      avg_right_hippo: { $avg: "$subcortical_structures.right_hippocampus_mm3" },
      avg_ventricles: { $avg: "$whole_brain_morphometry.ventricular_system_volume_mm3" }
  }},
  { $project: {
      condition: "$_id",
      bilateral_hippo_mm3: { $round: [{ $add: ["$avg_left_hippo", "$avg_right_hippo"] }, 1] },
      ventricles_mm3: { $round: ["$avg_ventricles", 1] }
  }},
  { $sort: { bilateral_hippo_mm3: 1 } }
]);
```

#### Empirical Results
| Clinical Condition | Left Hippo (mm³) | Right Hippo (mm³) | Total Bilateral Hippo | Ventricles (mm³) |
| :--- | :--- | :--- | :--- | :--- |
| **Early-onset Alzheimer's** | **3,120.4** | **3,210.1** | **6,330.5** | **58,400.0** |
| **Acute ischemic stroke** | 4,150.2 | 4,210.8 | 8,361.0 | 32,890.6 |
| **Healthy Control Benchmark**| 4,480.0 | 4,550.0 | 9,030.0 | 24,100.0 |

*Illustrative Synthetic Demonstration Results:* The Alzheimer's synthetic demonstration profile reflects marked bilateral hippocampal volume reduction ($6,330.5\text{ mm}^3$ vs $9,030.0\text{ mm}^3$ in Controls) with compensatory ventricular enlargement ($58,400\text{ mm}^3$ vs $24,100\text{ mm}^3$). These values illustrate multi-stage aggregation pipeline logic across synthetic demo documents, rather than population-level medical claims.

---

### Pipeline 2: Regional Cortical Thinning Analysis via `$unwind`
Unpacks the embedded `cortical_parcellations` array, isolates key Alzheimer's anatomical markers (`entorhinal` and `superiorfrontal` cortex), and computes localized cortical thickness:

```javascript
db.pipeline_metrics.aggregate([
  { $match: { "cortical_parcellations": { $exists: true } } },
  { $unwind: "$cortical_parcellations" },
  { $match: { "cortical_parcellations.region_name": { $in: ["entorhinal", "superiorfrontal"] } } },
  { $group: {
      _id: { region: "$cortical_parcellations.region_name", condition: "$clinical_cohort.condition_name" },
      mean_thickness_mm: { $avg: "$cortical_parcellations.mean_thickness_mm" },
      min_thickness_mm: { $min: "$cortical_parcellations.mean_thickness_mm" },
      max_thickness_mm: { $max: "$cortical_parcellations.mean_thickness_mm" }
  }}
]);
```

#### Empirical Results
| Anatomical Region | Clinical Condition | Hemispheres (N) | Mean Thickness (mm) | Range [Min – Max] |
| :--- | :--- | :--- | :--- | :--- |
| **entorhinal** | Early-onset Alzheimer's | 2 | **2.665** | [2.650 – 2.680] |
| **entorhinal** | Acute ischemic stroke | 2 | 3.435 | [3.420 – 3.450] |
| **entorhinal** | Healthy Control Benchmark | 2 | **3.565** | [3.550 – 3.580] |
| **superiorfrontal**| Early-onset Alzheimer's | 2 | 2.390 | [2.380 – 2.400] |
| **superiorfrontal**| Acute ischemic stroke | 2 | 2.770 | [2.760 – 2.780] |
| **superiorfrontal**| Healthy Control Benchmark | 2 | 2.835 | [2.820 – 2.850] |

*Illustrative Synthetic Demonstration Results:* Entorhinal cortex in the synthetic Alzheimer's demo document reflects localized cortical thinning ($2.665\text{ mm}$ vs $3.565\text{ mm}$ in Controls), successfully verifying the `$unwind` array deconstruction and grouping pipeline on nested parcellation structures.

---

### Pipeline 3: Hardware & High-Dimensional BIDS Acquisition Query
Filters multi-shell dMRI acquisitions with $b=2000\text{ s/mm}^2$ on $\ge 3.0\text{T}$ scanners:
- Matches scan `SCN-LOS-001-DM` acquired on a Siemens Skyra 3.0T system with 64 gradient directions and multi-shell array `[0, 1000, 2000]`.
- Demonstrates how document stores naturally query multi-shell arrays without requiring relational junction tables or string serialization.

---

### Pipeline 4: Multi-Stage `$facet` Analytics Dashboard
Generates an executive operational dashboard in a single pipeline pass using `$facet`:
- **Branch A (HPC Resource Consumption):** FreeSurfer jobs averaged 7.45 hours runtime and 11.62 GiB peak RAM; FSL TBSS averaged 3.94 hours runtime and 8.20 GiB peak RAM.
- **Branch B (Topological Surface Mesh Quality Metrics):** FreeSurfer Euler numbers ($\chi = 2 - 2g$) and defect counts. Crucially, Euler numbers serve as **mesh reconstruction topological quality metrics** rather than direct biological measurements of disease severity; a more negative Euler number ($\chi = -8, -10$; 9 surface holes repaired) indicates topological surface defects that required algorithmic patching during 3D cortical reconstruction.

---

## 6. Polyglot Persistence & Hybrid PostgreSQL JSONB Implementation

Rather than operating PostgreSQL and MongoDB in complete isolation, enterprise health informatics platforms frequently adopt a **Polyglot Persistence** pattern:

```mermaid
flowchart TD
    subgraph RDBMS ["PostgreSQL Relational Backbone (ACID & Constraints)"]
        P["participants (Demographics, Ethics)"]
        S["research_sites (Hospital Tiers)"]
    end

    subgraph HYBRID ["Polyglot Bridge: PostgreSQL JSONB (GIN Indexed)"]
        SB["scans_bids_jsonb (Relational Keys + BIDS JSONB Payload)"]
        PM["pipeline_metrics_jsonb (Relational FK + Hierarchical Metrics)"]
    end

    P -->|"FK: participant_id"| SB
    S -->|"FK: site_id"| SB
    SB -->|"FK: scan_id (CASCADE)"| PM
```

In [`scripts/hybrid_jsonb.sql`](./scripts/hybrid_jsonb.sql), we implemented this architecture in PostgreSQL 16:
1. `scans_bids_jsonb` anchors each scan to the core relational backbone using explicit foreign keys:
   - `participant_id REFERENCES participants(participant_id) ON UPDATE CASCADE ON DELETE RESTRICT`
   - `site_id REFERENCES research_sites(site_id) ON UPDATE CASCADE ON DELETE RESTRICT`
   - While storing dynamic BIDS acquisition parameters in a binary `JSONB` column.
2. `idx_scans_bids_metadata_gin` indexes the JSON payload using `USING gin (metadata jsonb_path_ops)`.
3. **Execution Plan Analysis & Cost-Based Optimizer Behavior:**  
   In [`evidence/jsonb_hybrid_outputs.txt`](./evidence/jsonb_hybrid_outputs.txt), we analyzed the execution plans for the JSON containment query (`metadata @> '{"scanner_hardware": {"vendor": "Siemens Healthineers", "magnetic_field_tesla": 3.0}}'`):
   - **Default Cost-Based Decision:** The PostgreSQL optimizer selected a `Seq Scan` (cost 0.00..1.05, actual time 0.004 ms) because the table contains only 4 demonstration records residing in a single 8 KB shared buffer page (`Heap Blocks: exact=1`, `shared hit=1`). Initializing the GIN index structure and constructing a bitmap carries a baseline cost of ~17.24, making sequential scanning the mathematically rational choice for small datasets.
   - **Forced Index Plan (`SET enable_seqscan = off`):** Disabling sequential scans forces PostgreSQL to utilize the GIN index, executing a `Bitmap Heap Scan` via `Bitmap Index Scan on idx_scans_bids_metadata_gin` (cost 17.24..22.61, actual time 0.013 ms, `shared hit=5` buffers). This confirms that the GIN index is fully functional and ready to accelerate lookups as data scales to production volumes.
4. Subcortical volumetry and cortical parcellation array unnesting were demonstrated using `LATERAL jsonb_array_elements()`, producing outputs identical to MongoDB's `$unwind` within 0.45 ms execution time.

---

## 7. Comparative Architecture: Relational vs. Document vs. Hybrid JSONB

| Architectural Dimension | Relational 3NF (PostgreSQL) | Document Store (MongoDB) | Hybrid RDBMS + JSONB (PostgreSQL) |
| :--- | :--- | :--- | :--- |
| **Data Structure** | Two-dimensional tabular relations | Hierarchical BSON trees | Relational columns + binary JSON |
| **Schema Governance** | Strict, compile-time DDL constraints | Flexible; governed by `$jsonSchema` | Strict on relational keys; flexible on JSONB |
| **Array Support** | Requires junction normalization tables | First-class native arrays | First-class `JSONB` arrays |
| **Query Mechanism** | Standard SQL, multi-table JOINs | Aggregation pipelines (`$match`, `$unwind`) | SQL + JSON operators (`@>`, `->>`, `LATERAL`) |
| **Indexing** | B-Tree, Hash, Partial indexes | B-Tree, Compound, Multikey indexes | B-Tree + GIN (`jsonb_path_ops`) |
| **ACID Support** | Full multi-table ACID transactions | Multi-document ACID within replica sets | Full ACID across relational and JSONB fields |
| **Best Used For** | Demographics, ethics, scanner hardware | Raw BIDS DICOM headers, FreeSurfer stats | Unified platforms balancing ACID & flexibility |

---

## 8. Distributed Architecture: CAP and PACELC Theorems

In multi-site deployments across Nigeria (LUTH, NHA, UCH, UNTH, ABUTH), network latency and intermittent WAN partitions must be factored into database selection:

```
+---------------------------------------------------------------------------------------------------------+
|                                        CAP & PACELC THEOREMS                                            |
|                                                                                                         |
|  * CAP Theorem (Brewer, 2000): In a network partition (P), choose Consistency (C) or Availability (A).  |
|  * PACELC (Abadi, 2012): If Partition (P), choose A or C; Else (E), choose Latency (L) or Consistency (C). |
|                                                                                                         |
|  PostgreSQL: PC/EC (Consistent under partition; prefers Consistency over Latency during normal states).   |
|  MongoDB:    Configurable (w: "majority" = PC/EC; w: 1 = PA/EL preferring lower write latency).           |
+---------------------------------------------------------------------------------------------------------+
```

1. **Relational Backbone (PostgreSQL):** Configured as a **CP/PC** system. In the event of a network disruption between Lagos and Abuja, the system rejects divergent writes to patient demographics or consent records to avoid clinical split-brain corruption.
2. **Imaging Metadata (MongoDB):** Can be configured with `w: "majority"` for critical radiological evaluations, or tuned to `w: 1` on local hospital edge clusters to allow fast local BIDS scan ingestion during WAN outages, synchronizing asynchronously when network connectivity is restored.

---

## 9. Conclusion

Portfolio 4 demonstrates that relational and NoSQL databases are complementary rather than mutually exclusive. By pairing PostgreSQL's transactional guarantees for core research demographics with MongoDB and PostgreSQL `JSONB` for polymorphous BIDS metadata and hierarchical pipeline results, the African Neuroimaging Research Data Management System achieves both strict clinical integrity and high scientific flexibility.

---

## References

- Abadi, D. J. (2012). Consistency tradeoffs in modern distributed database system design: CAP is only part of the story. *Computer*, 45(2), 37-42.
- Braak, H., & Braak, E. (1991). Neuropathological stageing of Alzheimer-related changes. *Acta Neuropathologica*, 82(4), 239-259.
- Brewer, E. A. (2000). Towards robust distributed systems. *PODC Keynote*, 7, 10-1145.
- Gorgolewski, K. J., et al. (2016). The brain imaging data structure, a format for organizing and describing outputs of neuroimaging experiments. *Scientific Data*, 3(1), 1-9.
- MongoDB Inc. (2024). *MongoDB Documentation: Aggregation Pipeline Operations & JSON Schema Validation*. https://www.mongodb.com/docs/manual/aggregation/
