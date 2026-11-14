# African Neuroimaging Research Data Management System (ANRDMS)
## Portfolio 1: Relational Data Dictionary

**Course:** MIT 8103 – Advanced Database Systems  
**Institution:** Miva Open University  
**Student:** Patrick Filima  
**Target DBMS:** PostgreSQL 14+  

> [!NOTE]
> **Neuroimaging Data Scope Notice:** ANRDMS stores structured imaging metadata, pulse sequence acquisition parameters, clinical phenotypic attributes, and Brain Imaging Data Structure (BIDS) relative directory paths (`bids_relative_path`). High-volume 3D/4D binary imaging volumes (raw DICOM archives, NIfTI `.nii.gz` files, and derivative surfaces) reside on external file/object storage systems (e.g., local Ceph/NFS clusters or Cloud Object Storage), linked deterministically through this relational database catalog.

---

### Entity Index

1. [`research_sites`](#1-research_sites)
2. [`mri_scanners`](#2-mri_scanners)
3. [`researchers`](#3-researchers)
4. [`research_projects`](#4-research_projects)
5. [`participants`](#5-participants)
6. [`neurological_diagnoses`](#6-neurological_diagnoses)
7. [`participant_diagnoses`](#7-participant_diagnoses)
8. [`mri_scans`](#8-mri_scans)
9. [`processing_pipelines`](#9-processing_pipelines)
10. [`processing_jobs`](#10-processing_jobs)
11. [`qc_evaluations`](#11-qc_evaluations)

---

### 1. `research_sites`
*Stores hospital centres and regional academic medical institutions participating in multi-site MRI studies.*

| Column Name | Data Type | Nullable | Key / Constraint | Default | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `site_id` | VARCHAR(15) | NO | **PK** | — | Unique institutional site code (e.g., `SITE-LOS-01`). |
| `hospital_name` | VARCHAR(150) | NO | — | — | Formal institutional facility name. |
| `city` | VARCHAR(60) | NO | — | — | City of physical location. |
| `state` | VARCHAR(60) | NO | — | — | Nigerian state location. |
| `tier` | VARCHAR(40) | NO | `CHECK (tier IN (...))` | — | Institutional categorization (`Federal Medical Centre`, `University Teaching Hospital`, `Specialist Research Institute`). |
| `contact_email` | VARCHAR(120) | NO | `CHECK (email LIKE ...)` | — | Administrative research department email. |
| `phone_number` | VARCHAR(30) | YES | — | — | Switchboard or departmental telephone contact. |
| `is_active` | BOOLEAN | NO | — | `TRUE` | Indicates whether site is currently recruiting/imaging. |
| `created_at` | TIMESTAMPTZ | NO | — | `CURRENT_TIMESTAMP` | Record audit timestamp. |

---

### 2. `mri_scanners`
*Hardware specifications, field strengths, and maintenance states of installed MRI systems.*

| Column Name | Data Type | Nullable | Key / Constraint | Default | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `scanner_id` | VARCHAR(20) | NO | **PK** | — | Unique scanner identifier (e.g., `SCN-LOS-3T01`). |
| `site_id` | VARCHAR(15) | NO | **FK** (`research_sites.site_id`) | — | Location where scanner is installed. |
| `manufacturer` | VARCHAR(50) | NO | — | — | Scanner vendor (`Siemens Healthineers`, `GE Healthcare`, `Philips Healthcare`). |
| `model_name` | VARCHAR(80) | NO | — | — | Model designation (`MAGNETOM Skyra`, `Signa Explorer`). |
| `magnetic_field_strength_tesla` | NUMERIC(3,1) | NO | `CHECK (IN (0.3, 1.5, 3.0, 7.0))` | — | Static magnetic field strength ($B_0$) in Tesla (supports 0.3T low-field to 7.0T ultra-high field). |
| `gradient_strength_mt_m` | NUMERIC(5,2) | NO | `CHECK (> 0)` | — | Peak gradient amplitude ($mT/m$). |
| `software_version` | VARCHAR(50) | NO | — | — | Console operating software release. |
| `installation_date` | DATE | NO | — | — | Official commissioning date. |
| `last_calibration_date` | DATE | NO | `CHECK (>= installation_date)` | — | Most recent phantom QA calibration date. |
| `is_operational` | BOOLEAN | NO | — | `TRUE` | Current functional availability status. |
| `created_at` | TIMESTAMPTZ | NO | — | `CURRENT_TIMESTAMP` | Audit timestamp. |

---

### 3. `researchers`
*Clinical investigators, radiologists, neuroimaging analysts, and scientific personnel.*

| Column Name | Data Type | Nullable | Key / Constraint | Default | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `researcher_id` | VARCHAR(20) | NO | **PK** | — | Unique researcher identity code. |
| `full_name` | VARCHAR(100) | NO | — | — | Full name including academic title. |
| `email` | VARCHAR(120) | NO | **UK**, `CHECK` | — | Institutional email address. |
| `affiliation_site_id` | VARCHAR(15) | YES | **FK** (`research_sites.site_id`) | — | Primary home institution. |
| `role` | VARCHAR(50) | NO | `CHECK (role IN (...))` | — | Professional function (`Principal Investigator`, `Radiologist`, `Neuroimaging Analyst`, `Data Manager`, `Clinical Research Coordinator`). |
| `orcid` | VARCHAR(20) | YES | `CHECK (regex)` | — | Open Researcher and Contributor ID. |
| `created_at` | TIMESTAMPTZ | NO | — | `CURRENT_TIMESTAMP` | Audit creation timestamp. |

---

### 4. `research_projects`
*Grant-funded studies, clinical trials, and scientific protocols.*

| Column Name | Data Type | Nullable | Key / Constraint | Default | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `project_id` | VARCHAR(20) | NO | **PK** | — | Unique project identifier (e.g., `PRJ-ABHI-2025`). |
| `project_name` | VARCHAR(150) | NO | — | — | Descriptive project title. |
| `principal_investigator_id` | VARCHAR(20) | NO | **FK** (`researchers.researcher_id`) | — | Lead academic PI. |
| `funding_agency` | VARCHAR(120) | NO | — | — | Sponsoring grant authority. |
| `ethics_approval_code` | VARCHAR(60) | NO | **UK** | — | Institutional Review Board (NHREC) ethics code. |
| `start_date` | DATE | NO | — | — | Project commencement date. |
| `end_date` | DATE | YES | `CHECK (end_date >= start_date)` | — | Project projected or actual completion date. |
| `status` | VARCHAR(20) | NO | `CHECK (status IN (...))` | `'ACTIVE'` | Current status (`PLANNING`, `ACTIVE`, `COMPLETED`, `SUSPENDED`, `ARCHIVED`). |
| `created_at` | TIMESTAMPTZ | NO | — | `CURRENT_TIMESTAMP` | Audit timestamp. |

---

### 5. `participants`
*Demographic and consent information for enrolled study participants.*

| Column Name | Data Type | Nullable | Key / Constraint | Default | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `participant_id` | VARCHAR(25) | NO | **PK** | — | De-identified pseudonymised participant code. |
| `primary_site_id` | VARCHAR(15) | NO | **FK** (`research_sites.site_id`) | — | Enrolling hospital centre. |
| `enrollment_date` | DATE | NO | — | — | Study enrollment date. |
| `birth_year` | INT | NO | `CHECK (1920..2026)` | — | Year of birth (coarsened for privacy). |
| `biological_sex` | VARCHAR(10) | NO | `CHECK (IN ('Female','Male','Other'))` | — | Phenotypic biological sex. |
| `handedness` | VARCHAR(15) | NO | `CHECK (IN ('Right','Left','Ambidextrous'))` | `'Right'` | Dominant hand motor preference. |
| `education_years` | INT | YES | `CHECK (0..30)` | — | Formal completed years of education. |
| `consent_obtained` | BOOLEAN | NO | `CHECK (consent_obtained IS TRUE)` | — | Explicitly verified ethical informed consent flag (NOT NULL, no default assumed). |
| `created_at` | TIMESTAMPTZ | NO | — | `CURRENT_TIMESTAMP` | Audit timestamp. |

---

### 6. `neurological_diagnoses`
*Reference dictionary of neurological pathologies and healthy control cohorts mapped to ICD-11.*

| Column Name | Data Type | Nullable | Key / Constraint | Default | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `diagnosis_code` | VARCHAR(20) | NO | **PK** | — | Internal standard code (e.g., `DX-STR-001`). |
| `condition_name` | VARCHAR(100) | NO | **UK** | — | Formal clinical disease name. |
| `category` | VARCHAR(60) | NO | `CHECK (category IN (...))` | — | High-level disease category (`Cerebrovascular`, `Neurodegenerative`, `Epilepsy & Seizures`, etc.). |
| `icd11_code` | VARCHAR(25) | NO | — | — | WHO ICD-11 classification code. |
| `description` | TEXT | YES | — | — | Clinical diagnostic criteria summary. |

---

### 7. `participant_diagnoses`
*Junction entity linking participants to clinical diagnoses with severity and longitudinal timestamps.*

| Column Name | Data Type | Nullable | Key / Constraint | Default | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `participant_diagnosis_id` | BIGSERIAL | NO | **PK** | auto-increment | Synthetic surrogate primary key. |
| `participant_id` | VARCHAR(25) | NO | **FK** (`participants.participant_id`) | — | Associated participant. |
| `diagnosis_code` | VARCHAR(20) | NO | **FK** (`neurological_diagnoses.diagnosis_code`) | — | Assigned pathology code. |
| `diagnosing_researcher_id` | VARCHAR(20) | NO | **FK** (`researchers.researcher_id`) | — | Clinician/radiologist confirming diagnosis. |
| `diagnosis_date` | DATE | NO | — | — | Date of diagnosis evaluation. |
| `severity_stage` | VARCHAR(25) | NO | `CHECK (IN (...))` | `'Not Applicable'` | Disease severity (`Subclinical`, `Mild`, `Moderate`, `Severe`, `Not Applicable`). |
| `is_primary_diagnosis` | BOOLEAN | NO | — | `TRUE` | Flags primary study entry indication. |
| `clinical_notes` | TEXT | YES | — | — | Additional radiological/clinical notes. |
| `created_at` | TIMESTAMPTZ | NO | — | `CURRENT_TIMESTAMP` | Audit timestamp. |
| *Composite Unique* | — | — | `UNIQUE (participant_id, diagnosis_code)` | — | Current diagnosis constraint (permits one current record per condition). |

---

### 8. `mri_scans`
*Detailed acquisition parameters, scanner linkage, and BIDS directory layout for individual imaging series.*

| Column Name | Data Type | Nullable | Key / Constraint | Default | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `scan_id` | VARCHAR(30) | NO | **PK** | — | Unique acquisition session code. |
| `participant_id` | VARCHAR(25) | NO | **FK** (`participants.participant_id`) | — | Subject scanned. |
| `scanner_id` | VARCHAR(20) | NO | **FK** (`mri_scanners.scanner_id`) | — | Acquisition hardware used. |
| `project_id` | VARCHAR(20) | NO | **FK** (`research_projects.project_id`) | — | Research study governing scan. |
| `acquisition_date` | TIMESTAMPTZ | NO | — | — | Timestamp of scan execution. |
| `modality` | VARCHAR(10) | NO | — | `'MRI'` | Imaging modality. |
| `sequence_type` | VARCHAR(25) | NO | `CHECK (IN (...))` | — | Pulse sequence (`T1w`, `T2w`, `FLAIR`, `dMRI`, `fMRI-rest`, `fMRI-task`, `MRA`). |
| `repetition_time_ms` | NUMERIC(8,2) | NO | `CHECK (> 0)` | — | Repetition time ($TR$) in milliseconds. |
| `echo_time_ms` | NUMERIC(6,2) | NO | `CHECK (> 0)` | — | Echo time ($TE$) in milliseconds. |
| `flip_angle_deg` | NUMERIC(4,1) | YES | `CHECK (0..180)` | — | RF pulse excitation flip angle in degrees. |
| `voxel_size_x_mm` | NUMERIC(4,2) | NO | `CHECK (> 0)` | — | Spatial resolution along x-axis ($mm$). |
| `voxel_size_y_mm` | NUMERIC(4,2) | NO | `CHECK (> 0)` | — | Spatial resolution along y-axis ($mm$). |
| `voxel_size_z_mm` | NUMERIC(4,2) | NO | `CHECK (> 0)` | — | Slice thickness ($mm$). |
| `matrix_x` | INT | NO | `CHECK (> 0)` | — | Reconstruction matrix dimension x. |
| `matrix_y` | INT | NO | `CHECK (> 0)` | — | Reconstruction matrix dimension y. |
| `slices_count` | INT | NO | `CHECK (> 0)` | — | Total anatomical slice planes acquired. |
| `dicom_series_uid` | VARCHAR(120) | NO | **UK** | — | Globally unique DICOM Series Instance UID. |
| `bids_relative_path` | VARCHAR(255) | NO | **UK** | — | Canonical BIDS relative file path on storage. |
| `file_size_bytes` | BIGINT | NO | `CHECK (> 0)` | — | Raw NIfTI file size in bytes. |
| `created_at` | TIMESTAMPTZ | NO | — | `CURRENT_TIMESTAMP` | Audit timestamp. |

---

### 9. `processing_pipelines`
*Catalog of standardized neuroinformatics pipelines containerized for reproducibility.*

| Column Name | Data Type | Nullable | Key / Constraint | Default | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `pipeline_id` | VARCHAR(25) | NO | **PK** | — | Unique software pipeline identifier. |
| `name` | VARCHAR(80) | NO | — | — | Software name (e.g., `FreeSurfer Cortical Reconstruction`). |
| `version` | VARCHAR(30) | NO | — | — | Exact semantic version tag. |
| `container_image` | VARCHAR(150) | NO | — | — | Docker/Singularity image reference. |
| `target_sequence` | VARCHAR(25) | NO | `CHECK (IN (...))` | — | Primary sequence processed (`T1w`, `dMRI`, etc.). |
| `description` | TEXT | NO | — | — | Algorithmic summary of pipeline steps. |
| `is_active` | BOOLEAN | NO | — | `TRUE` | Deployment status flag. |
| `created_at` | TIMESTAMPTZ | NO | — | `CURRENT_TIMESTAMP` | Audit timestamp. |
| *Composite Unique* | — | — | `UNIQUE (name, version)` | — | Enforces unique version registry. |

---

### 10. `processing_jobs`
*Computational execution records tracking batch HPC and cloud processing runs.*

| Column Name | Data Type | Nullable | Key / Constraint | Default | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `job_id` | BIGSERIAL | NO | **PK** | auto-increment | Unique job execution tracking ID. |
| `scan_id` | VARCHAR(30) | NO | **FK** (`mri_scans.scan_id`) | — | Input scan processed. |
| `pipeline_id` | VARCHAR(25) | NO | **FK** (`processing_pipelines.pipeline_id`) | — | Executed neuroinformatics pipeline. |
| `submitted_by_id` | VARCHAR(20) | NO | **FK** (`researchers.researcher_id`) | — | Submitting user/analyst. |
| `submission_time` | TIMESTAMPTZ | NO | — | `CURRENT_TIMESTAMP` | Dispatch timestamp. |
| `start_time` | TIMESTAMPTZ | YES | — | — | Execution start timestamp on compute node. |
| `end_time` | TIMESTAMPTZ | YES | `CHECK (end_time >= start_time)` | — | Job termination timestamp. |
| `status` | VARCHAR(20) | NO | `CHECK (status IN (...))` | `'PENDING'` | State (`PENDING`, `RUNNING`, `COMPLETED`, `FAILED`, `CANCELLED`). |
| `exit_code` | INT | YES | — | — | Linux process exit status (0 = success). |
| `compute_node` | VARCHAR(80) | YES | — | — | Hostname/cluster node executing workload. |
| `output_directory` | VARCHAR(255) | YES | — | — | Storage path containing derivative output files. |
| `error_message` | TEXT | YES | — | — | Standard error log trace upon failure. |

---

### 11. `qc_evaluations`
*Automated and radiologist visual quality control audits.*

| Column Name | Data Type | Nullable | Key / Constraint | Default | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `qc_id` | BIGSERIAL | NO | **PK** | auto-increment | Unique QA evaluation record ID. |
| `scan_id` | VARCHAR(30) | NO | **FK** (`mri_scans.scan_id`) | — | Associated scan evaluated. |
| `evaluator_id` | VARCHAR(20) | NO | **FK** (`researchers.researcher_id`) | — | Reviewing radiologist or analyst. |
| `evaluation_date` | TIMESTAMPTZ | NO | — | `CURRENT_TIMESTAMP` | Audit timestamp of evaluation. |
| `overall_quality` | VARCHAR(10) | NO | `CHECK (IN ('PASS','WARN','FAIL'))` | — | Summary qualitative rating. |
| `snr_score` | NUMERIC(6,2) | NO | `CHECK (snr_score >= 0)` | — | Signal-to-Noise Ratio. |
| `cnr_score` | NUMERIC(6,2) | NO | `CHECK (cnr_score >= 0)` | — | Contrast-to-Noise Ratio (grey-to-white matter). |
| `head_motion_fd_mean_mm` | NUMERIC(5,3) | NO | `CHECK (>= 0)` | — | Mean Framewise Displacement in millimeters (primary motion metric). |
| `usable_for_analysis` | BOOLEAN | NO | — | `TRUE` | Certification for downstream pipeline entry. |
| `artifact_notes` | TEXT | YES | — | — | Qualitative findings (e.g. ghosting, ringing). |
| `created_at` | TIMESTAMPTZ | NO | — | `CURRENT_TIMESTAMP` | Audit timestamp. |
| *Composite Unique* | — | — | `UNIQUE (scan_id, evaluator_id)` | — | One evaluation per reviewer per scan. |
