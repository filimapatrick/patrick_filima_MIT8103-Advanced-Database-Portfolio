-- ============================================================================
-- MIT 8103: Advanced Database Systems
-- Continuous Assessment (CA) - September Cohort 2026
-- Student: Patrick Filima
-- Institution: Miva Open University
-- Portfolio 1: Database Design and Modelling
-- File: schema.sql
-- 
-- System: African Neuroimaging Research Data Management System (ANRDMS)
-- Target DBMS: PostgreSQL 14+
-- Description: Production-grade DDL defining the relational schema, constraints,
--              relationships, and indexing for multi-site neuroimaging research.
-- ============================================================================

-- Drop tables if they exist to ensure clean re-runs (ordered by foreign key dependency)
DROP TABLE IF EXISTS qc_evaluations CASCADE;
DROP TABLE IF EXISTS processing_jobs CASCADE;
DROP TABLE IF EXISTS processing_pipelines CASCADE;
DROP TABLE IF EXISTS mri_scans CASCADE;
DROP TABLE IF EXISTS participant_diagnoses CASCADE;
DROP TABLE IF EXISTS neurological_diagnoses CASCADE;
DROP TABLE IF EXISTS participants CASCADE;
DROP TABLE IF EXISTS research_projects CASCADE;
DROP TABLE IF EXISTS researchers CASCADE;
DROP TABLE IF EXISTS mri_scanners CASCADE;
DROP TABLE IF EXISTS research_sites CASCADE;

-- Enable UUID extension if needed in future
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- 1. RESEARCH SITES (Hospitals and Imaging Centres across Nigeria)
-- ============================================================================
CREATE TABLE research_sites (
    site_id VARCHAR(15) PRIMARY KEY,
    hospital_name VARCHAR(150) NOT NULL,
    city VARCHAR(60) NOT NULL,
    state VARCHAR(60) NOT NULL,
    tier VARCHAR(40) NOT NULL,
    contact_email VARCHAR(120) NOT NULL,
    phone_number VARCHAR(30),
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_sites_tier CHECK (
        tier IN ('Federal Medical Centre', 'University Teaching Hospital', 'Specialist Research Institute')
    ),
    CONSTRAINT ck_sites_email CHECK (contact_email LIKE '%_@__%.__%')
);

COMMENT ON TABLE research_sites IS 'Participating Nigerian hospital and research sites hosting MRI facilities.';
COMMENT ON COLUMN research_sites.site_id IS 'Unique identifier for the research site (e.g., SITE-LOS-01).';
COMMENT ON COLUMN research_sites.tier IS 'Healthcare tier classification in the Nigerian health system.';

-- ============================================================================
-- 2. MRI SCANNERS (Hardware Specifications and Calibration)
-- ============================================================================
CREATE TABLE mri_scanners (
    scanner_id VARCHAR(20) PRIMARY KEY,
    site_id VARCHAR(15) NOT NULL,
    manufacturer VARCHAR(50) NOT NULL,
    model_name VARCHAR(80) NOT NULL,
    magnetic_field_strength_tesla NUMERIC(3, 1) NOT NULL,
    gradient_strength_mt_m NUMERIC(5, 2) NOT NULL,
    software_version VARCHAR(50) NOT NULL,
    installation_date DATE NOT NULL,
    last_calibration_date DATE NOT NULL,
    is_operational BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_scanners_site FOREIGN KEY (site_id) 
        REFERENCES research_sites(site_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_scanners_field_strength CHECK (
        magnetic_field_strength_tesla IN (1.5, 3.0, 7.0)
    ),
    CONSTRAINT ck_scanners_gradient CHECK (gradient_strength_mt_m > 0),
    CONSTRAINT ck_scanners_calibration CHECK (last_calibration_date >= installation_date)
);

COMMENT ON TABLE mri_scanners IS 'Physical magnetic resonance imaging scanners installed at research sites.';
COMMENT ON COLUMN mri_scanners.magnetic_field_strength_tesla IS 'Static magnetic field strength (B0) in Tesla (typically 1.5T or 3.0T).';

-- ============================================================================
-- 3. RESEARCHERS (Investigators, Radiologists, Analysts)
-- ============================================================================
CREATE TABLE researchers (
    researcher_id VARCHAR(20) PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(120) NOT NULL UNIQUE,
    affiliation_site_id VARCHAR(15),
    role VARCHAR(50) NOT NULL,
    orcid VARCHAR(20),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_researchers_site FOREIGN KEY (affiliation_site_id) 
        REFERENCES research_sites(site_id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT ck_researchers_role CHECK (
        role IN ('Principal Investigator', 'Radiologist', 'Neuroimaging Analyst', 'Data Manager', 'Clinical Research Coordinator')
    ),
    CONSTRAINT ck_researchers_email CHECK (email LIKE '%_@__%.__%'),
    CONSTRAINT ck_researchers_orcid CHECK (orcid IS NULL OR orcid ~ '^[0-9]{4}-[0-9]{4}-[0-9]{4}-[0-9]{3}[0-9X]$')
);

COMMENT ON TABLE researchers IS 'Clinical investigators, radiologists, neuroimaging analysts, and scientific personnel.';

-- ============================================================================
-- 4. RESEARCH PROJECTS (Studies, Grants, and Ethics Protocols)
-- ============================================================================
CREATE TABLE research_projects (
    project_id VARCHAR(20) PRIMARY KEY,
    project_name VARCHAR(150) NOT NULL,
    principal_investigator_id VARCHAR(20) NOT NULL,
    funding_agency VARCHAR(120) NOT NULL,
    ethics_approval_code VARCHAR(60) NOT NULL UNIQUE,
    start_date DATE NOT NULL,
    end_date DATE,
    status VARCHAR(20) DEFAULT 'ACTIVE' NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_projects_pi FOREIGN KEY (principal_investigator_id) 
        REFERENCES researchers(researcher_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_projects_dates CHECK (end_date IS NULL OR end_date >= start_date),
    CONSTRAINT ck_projects_status CHECK (
        status IN ('PLANNING', 'ACTIVE', 'COMPLETED', 'SUSPENDED', 'ARCHIVED')
    )
);

COMMENT ON TABLE research_projects IS 'Approved scientific research protocols and grant-funded imaging projects.';

-- ============================================================================
-- 5. PARTICIPANTS (Synthetic Research Cohort Demographics)
-- ============================================================================
CREATE TABLE participants (
    participant_id VARCHAR(25) PRIMARY KEY,
    primary_site_id VARCHAR(15) NOT NULL,
    enrollment_date DATE NOT NULL,
    birth_year INT NOT NULL,
    biological_sex VARCHAR(10) NOT NULL,
    handedness VARCHAR(15) DEFAULT 'Right' NOT NULL,
    education_years INT,
    consent_obtained BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_participants_site FOREIGN KEY (primary_site_id) 
        REFERENCES research_sites(site_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_participants_birth_year CHECK (birth_year BETWEEN 1920 AND 2026),
    CONSTRAINT ck_participants_sex CHECK (biological_sex IN ('Female', 'Male', 'Other')),
    CONSTRAINT ck_participants_handedness CHECK (handedness IN ('Right', 'Left', 'Ambidextrous')),
    CONSTRAINT ck_participants_education CHECK (education_years IS NULL OR education_years BETWEEN 0 AND 30),
    CONSTRAINT ck_participants_consent CHECK (consent_obtained IS TRUE)
);

COMMENT ON TABLE participants IS 'Synthetic research participants enrolled across Nigerian study cohorts.';
COMMENT ON COLUMN participants.consent_obtained IS 'Enforces ethical compliance: imaging records require confirmed participant consent.';

-- ============================================================================
-- 6. NEUROLOGICAL DIAGNOSES (Reference Ontology / ICD-11 Mapping)
-- ============================================================================
CREATE TABLE neurological_diagnoses (
    diagnosis_code VARCHAR(20) PRIMARY KEY,
    condition_name VARCHAR(100) NOT NULL UNIQUE,
    category VARCHAR(60) NOT NULL,
    icd11_code VARCHAR(25) NOT NULL,
    description TEXT,
    CONSTRAINT ck_diagnoses_category CHECK (
        category IN ('Cerebrovascular', 'Neurodegenerative', 'Epilepsy & Seizures', 'Infectious / Neuroinflammatory', 'Healthy Control')
    )
);

COMMENT ON TABLE neurological_diagnoses IS 'Standardised neurological disease classifications and healthy control benchmarks.';

-- ============================================================================
-- 7. PARTICIPANT DIAGNOSES (Clinical Assessment Association)
-- ============================================================================
CREATE TABLE participant_diagnoses (
    participant_diagnosis_id BIGSERIAL PRIMARY KEY,
    participant_id VARCHAR(25) NOT NULL,
    diagnosis_code VARCHAR(20) NOT NULL,
    diagnosing_researcher_id VARCHAR(20) NOT NULL,
    diagnosis_date DATE NOT NULL,
    severity_stage VARCHAR(25) DEFAULT 'Not Applicable' NOT NULL,
    is_primary_diagnosis BOOLEAN DEFAULT TRUE NOT NULL,
    clinical_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_ptdx_participant FOREIGN KEY (participant_id) 
        REFERENCES participants(participant_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_ptdx_diagnosis FOREIGN KEY (diagnosis_code) 
        REFERENCES neurological_diagnoses(diagnosis_code) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_ptdx_researcher FOREIGN KEY (diagnosing_researcher_id) 
        REFERENCES researchers(researcher_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_ptdx_severity CHECK (
        severity_stage IN ('Subclinical', 'Mild', 'Moderate', 'Severe', 'Not Applicable')
    ),
    CONSTRAINT uq_participant_diagnosis UNIQUE (participant_id, diagnosis_code)
);

COMMENT ON TABLE participant_diagnoses IS 'Associates research participants with specific clinical diagnoses and severity.';

-- ============================================================================
-- 8. MRI SCANS (Acquisition Session & DICOM/BIDS Metadata)
-- ============================================================================
CREATE TABLE mri_scans (
    scan_id VARCHAR(30) PRIMARY KEY,
    participant_id VARCHAR(25) NOT NULL,
    scanner_id VARCHAR(20) NOT NULL,
    project_id VARCHAR(20) NOT NULL,
    acquisition_date TIMESTAMPTZ NOT NULL,
    modality VARCHAR(10) DEFAULT 'MRI' NOT NULL,
    sequence_type VARCHAR(25) NOT NULL,
    repetition_time_ms NUMERIC(8, 2) NOT NULL,
    echo_time_ms NUMERIC(6, 2) NOT NULL,
    flip_angle_deg NUMERIC(4, 1),
    voxel_size_x_mm NUMERIC(4, 2) NOT NULL,
    voxel_size_y_mm NUMERIC(4, 2) NOT NULL,
    voxel_size_z_mm NUMERIC(4, 2) NOT NULL,
    matrix_x INT NOT NULL,
    matrix_y INT NOT NULL,
    slices_count INT NOT NULL,
    dicom_series_uid VARCHAR(120) NOT NULL UNIQUE,
    bids_relative_path VARCHAR(255) NOT NULL UNIQUE,
    file_size_bytes BIGINT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_scans_participant FOREIGN KEY (participant_id) 
        REFERENCES participants(participant_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_scans_scanner FOREIGN KEY (scanner_id) 
        REFERENCES mri_scanners(scanner_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_scans_project FOREIGN KEY (project_id) 
        REFERENCES research_projects(project_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_scans_sequence CHECK (
        sequence_type IN ('T1w', 'T2w', 'FLAIR', 'dMRI', 'fMRI-rest', 'fMRI-task', 'MRA')
    ),
    CONSTRAINT ck_scans_tr CHECK (repetition_time_ms > 0),
    CONSTRAINT ck_scans_te CHECK (echo_time_ms > 0),
    CONSTRAINT ck_scans_flip CHECK (flip_angle_deg IS NULL OR (flip_angle_deg > 0 AND flip_angle_deg <= 180)),
    CONSTRAINT ck_scans_voxel CHECK (voxel_size_x_mm > 0 AND voxel_size_y_mm > 0 AND voxel_size_z_mm > 0),
    CONSTRAINT ck_scans_matrix CHECK (matrix_x > 0 AND matrix_y > 0 AND slices_count > 0),
    CONSTRAINT ck_scans_size CHECK (file_size_bytes > 0)
);

COMMENT ON TABLE mri_scans IS 'Neuroimaging scan acquisition records conforming to BIDS directory structuring.';
COMMENT ON COLUMN mri_scans.bids_relative_path IS 'Brain Imaging Data Structure (BIDS) relative filepath on the file storage layer.';
COMMENT ON COLUMN mri_scans.dicom_series_uid IS 'Globally unique DICOM Series Instance UID (0020,000E).';

-- ============================================================================
-- 9. PROCESSING PIPELINES (Neuroinformatics Algorithms & Containers)
-- ============================================================================
CREATE TABLE processing_pipelines (
    pipeline_id VARCHAR(25) PRIMARY KEY,
    name VARCHAR(80) NOT NULL,
    version VARCHAR(30) NOT NULL,
    container_image VARCHAR(150) NOT NULL,
    target_sequence VARCHAR(25) NOT NULL,
    description TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT uq_pipeline_name_version UNIQUE (name, version),
    CONSTRAINT ck_pipelines_sequence CHECK (
        target_sequence IN ('T1w', 'T2w', 'FLAIR', 'dMRI', 'fMRI-rest', 'fMRI-task', 'MRA', 'MULTI')
    )
);

COMMENT ON TABLE processing_pipelines IS 'Registered neuroinformatics workflow pipelines (FreeSurfer, FSL, QSIPrep, etc.).';

-- ============================================================================
-- 10. PROCESSING JOBS (HPC / Cloud Batch Computational Executions)
-- ============================================================================
CREATE TABLE processing_jobs (
    job_id BIGSERIAL PRIMARY KEY,
    scan_id VARCHAR(30) NOT NULL,
    pipeline_id VARCHAR(25) NOT NULL,
    submitted_by_id VARCHAR(20) NOT NULL,
    submission_time TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    start_time TIMESTAMPTZ,
    end_time TIMESTAMPTZ,
    status VARCHAR(20) DEFAULT 'PENDING' NOT NULL,
    exit_code INT,
    compute_node VARCHAR(80),
    output_directory VARCHAR(255),
    error_message TEXT,
    CONSTRAINT fk_jobs_scan FOREIGN KEY (scan_id) 
        REFERENCES mri_scans(scan_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_jobs_pipeline FOREIGN KEY (pipeline_id) 
        REFERENCES processing_pipelines(pipeline_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_jobs_submitter FOREIGN KEY (submitted_by_id) 
        REFERENCES researchers(researcher_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_jobs_status CHECK (
        status IN ('PENDING', 'RUNNING', 'COMPLETED', 'FAILED', 'CANCELLED')
    ),
    CONSTRAINT ck_jobs_chronology CHECK (
        (start_time IS NULL OR start_time >= submission_time) AND
        (end_time IS NULL OR (start_time IS NOT NULL AND end_time >= start_time))
    )
);

COMMENT ON TABLE processing_jobs IS 'Asynchronous batch processing jobs dispatched to compute nodes for feature extraction.';

-- ============================================================================
-- 11. QUALITY CONTROL (QC) EVALUATIONS (Expert & Automated Metrics)
-- ============================================================================
CREATE TABLE qc_evaluations (
    qc_id BIGSERIAL PRIMARY KEY,
    scan_id VARCHAR(30) NOT NULL,
    evaluator_id VARCHAR(20) NOT NULL,
    evaluation_date TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    overall_quality VARCHAR(10) NOT NULL,
    snr_score NUMERIC(6, 2) NOT NULL,
    cnr_score NUMERIC(6, 2) NOT NULL,
    head_motion_fd_mean_mm NUMERIC(5, 3) NOT NULL,
    usable_for_analysis BOOLEAN DEFAULT TRUE NOT NULL,
    artifact_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_qc_scan FOREIGN KEY (scan_id) 
        REFERENCES mri_scans(scan_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_qc_evaluator FOREIGN KEY (evaluator_id) 
        REFERENCES researchers(researcher_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_qc_quality CHECK (overall_quality IN ('PASS', 'WARN', 'FAIL')),
    CONSTRAINT ck_qc_snr CHECK (snr_score >= 0),
    CONSTRAINT ck_qc_cnr CHECK (cnr_score >= 0),
    CONSTRAINT ck_qc_fd CHECK (head_motion_fd_mean_mm >= 0),
    CONSTRAINT uq_qc_scan_evaluator UNIQUE (scan_id, evaluator_id)
);

COMMENT ON TABLE qc_evaluations IS 'Radiological and automated image quality assessments (SNR, CNR, framewise displacement).';

-- ============================================================================
-- INDEXING STRATEGY (Foundational Relational Optimization)
-- ============================================================================
-- Foreign key indexing for performant joins
CREATE INDEX idx_scanners_site ON mri_scanners(site_id);
CREATE INDEX idx_researchers_site ON researchers(affiliation_site_id);
CREATE INDEX idx_projects_pi ON research_projects(principal_investigator_id);
CREATE INDEX idx_participants_site ON participants(primary_site_id);
CREATE INDEX idx_ptdx_participant ON participant_diagnoses(participant_id);
CREATE INDEX idx_ptdx_diagnosis ON participant_diagnoses(diagnosis_code);
CREATE INDEX idx_scans_participant ON mri_scans(participant_id);
CREATE INDEX idx_scans_scanner ON mri_scans(scanner_id);
CREATE INDEX idx_scans_project ON mri_scans(project_id);
CREATE INDEX idx_jobs_scan ON processing_jobs(scan_id);
CREATE INDEX idx_jobs_pipeline ON processing_jobs(pipeline_id);
CREATE INDEX idx_jobs_status ON processing_jobs(status);
CREATE INDEX idx_qc_scan ON qc_evaluations(scan_id);

-- Analytical filtering composite and partial indexes
CREATE INDEX idx_scans_seq_date ON mri_scans(sequence_type, acquisition_date DESC);
CREATE INDEX idx_qc_quality_usable ON qc_evaluations(overall_quality, usable_for_analysis);
