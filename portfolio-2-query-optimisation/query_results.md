# Portfolio 2: SQL Query Execution Results

**Course:** MIT 8103 – Advanced Database Systems  
**Institution:** Miva Open University  
**Student:** Patrick Filima  
**Database:** `anrdms` (PostgreSQL 16.16)  
**Execution Timestamp:** 2026-11-14T18:48:00Z  

---

### Query 1: Multi-Site Scanner Utilization & Total Acquisitions

**Research Question:** How many MRI scans have been acquired at each research site?  
**SQL Techniques:** Multi-table `LEFT JOIN`, `GROUP BY`, Aggregate `COUNT()`, `ORDER BY DESC`.  
**Clinical Rationale:** Essential for monitoring recruitment balance across Nigerian hospital centres. The use of `LEFT JOIN` ensures that sites without scans are retained in the reporting view rather than dropped.

```sql
SELECT
    rs.site_id,
    rs.hospital_name,
    COUNT(ms.scan_id) AS total_scans
FROM research_sites rs
LEFT JOIN mri_scanners sc
    ON rs.site_id = sc.site_id
LEFT JOIN mri_scans ms
    ON sc.scanner_id = ms.scanner_id
GROUP BY rs.site_id, rs.hospital_name
ORDER BY total_scans DESC;
```

**Live Verified Database Output:**
```
   site_id   |                   hospital_name                   | total_scans 
-------------+---------------------------------------------------+-------------
 SITE-LOS-01 | Lagos University Teaching Hospital (LUTH)         |           9
 SITE-ABJ-01 | National Hospital Abuja (NHA)                     |           8
 SITE-IBD-01 | University College Hospital (UCH)                 |           7
 SITE-ZAR-01 | Ahmadu Bello University Teaching Hospital (ABUTH) |           6
 SITE-ENU-01 | University of Nigeria Teaching Hospital (UNTH)    |           6
(5 rows)
```

---

### Query 2: Participant Cohort Distribution by Neurological Diagnosis

**Research Question:** How are research participants distributed across neurological conditions?  
**SQL Techniques:** `LEFT JOIN`, `COUNT(DISTINCT pd.participant_id)`, `GROUP BY`, `ORDER BY DESC`.  
**Clinical Rationale:** Audits cohort demographics across pathology categories. Using `COUNT(DISTINCT)` prevents duplicate counting of participants who have undergone multiple diagnostic visits.

```sql
SELECT
    nd.condition_name,
    nd.category,
    COUNT(DISTINCT pd.participant_id) AS total_participants
FROM neurological_diagnoses nd
LEFT JOIN participant_diagnoses pd
    ON nd.diagnosis_code = pd.diagnosis_code
GROUP BY nd.diagnosis_code,
         nd.condition_name,
         nd.category
ORDER BY total_participants DESC;
```

**Live Verified Database Output:**
```
                  condition_name                   |      category       | total_participants 
---------------------------------------------------+---------------------+--------------------
 Cognitively Unimpaired Healthy Control            | Healthy Control     |                  7
 Acute Ischemic Stroke                             | Cerebrovascular     |                  5
 Temporal Lobe Epilepsy with Hippocampal Sclerosis | Epilepsy & Seizures |                  4
 Vascular Dementia                                 | Neurodegenerative   |                  3
 Early-Onset Alzheimer's Dementia                  | Neurodegenerative   |                  3
 Idiopathic Parkinson's Disease                    | Neurodegenerative   |                  2
 Intracerebral Hemorrhage                          | Cerebrovascular     |                  1
(7 rows)
```

---

### Query 3: Quality-Certified Structural MRI Cohort Retrieval

**Research Question:** Which T1-weighted MRI scans have passed quality control?  
**SQL Techniques:** Multi-table `INNER JOIN`, Correlated Subquery with `EXISTS`, Filtering.  
**Clinical Rationale:** Selects scans certified by radiologists (`overall_quality = 'PASS'` and `usable_for_analysis = TRUE`) for automated volumetric morphometry. `EXISTS` prevents duplicate rows if a scan was evaluated by multiple reviewers.

```sql
SELECT
    ms.scan_id,
    ms.participant_id,
    ms.sequence_type,
    rs.hospital_name,
    ms.acquisition_date
FROM mri_scans ms
JOIN mri_scanners sc
    ON ms.scanner_id = sc.scanner_id
JOIN research_sites rs
    ON sc.site_id = rs.site_id
WHERE ms.sequence_type = 'T1w'
AND EXISTS (
    SELECT 1
    FROM qc_evaluations qc
    WHERE qc.scan_id = ms.scan_id
      AND qc.overall_quality = 'PASS'
      AND qc.usable_for_analysis = TRUE
)
ORDER BY ms.acquisition_date DESC;
```

**Live Verified Database Output:**
```
    scan_id     | participant_id | sequence_type |                   hospital_name                   |    acquisition_date    
----------------+----------------+---------------+---------------------------------------------------+------------------------
 SCN-ABJ-003-T1 | ANRDMS-ABJ-003 | T1w           | National Hospital Abuja (NHA)                     | 2025-03-16 12:30:00+00
 SCN-ENU-002-T1 | ANRDMS-ENU-002 | T1w           | University of Nigeria Teaching Hospital (UNTH)    | 2025-03-14 10:15:00+00
 SCN-ZAR-001-T1 | ANRDMS-ZAR-001 | T1w           | Ahmadu Bello University Teaching Hospital (ABUTH) | 2025-03-08 08:15:00+00
 SCN-LOS-003-T1 | ANRDMS-LOS-003 | T1w           | Lagos University Teaching Hospital (LUTH)         | 2025-03-05 13:00:00+00
 SCN-ABJ-002-T1 | ANRDMS-ABJ-002 | T1w           | National Hospital Abuja (NHA)                     | 2025-03-02 09:00:00+00
 SCN-ABJ-001-T1 | ANRDMS-ABJ-001 | T1w           | National Hospital Abuja (NHA)                     | 2025-02-25 07:30:00+00
 SCN-LOS-002-T1 | ANRDMS-LOS-002 | T1w           | Lagos University Teaching Hospital (LUTH)         | 2025-02-20 10:15:00+00
 SCN-ENU-001-T1 | ANRDMS-ENU-001 | T1w           | University of Nigeria Teaching Hospital (UNTH)    | 2025-02-18 09:30:00+00
 SCN-LOS-001-T1 | ANRDMS-LOS-001 | T1w           | Lagos University Teaching Hospital (LUTH)         | 2025-02-14 08:30:00+00
 SCN-IBD-001-T1 | ANRDMS-IBD-001 | T1w           | University College Hospital (UCH)                 | 2025-01-28 09:10:00+00
(10 rows)
```

---

### Query 4: Computational Pipeline Failure Rate & Reliability Audit

**Research Question:** Which processing pipelines have the highest failure rates?  
**SQL Techniques:** `LEFT JOIN`, Modern SQL:2003 `FILTER (WHERE ...)`, `NULLIF()`, `ROUND()`.  
**Clinical Rationale:** Tracks pipeline performance and compute resource exhaustion (e.g. OOM termination during FreeSurfer `recon-all`) across institutional HPC nodes.

```sql
SELECT
    pp.pipeline_id,
    pp.name,
    pp.version,
    COUNT(pj.job_id) AS total_jobs,
    COUNT(pj.job_id) FILTER (
        WHERE pj.status = 'FAILED'
    ) AS failed_jobs,
    COUNT(pj.job_id) FILTER (
        WHERE pj.status IN ('COMPLETED', 'FAILED')
    ) AS completed_or_failed_jobs,
    ROUND(
        100.0 * COUNT(pj.job_id) FILTER (
            WHERE pj.status = 'FAILED'
        )
        / NULLIF(
            COUNT(pj.job_id) FILTER (
                WHERE pj.status IN ('COMPLETED', 'FAILED')
            ), 0
        ), 2
    ) AS failure_rate_percent
FROM processing_pipelines pp
LEFT JOIN processing_jobs pj
    ON pp.pipeline_id = pj.pipeline_id
GROUP BY pp.pipeline_id, pp.name, pp.version
ORDER BY failure_rate_percent DESC NULLS LAST;
```

**Live Verified Database Output:**
```
   pipeline_id   |                name                | version | total_jobs | failed_jobs | completed_or_failed_jobs | failure_rate_percent 
-----------------+------------------------------------+---------+------------+-------------+--------------------------+----------------------
 PIP-FS-741      | FreeSurfer Cortical Reconstruction | 7.4.1   |         16 |           1 |                       14 |                 7.14
 PIP-QSIPREP-020 | QSIPrep Diffusion Preprocessing    | 0.20.0  |          3 |           0 |                        3 |                 0.00
 PIP-FLAIR-WML   | BIANCA White Matter Lesion Tool    | 1.2.0   |          2 |           0 |                        2 |                 0.00
 PIP-FMRIPREP-23 | fMRIPrep BIDS Pipeline             | 23.2.0  |          2 |           0 |                        2 |                 0.00
 PIP-FSL-607     | FSL Brain Extraction & FEAT        | 6.0.7   |          0 |           0 |                        0 |                     
(5 rows)
```

---

### Query 5: Multi-Modal Acquisition Diversity

**Research Question:** Which participants have undergone multiple distinct MRI sequences?  
**SQL Techniques:** `INNER JOIN`, `GROUP BY`, `HAVING COUNT(DISTINCT ...) > 1`, `STRING_AGG()`.  
**Clinical Rationale:** Identifies multi-modal subjects possessing complementary structural, diffusion, and functional datasets for advanced multimodal neuroimaging models.

```sql
SELECT
    p.participant_id,
    COUNT(DISTINCT ms.sequence_type) AS sequence_count,
    STRING_AGG(
        DISTINCT ms.sequence_type,
        ', ' ORDER BY ms.sequence_type
    ) AS available_sequences
FROM participants p
JOIN mri_scans ms
    ON p.participant_id = ms.participant_id
GROUP BY p.participant_id
HAVING COUNT(DISTINCT ms.sequence_type) > 1
ORDER BY sequence_count DESC;
```

**Live Verified Database Output:**
```
 participant_id | sequence_count | available_sequences 
----------------+----------------+---------------------
 ANRDMS-LOS-001 |              3 | dMRI, FLAIR, T1w
 ANRDMS-ABJ-002 |              2 | FLAIR, T1w
 ANRDMS-ABJ-003 |              2 | fMRI-rest, T1w
 ANRDMS-ENU-001 |              2 | FLAIR, T1w
 ANRDMS-IBD-001 |              2 | FLAIR, T1w
 ANRDMS-IBD-002 |              2 | dMRI, T1w
 ANRDMS-LOS-002 |              2 | FLAIR, T1w
 ANRDMS-LOS-003 |              2 | fMRI-rest, T1w
 ANRDMS-ABJ-001 |              2 | dMRI, T1w
 ANRDMS-ZAR-002 |              2 | FLAIR, T1w
(10 rows)
```

---

### Query 6: Computational Backlog Identification (Unprocessed Scans)

**Research Question:** Which MRI scans lack a successfully completed processing job?  
**SQL Techniques:** Correlated Subquery with `NOT EXISTS`, Temporal Sorting.  
**Clinical Rationale:** Feeds automated scheduler queues by identifying acquired scans that have not yet undergone pipeline processing or whose previous attempts failed.

```sql
SELECT
    ms.scan_id,
    ms.participant_id,
    ms.sequence_type,
    ms.acquisition_date
FROM mri_scans ms
WHERE NOT EXISTS (
    SELECT 1
    FROM processing_jobs pj
    WHERE pj.scan_id = ms.scan_id
      AND pj.status = 'COMPLETED'
)
ORDER BY ms.acquisition_date DESC;
```

**Live Verified Database Output:**
```
    scan_id     | participant_id | sequence_type |    acquisition_date    
----------------+----------------+---------------+------------------------
 SCN-ZAR-005-T1 | ANRDMS-ZAR-005 | T1w           | 2025-06-25 14:40:00+01
 SCN-ENU-005-T1 | ANRDMS-ENU-005 | T1w           | 2025-06-20 15:30:00+01
 SCN-IBD-005-T1 | ANRDMS-IBD-005 | T1w           | 2025-05-28 16:00:00+01
 SCN-ABJ-005-T1 | ANRDMS-ABJ-005 | T1w           | 2025-05-22 15:10:00+01
 SCN-ZAR-004-T1 | ANRDMS-ZAR-004 | T1w           | 2025-05-12 10:15:00+01
 SCN-ENU-004-T1 | ANRDMS-ENU-004 | T1w           | 2025-05-08 12:40:00+01
 SCN-IBD-004-T1 | ANRDMS-IBD-004 | T1w           | 2025-04-26 09:20:00+01
 SCN-ZAR-003-T1 | ANRDMS-ZAR-003 | T1w           | 2025-04-22 13:00:00+01
 SCN-LOS-005-T1 | ANRDMS-LOS-005 | T1w           | 2025-04-10 15:40:00+01
 SCN-ENU-003-T1 | ANRDMS-ENU-003 | T1w           | 2025-04-10 14:00:00+01
 SCN-ZAR-002-FL | ANRDMS-ZAR-002 | FLAIR         | 2025-04-02 11:45:00+01
 SCN-ABJ-003-T1 | ANRDMS-ABJ-003 | T1w           | 2025-03-16 12:30:00+00
 SCN-ABJ-002-FL | ANRDMS-ABJ-002 | FLAIR         | 2025-03-02 09:15:00+00
 SCN-ENU-001-FL | ANRDMS-ENU-001 | FLAIR         | 2025-02-18 09:45:00+00
 SCN-IBD-002-T1 | ANRDMS-IBD-002 | T1w           | 2025-02-12 10:45:00+00
 SCN-IBD-001-FL | ANRDMS-IBD-001 | FLAIR         | 2025-01-28 09:25:00+00
(16 rows)
```

---

### Query 7: Longitudinal Session Stratification (Most Recent Scan per Subject)

**Research Question:** What is the most recent MRI scan acquisition for each participant?  
**SQL Techniques:** Common Table Expression (`WITH ranked_scans AS (...)`), Window Function (`ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ...)`).  
**Clinical Rationale:** Selects the most recent imaging assessment for disease progression tracking while avoiding computationally expensive self-joins.

```sql
WITH ranked_scans AS (
    SELECT
        scan_id,
        participant_id,
        sequence_type,
        acquisition_date,
        ROW_NUMBER() OVER (
            PARTITION BY participant_id
            ORDER BY acquisition_date DESC,
                     scan_id DESC
        ) AS scan_rank
    FROM mri_scans
)
SELECT
    participant_id,
    scan_id,
    sequence_type,
    acquisition_date
FROM ranked_scans
WHERE scan_rank = 1
ORDER BY participant_id;
```

**Live Verified Database Output:**
```
 participant_id |    scan_id     | sequence_type |    acquisition_date    
----------------+----------------+---------------+------------------------
 ANRDMS-ABJ-001 | SCN-ABJ-001-DM | dMRI          | 2025-02-25 07:48:00+00
 ANRDMS-ABJ-002 | SCN-ABJ-002-FL | FLAIR         | 2025-03-02 09:15:00+00
 ANRDMS-ABJ-003 | SCN-ABJ-003-FM | fMRI-rest     | 2025-03-16 12:50:00+00
 ANRDMS-ABJ-004 | SCN-ABJ-004-T1 | T1w           | 2025-04-10 11:00:00+01
 ANRDMS-ABJ-005 | SCN-ABJ-005-T1 | T1w           | 2025-05-22 15:10:00+01
 ANRDMS-ENU-001 | SCN-ENU-001-FL | FLAIR         | 2025-02-18 09:45:00+00
 ANRDMS-ENU-002 | SCN-ENU-002-T1 | T1w           | 2025-03-14 10:15:00+00
 ANRDMS-ENU-003 | SCN-ENU-003-T1 | T1w           | 2025-04-10 14:00:00+01
 ANRDMS-ENU-004 | SCN-ENU-004-T1 | T1w           | 2025-05-08 12:40:00+01
 ANRDMS-ENU-005 | SCN-ENU-005-T1 | T1w           | 2025-06-20 15:30:00+01
 ANRDMS-IBD-001 | SCN-IBD-001-FL | FLAIR         | 2025-01-28 09:25:00+00
 ANRDMS-IBD-002 | SCN-IBD-002-DM | dMRI          | 2025-02-12 11:05:00+00
 ANRDMS-IBD-003 | SCN-IBD-003-T1 | T1w           | 2025-03-24 13:15:00+00
 ANRDMS-IBD-004 | SCN-IBD-004-T1 | T1w           | 2025-04-26 09:20:00+01
 ANRDMS-IBD-005 | SCN-IBD-005-T1 | T1w           | 2025-05-28 16:00:00+01
 ANRDMS-LOS-001 | SCN-LOS-001-DM | dMRI          | 2025-02-14 08:55:00+00
 ANRDMS-LOS-002 | SCN-LOS-002-FL | FLAIR         | 2025-02-20 10:28:00+00
 ANRDMS-LOS-003 | SCN-LOS-003-FM | fMRI-rest     | 2025-03-05 13:18:00+00
 ANRDMS-LOS-004 | SCN-LOS-004-T1 | T1w           | 2025-03-18 09:20:00+00
 ANRDMS-LOS-005 | SCN-LOS-005-T1 | T1w           | 2025-04-10 15:40:00+01
 ANRDMS-ZAR-001 | SCN-ZAR-001-T1 | T1w           | 2025-03-08 08:15:00+00
 ANRDMS-ZAR-002 | SCN-ZAR-002-FL | FLAIR         | 2025-04-02 11:45:00+01
 ANRDMS-ZAR-003 | SCN-ZAR-003-T1 | T1w           | 2025-04-22 13:00:00+01
 ANRDMS-ZAR-004 | SCN-ZAR-004-T1 | T1w           | 2025-05-12 10:15:00+01
 ANRDMS-ZAR-005 | SCN-ZAR-005-T1 | T1w           | 2025-06-25 14:40:00+01
(25 rows)
```
