-- ============================================================================
-- MIT 8103: Advanced Database Systems
-- Continuous Assessment (CA) - September Cohort 2026
-- Student: Patrick Filima
-- Institution: Miva Open University
-- Portfolio 1: Database Design and Modelling
-- File: seed_data.sql
-- 
-- System: African Neuroimaging Research Data Management System (ANRDMS)
-- Target DBMS: PostgreSQL 14+
-- Description: Realistic synthetic data simulating multi-site clinical and
--              research neuroimaging cohorts across Nigerian healthcare centres.
-- ============================================================================

-- ============================================================================
-- 1. SEED RESEARCH SITES
-- ============================================================================
INSERT INTO research_sites (site_id, hospital_name, city, state, tier, contact_email, phone_number, is_active) VALUES
('SITE-LOS-01', 'Lagos University Teaching Hospital (LUTH)', 'Idi-Araba, Lagos', 'Lagos State', 'University Teaching Hospital', 'mri.research@luth.edu.ng', '+234-1-8445100', TRUE),
('SITE-ABJ-01', 'National Hospital Abuja (NHA)', 'Central Business District', 'FCT Abuja', 'Specialist Research Institute', 'radiology.trials@nationalhospital.gov.ng', '+234-9-2914000', TRUE),
('SITE-IBD-01', 'University College Hospital (UCH)', 'Ibadan', 'Oyo State', 'University Teaching Hospital', 'neuroimaging.center@uch-ibadan.org.ng', '+234-2-2410088', TRUE),
('SITE-ENU-01', 'University of Nigeria Teaching Hospital (UNTH)', 'Ituku-Ozalla, Enugu', 'Enugu State', 'University Teaching Hospital', 'imaging.cohorts@unth.edu.ng', '+234-42-252111', TRUE),
('SITE-ZAR-01', 'Ahmadu Bello University Teaching Hospital (ABUTH)', 'Shika, Zaria', 'Kaduna State', 'University Teaching Hospital', 'neuroscience.data@abuth.gov.ng', '+234-69-550123', TRUE);

-- ============================================================================
-- 2. SEED MRI SCANNERS
-- ============================================================================
INSERT INTO mri_scanners (scanner_id, site_id, manufacturer, model_name, magnetic_field_strength_tesla, gradient_strength_mt_m, software_version, installation_date, last_calibration_date, is_operational) VALUES
('SCN-LOS-3T01', 'SITE-LOS-01', 'Siemens Healthineers', 'MAGNETOM Skyra', 3.0, 45.00, 'Syngo MR E11C', '2021-03-15', '2026-08-10', TRUE),
('SCN-LOS-15T1', 'SITE-LOS-01', 'GE Healthcare', 'Signa Explorer', 1.5, 33.00, 'DV26.0_R03', '2019-07-22', '2026-07-05', TRUE),
('SCN-ABJ-3T01', 'SITE-ABJ-01', 'Siemens Healthineers', 'MAGNETOM Prisma', 3.0, 80.00, 'Syngo MR XA30A', '2022-11-01', '2026-09-12', TRUE),
('SCN-IBD-3T01', 'SITE-IBD-01', 'GE Healthcare', 'Signa Pioneer', 3.0, 44.00, 'DV29.1_R01', '2020-09-18', '2026-08-25', TRUE),
('SCN-ENU-15T1', 'SITE-ENU-01', 'Philips Healthcare', 'Achieva dStream', 1.5, 33.00, 'Release 5.4.1', '2018-05-10', '2026-06-30', TRUE),
('SCN-ZAR-15T1', 'SITE-ZAR-01', 'Siemens Healthineers', 'MAGNETOM Amira', 1.5, 33.00, 'Syngo MR E11E', '2021-01-14', '2026-05-18', TRUE);

-- ============================================================================
-- 3. SEED RESEARCHERS
-- ============================================================================
INSERT INTO researchers (researcher_id, full_name, email, affiliation_site_id, role, orcid) VALUES
('RES-001', 'Prof. Amina Bello', 'amina.bello@luth.edu.ng', 'SITE-LOS-01', 'Principal Investigator', '0000-0002-1825-0097'),
('RES-002', 'Dr. Chukwudi Okafor', 'c.okafor@uch-ibadan.org.ng', 'SITE-IBD-01', 'Radiologist', '0000-0001-9234-551X'),
('RES-003', 'Dr. Zainab Danjuma', 'z.danjuma@abuth.gov.ng', 'SITE-ZAR-01', 'Neuroimaging Analyst', '0000-0003-4412-8876'),
('RES-004', 'Patrick Filima', 'p.filima@anrdms.research.ng', 'SITE-LOS-01', 'Data Manager', '0000-0002-9901-4321'),
('RES-005', 'Dr. Emeka Nnamani', 'e.nnamani@unth.edu.ng', 'SITE-ENU-01', 'Radiologist', '0000-0001-7788-9900'),
('RES-006', 'Dr. Fatima Garba', 'fatima.garba@nationalhospital.gov.ng', 'SITE-ABJ-01', 'Principal Investigator', '0000-0002-3344-5566'),
('RES-007', 'Olumide Adeleke', 'o.adeleke@luth.edu.ng', 'SITE-LOS-01', 'Neuroimaging Analyst', '0000-0003-1122-3344'),
('RES-008', 'Dr. Ifeoma Eze', 'ifeoma.eze@unth.edu.ng', 'SITE-ENU-01', 'Clinical Research Coordinator', '0000-0002-5566-7788');

-- ============================================================================
-- 4. SEED RESEARCH PROJECTS
-- ============================================================================
INSERT INTO research_projects (project_id, project_name, principal_investigator_id, funding_agency, ethics_approval_code, start_date, end_date, status) VALUES
('PRJ-ABHI-2025', 'African Brain Health & Healthy Ageing Initiative', 'RES-001', 'Wellcome Trust & TETFund', 'NHREC/01/01/2025-104A', '2025-01-01', '2028-12-31', 'ACTIVE'),
('PRJ-WASCS-2024', 'West African Stroke Cohort Study', 'RES-006', 'National Institutes of Health (Fogarty)', 'NHREC/01/01/2024-883B', '2024-03-01', '2027-02-28', 'ACTIVE'),
('PRJ-SSADG-2026', 'Sub-Saharan Alzheimer''s Disease Biomarker Study', 'RES-001', 'African Academy of Sciences', 'NHREC/01/01/2026-019C', '2026-01-15', '2029-01-14', 'ACTIVE'),
('PRJ-NPEPP-2025', 'Nigerian Pediatric Epilepsy Neuroimaging Project', 'RES-006', 'Gates Foundation & Tertiary Healthcare Fund', 'NHREC/01/01/2025-412D', '2025-06-01', '2027-05-31', 'ACTIVE');

-- ============================================================================
-- 5. SEED PARTICIPANTS (Synthetic cohort)
-- ============================================================================
INSERT INTO participants (participant_id, primary_site_id, enrollment_date, birth_year, biological_sex, handedness, education_years, consent_obtained) VALUES
('ANRDMS-LOS-001', 'SITE-LOS-01', '2025-02-10', 1968, 'Female', 'Right', 16, TRUE),
('ANRDMS-LOS-002', 'SITE-LOS-01', '2025-02-15', 1954, 'Male',   'Right', 12, TRUE),
('ANRDMS-LOS-003', 'SITE-LOS-01', '2025-03-01', 1975, 'Female', 'Left',  18, TRUE),
('ANRDMS-LOS-004', 'SITE-LOS-01', '2025-03-12', 1982, 'Male',   'Right', 14, TRUE),
('ANRDMS-LOS-005', 'SITE-LOS-01', '2025-04-05', 1961, 'Female', 'Right', 6,  TRUE),
('ANRDMS-ABJ-001', 'SITE-ABJ-01', '2025-02-18', 1970, 'Male',   'Right', 16, TRUE),
('ANRDMS-ABJ-002', 'SITE-ABJ-01', '2025-02-22', 1959, 'Female', 'Right', 12, TRUE),
('ANRDMS-ABJ-003', 'SITE-ABJ-01', '2025-03-10', 1988, 'Male',   'Ambidextrous', 20, TRUE),
('ANRDMS-ABJ-004', 'SITE-ABJ-01', '2025-04-02', 1965, 'Female', 'Right', 10, TRUE),
('ANRDMS-ABJ-005', 'SITE-ABJ-01', '2025-05-14', 1979, 'Male',   'Left',  16, TRUE),
('ANRDMS-IBD-001', 'SITE-IBD-01', '2025-01-20', 1951, 'Female', 'Right', 8,  TRUE),
('ANRDMS-IBD-002', 'SITE-IBD-01', '2025-02-04', 1963, 'Male',   'Right', 16, TRUE),
('ANRDMS-IBD-003', 'SITE-IBD-01', '2025-03-15', 1974, 'Female', 'Right', 14, TRUE),
('ANRDMS-IBD-004', 'SITE-IBD-01', '2025-04-18', 1985, 'Male',   'Right', 18, TRUE),
('ANRDMS-IBD-005', 'SITE-IBD-01', '2025-05-20', 1992, 'Female', 'Left',  16, TRUE),
('ANRDMS-ENU-001', 'SITE-ENU-01', '2025-02-12', 1960, 'Male',   'Right', 11, TRUE),
('ANRDMS-ENU-002', 'SITE-ENU-01', '2025-03-08', 1972, 'Female', 'Right', 15, TRUE),
('ANRDMS-ENU-003', 'SITE-ENU-01', '2025-04-01', 1958, 'Male',   'Right', 9,  TRUE),
('ANRDMS-ENU-004', 'SITE-ENU-01', '2025-04-29', 1980, 'Female', 'Right', 17, TRUE),
('ANRDMS-ENU-005', 'SITE-ENU-01', '2025-06-11', 1967, 'Male',   'Left',  13, TRUE),
('ANRDMS-ZAR-001', 'SITE-ZAR-01', '2025-03-02', 1971, 'Female', 'Right', 12, TRUE),
('ANRDMS-ZAR-002', 'SITE-ZAR-01', '2025-03-25', 1955, 'Male',   'Right', 6,  TRUE),
('ANRDMS-ZAR-003', 'SITE-ZAR-01', '2025-04-14', 1983, 'Female', 'Right', 16, TRUE),
('ANRDMS-ZAR-004', 'SITE-ZAR-01', '2025-05-02', 1966, 'Male',   'Right', 14, TRUE),
('ANRDMS-ZAR-005', 'SITE-ZAR-01', '2025-06-19', 1977, 'Female', 'Left',  15, TRUE);

-- ============================================================================
-- 6. SEED NEUROLOGICAL DIAGNOSES
-- ============================================================================
INSERT INTO neurological_diagnoses (diagnosis_code, condition_name, category, icd11_code, description) VALUES
('DX-CTL-001', 'Cognitively Unimpaired Healthy Control', 'Healthy Control', 'QA00', 'Normative neuroimaging reference cohort without neurological symptoms.'),
('DX-STR-001', 'Acute Ischemic Stroke', 'Cerebrovascular', '8B11', 'Focal cerebral infarction resulting from vascular occlusion.'),
('DX-STR-002', 'Intracerebral Hemorrhage', 'Cerebrovascular', '8B00', 'Non-traumatic spontaneous extravasation of blood into the brain parenchyma.'),
('DX-DEM-001', 'Early-Onset Alzheimer''s Dementia', 'Neurodegenerative', '8A20', 'Progressive cortical neurodegeneration characterized by memory impairment.'),
('DX-DEM-002', 'Vascular Dementia', 'Neurodegenerative', '8A21', 'Dementia resulting from ischemic or hemorrhagic cerebrovascular disease.'),
('DX-EPI-001', 'Temporal Lobe Epilepsy with Hippocampal Sclerosis', 'Epilepsy & Seizures', '8A62', 'Focal onset epilepsy characterized by mesial temporal sclerosis.'),
('DX-PD-001',  'Idiopathic Parkinson''s Disease', 'Neurodegenerative', '8A00.0', 'Neurodegenerative disorder of dopamine-producing neurons in substantia nigra.');

-- ============================================================================
-- 7. SEED PARTICIPANT DIAGNOSES
-- ============================================================================
INSERT INTO participant_diagnoses (participant_id, diagnosis_code, diagnosing_researcher_id, diagnosis_date, severity_stage, is_primary_diagnosis, clinical_notes) VALUES
('ANRDMS-LOS-001', 'DX-STR-001', 'RES-002', '2025-02-12', 'Moderate', TRUE, 'Middle cerebral artery territory infarction with contralateral weakness.'),
('ANRDMS-LOS-002', 'DX-DEM-002', 'RES-002', '2025-02-18', 'Mild', TRUE, 'Multi-infarct vascular dementia, MoCA score 21/30.'),
('ANRDMS-LOS-003', 'DX-CTL-001', 'RES-001', '2025-03-03', 'Not Applicable', TRUE, 'Healthy control, normal structural baseline.'),
('ANRDMS-LOS-004', 'DX-EPI-001', 'RES-002', '2025-03-15', 'Moderate', TRUE, 'Refractory left mesial temporal lobe seizures.'),
('ANRDMS-LOS-005', 'DX-DEM-001', 'RES-001', '2025-04-08', 'Severe', TRUE, 'Familial early-onset presentation, CDR score 2.0.'),
('ANRDMS-ABJ-001', 'DX-STR-001', 'RES-006', '2025-02-20', 'Mild', TRUE, 'Subcortical lacunar infarction, NIHSS score 4.'),
('ANRDMS-ABJ-002', 'DX-DEM-001', 'RES-006', '2025-02-26', 'Moderate', TRUE, 'Progressive episodic amnesia over 18 months.'),
('ANRDMS-ABJ-003', 'DX-CTL-001', 'RES-006', '2025-03-12', 'Not Applicable', TRUE, 'Volunteer control for normative fMRI resting state.'),
('ANRDMS-ABJ-004', 'DX-PD-001',  'RES-006', '2025-04-05', 'Mild', TRUE, 'Asymmetric resting tremor and bradykinesia, Hoehn & Yahr stage 1.5.'),
('ANRDMS-ABJ-005', 'DX-EPI-001', 'RES-006', '2025-05-18', 'Mild', TRUE, 'Juvenile myoclonic epilepsy spectrum with nocturnal seizures.'),
('ANRDMS-IBD-001', 'DX-DEM-002', 'RES-002', '2025-01-25', 'Moderate', TRUE, 'Extensive white matter hyperintensities on FLAIR.'),
('ANRDMS-IBD-002', 'DX-STR-001', 'RES-002', '2025-02-08', 'Severe', TRUE, 'Large hemispheric stroke, intensive neuro-rehab participant.'),
('ANRDMS-IBD-003', 'DX-CTL-001', 'RES-002', '2025-03-20', 'Not Applicable', TRUE, 'Matched control subject for stroke cohort.'),
('ANRDMS-IBD-004', 'DX-PD-001',  'RES-002', '2025-04-22', 'Moderate', TRUE, 'Bilateral involvement, Hoehn & Yahr stage 2.'),
('ANRDMS-IBD-005', 'DX-CTL-001', 'RES-002', '2025-05-25', 'Not Applicable', TRUE, 'Healthy control, age 33, graduate student volunteer.'),
('ANRDMS-ENU-001', 'DX-STR-001', 'RES-005', '2025-02-15', 'Moderate', TRUE, 'Posterior circulation stroke with cerebellar ataxia.'),
('ANRDMS-ENU-002', 'DX-CTL-001', 'RES-005', '2025-03-10', 'Not Applicable', TRUE, 'Healthy control reference subject.'),
('ANRDMS-ENU-003', 'DX-DEM-001', 'RES-005', '2025-04-05', 'Moderate', TRUE, 'Rapid progressive cognitive decline, Mini-Mental 18/30.'),
('ANRDMS-ENU-004', 'DX-EPI-001', 'RES-005', '2025-05-02', 'Severe', TRUE, 'Drug-resistant temporal lobe epilepsy.'),
('ANRDMS-ENU-005', 'DX-STR-002', 'RES-005', '2025-06-15', 'Severe', TRUE, 'Deep basal ganglia hypertensive hemorrhage.'),
('ANRDMS-ZAR-001', 'DX-CTL-001', 'RES-003', '2025-03-05', 'Not Applicable', TRUE, 'Normative cohort baseline.'),
('ANRDMS-ZAR-002', 'DX-DEM-002', 'RES-003', '2025-03-28', 'Severe', TRUE, 'Subcortical ischemic vascular dementia.'),
('ANRDMS-ZAR-003', 'DX-CTL-001', 'RES-003', '2025-04-18', 'Not Applicable', TRUE, 'Control participant for healthy aging panel.'),
('ANRDMS-ZAR-004', 'DX-STR-001', 'RES-003', '2025-05-06', 'Moderate', TRUE, 'Embolic stroke secondary to atrial fibrillation.'),
('ANRDMS-ZAR-005', 'DX-EPI-001', 'RES-003', '2025-06-22', 'Mild', TRUE, 'Post-traumatic temporal lobe epilepsy with aura.');

-- ============================================================================
-- 8. SEED PROCESSING PIPELINES
-- ============================================================================
INSERT INTO processing_pipelines (pipeline_id, name, version, container_image, target_sequence, description, is_active) VALUES
('PIP-FS-741',     'FreeSurfer Cortical Reconstruction', '7.4.1',  'docker://freesurfer/freesurfer:7.4.1', 'T1w',        'Automated parcellation of cerebral cortex and subcortical volumetric segmentation.', TRUE),
('PIP-FSL-607',    'FSL Brain Extraction & FEAT',        '6.0.7',  'docker://brainlife/fsl:6.0.7',         'fMRI-rest',  'Motion correction, skull-stripping, spatial smoothing and ICA resting state analysis.', TRUE),
('PIP-QSIPREP-020','QSIPrep Diffusion Preprocessing',   '0.20.0', 'docker://pennbbl/qsiprep:0.20.0',      'dMRI',       'Comprehensive preprocessing, eddy-current correction and reconstruction for dMRI.', TRUE),
('PIP-FMRIPREP-23','fMRIPrep BIDS Pipeline',             '23.2.0', 'docker://nipreps/fmriprep:23.2.0',     'fMRI-rest',  'Robust BIDS-compliant preprocessing pipeline for functional MRI data.', TRUE),
('PIP-FLAIR-WML',  'BIANCA White Matter Lesion Tool',    '1.2.0',  'docker://brainlife/bianca:1.2.0',      'FLAIR',      'Automated segmentation of white matter hyperintensities in cerebral small vessel disease.', TRUE);

-- ============================================================================
-- 9. SEED MRI SCANS
-- ============================================================================
INSERT INTO mri_scans (scan_id, participant_id, scanner_id, project_id, acquisition_date, modality, sequence_type, repetition_time_ms, echo_time_ms, flip_angle_deg, voxel_size_x_mm, voxel_size_y_mm, voxel_size_z_mm, matrix_x, matrix_y, slices_count, dicom_series_uid, bids_relative_path, file_size_bytes) VALUES
-- LOS Participants
('SCN-LOS-001-T1',  'ANRDMS-LOS-001', 'SCN-LOS-3T01', 'PRJ-WASCS-2024', '2025-02-14 09:30:00+01', 'MRI', 'T1w',       2300.00, 2.98,  9.0, 1.00, 1.00, 1.00, 256, 256, 176, '1.3.12.2.1107.5.2.19.45012.20250214093001', 'sub-ANRDMSLOS001/ses-01/anat/sub-ANRDMSLOS001_ses-01_T1w.nii.gz',       18450120),
('SCN-LOS-001-FL',  'ANRDMS-LOS-001', 'SCN-LOS-3T01', 'PRJ-WASCS-2024', '2025-02-14 09:42:00+01', 'MRI', 'FLAIR',     9000.00, 85.00, 150.0, 0.90, 0.90, 3.00, 256, 256, 44,  '1.3.12.2.1107.5.2.19.45012.20250214094202', 'sub-ANRDMSLOS001/ses-01/anat/sub-ANRDMSLOS001_ses-01_FLAIR.nii.gz',     12320400),
('SCN-LOS-001-DM',  'ANRDMS-LOS-001', 'SCN-LOS-3T01', 'PRJ-WASCS-2024', '2025-02-14 09:55:00+01', 'MRI', 'dMRI',      3800.00, 75.00, 90.0,  2.00, 2.00, 2.00, 128, 128, 64,  '1.3.12.2.1107.5.2.19.45012.20250214095503', 'sub-ANRDMSLOS001/ses-01/dwi/sub-ANRDMSLOS001_ses-01_dwi.nii.gz',         95400100),
('SCN-LOS-002-T1',  'ANRDMS-LOS-002', 'SCN-LOS-3T01', 'PRJ-SSADG-2026', '2025-02-20 11:15:00+01', 'MRI', 'T1w',       2300.00, 2.98,  9.0, 1.00, 1.00, 1.00, 256, 256, 176, '1.3.12.2.1107.5.2.19.45012.20250220111501', 'sub-ANRDMSLOS002/ses-01/anat/sub-ANRDMSLOS002_ses-01_T1w.nii.gz',       18442100),
('SCN-LOS-002-FL',  'ANRDMS-LOS-002', 'SCN-LOS-3T01', 'PRJ-SSADG-2026', '2025-02-20 11:28:00+01', 'MRI', 'FLAIR',     9000.00, 85.00, 150.0, 0.90, 0.90, 3.00, 256, 256, 44,  '1.3.12.2.1107.5.2.19.45012.20250220112802', 'sub-ANRDMSLOS002/ses-01/anat/sub-ANRDMSLOS002_ses-01_FLAIR.nii.gz',     12318000),
('SCN-LOS-003-T1',  'ANRDMS-LOS-003', 'SCN-LOS-3T01', 'PRJ-ABHI-2025',  '2025-03-05 14:00:00+01', 'MRI', 'T1w',       2300.00, 2.98,  9.0, 1.00, 1.00, 1.00, 256, 256, 176, '1.3.12.2.1107.5.2.19.45012.20250305140001', 'sub-ANRDMSLOS003/ses-01/anat/sub-ANRDMSLOS003_ses-01_T1w.nii.gz',       18510000),
('SCN-LOS-003-FM',  'ANRDMS-LOS-003', 'SCN-LOS-3T01', 'PRJ-ABHI-2025',  '2025-03-05 14:18:00+01', 'MRI', 'fMRI-rest', 2000.00, 30.00, 75.0,  3.00, 3.00, 3.00, 64,  64,  36,  '1.3.12.2.1107.5.2.19.45012.20250305141802', 'sub-ANRDMSLOS003/ses-01/func/sub-ANRDMSLOS003_ses-01_task-rest_bold.nii.gz', 112000400),
('SCN-LOS-004-T1',  'ANRDMS-LOS-004', 'SCN-LOS-15T1', 'PRJ-NPEPP-2025', '2025-03-18 10:20:00+01', 'MRI', 'T1w',       1900.00, 3.20,  8.0, 1.00, 1.00, 1.20, 240, 240, 160, '1.2.840.113619.2.340.20250318102001.99',     'sub-ANRDMSLOS004/ses-01/anat/sub-ANRDMSLOS004_ses-01_T1w.nii.gz',       15800200),
('SCN-LOS-005-T1',  'ANRDMS-LOS-005', 'SCN-LOS-3T01', 'PRJ-SSADG-2026', '2025-04-10 15:40:00+01', 'MRI', 'T1w',       2300.00, 2.98,  9.0, 1.00, 1.00, 1.00, 256, 256, 176, '1.3.12.2.1107.5.2.19.45012.20250410154001', 'sub-ANRDMSLOS005/ses-01/anat/sub-ANRDMSLOS005_ses-01_T1w.nii.gz',       18390000),

-- ABJ Participants
('SCN-ABJ-001-T1',  'ANRDMS-ABJ-001', 'SCN-ABJ-3T01', 'PRJ-WASCS-2024', '2025-02-25 08:30:00+01', 'MRI', 'T1w',       2400.00, 2.22,  8.0, 0.80, 0.80, 0.80, 320, 320, 208, '1.3.12.2.1107.5.2.43.66011.20250225083001', 'sub-ANRDMSABJ001/ses-01/anat/sub-ANRDMSABJ001_ses-01_T1w.nii.gz',       28900400),
('SCN-ABJ-001-DM',  'ANRDMS-ABJ-001', 'SCN-ABJ-3T01', 'PRJ-WASCS-2024', '2025-02-25 08:48:00+01', 'MRI', 'dMRI',      3500.00, 72.00, 90.0,  1.70, 1.70, 1.70, 140, 140, 80,  '1.3.12.2.1107.5.2.43.66011.20250225084802', 'sub-ANRDMSABJ001/ses-01/dwi/sub-ANRDMSABJ001_ses-01_dwi.nii.gz',        145000200),
('SCN-ABJ-002-T1',  'ANRDMS-ABJ-002', 'SCN-ABJ-3T01', 'PRJ-SSADG-2026', '2025-03-02 10:00:00+01', 'MRI', 'T1w',       2400.00, 2.22,  8.0, 0.80, 0.80, 0.80, 320, 320, 208, '1.3.12.2.1107.5.2.43.66011.20250302100001', 'sub-ANRDMSABJ002/ses-01/anat/sub-ANRDMSABJ002_ses-01_T1w.nii.gz',       28850000),
('SCN-ABJ-002-FL',  'ANRDMS-ABJ-002', 'SCN-ABJ-3T01', 'PRJ-SSADG-2026', '2025-03-02 10:15:00+01', 'MRI', 'FLAIR',     9000.00, 81.00, 150.0, 0.90, 0.90, 3.00, 256, 256, 46,  '1.3.12.2.1107.5.2.43.66011.20250302101502', 'sub-ANRDMSABJ002/ses-01/anat/sub-ANRDMSABJ002_ses-01_FLAIR.nii.gz',     13400200),
('SCN-ABJ-003-T1',  'ANRDMS-ABJ-003', 'SCN-ABJ-3T01', 'PRJ-ABHI-2025',  '2025-03-16 13:30:00+01', 'MRI', 'T1w',       2400.00, 2.22,  8.0, 0.80, 0.80, 0.80, 320, 320, 208, '1.3.12.2.1107.5.2.43.66011.20250316133001', 'sub-ANRDMSABJ003/ses-01/anat/sub-ANRDMSABJ003_ses-01_T1w.nii.gz',       29100000),
('SCN-ABJ-003-FM',  'ANRDMS-ABJ-003', 'SCN-ABJ-3T01', 'PRJ-ABHI-2025',  '2025-03-16 13:50:00+01', 'MRI', 'fMRI-rest', 1800.00, 32.00, 70.0,  2.50, 2.50, 2.50, 80,  80,  50,  '1.3.12.2.1107.5.2.43.66011.20250316135002', 'sub-ANRDMSABJ003/ses-01/func/sub-ANRDMSABJ003_ses-01_task-rest_bold.nii.gz', 148000500),
('SCN-ABJ-004-T1',  'ANRDMS-ABJ-004', 'SCN-ABJ-3T01', 'PRJ-ABHI-2025',  '2025-04-10 11:00:00+01', 'MRI', 'T1w',       2400.00, 2.22,  8.0, 0.80, 0.80, 0.80, 320, 320, 208, '1.3.12.2.1107.5.2.43.66011.20250410110001', 'sub-ANRDMSABJ004/ses-01/anat/sub-ANRDMSABJ004_ses-01_T1w.nii.gz',       28950000),
('SCN-ABJ-005-T1',  'ANRDMS-ABJ-005', 'SCN-ABJ-3T01', 'PRJ-NPEPP-2025', '2025-05-22 15:10:00+01', 'MRI', 'T1w',       2400.00, 2.22,  8.0, 0.80, 0.80, 0.80, 320, 320, 208, '1.3.12.2.1107.5.2.43.66011.20250522151001', 'sub-ANRDMSABJ005/ses-01/anat/sub-ANRDMSABJ005_ses-01_T1w.nii.gz',       28800000),

-- IBD Participants
('SCN-IBD-001-T1',  'ANRDMS-IBD-001', 'SCN-IBD-3T01', 'PRJ-SSADG-2026', '2025-01-28 10:10:00+01', 'MRI', 'T1w',       2500.00, 3.10,  8.0, 1.00, 1.00, 1.00, 256, 256, 176, '1.2.840.113619.2.410.20250128101001.12',     'sub-ANRDMSIBD001/ses-01/anat/sub-ANRDMSIBD001_ses-01_T1w.nii.gz',       19100500),
('SCN-IBD-001-FL',  'ANRDMS-IBD-001', 'SCN-IBD-3T01', 'PRJ-SSADG-2026', '2025-01-28 10:25:00+01', 'MRI', 'FLAIR',     8500.00, 90.00, 140.0, 1.00, 1.00, 3.00, 240, 240, 42,  '1.2.840.113619.2.410.20250128102502.14',     'sub-ANRDMSIBD001/ses-01/anat/sub-ANRDMSIBD001_ses-01_FLAIR.nii.gz',     11900000),
('SCN-IBD-002-T1',  'ANRDMS-IBD-002', 'SCN-IBD-3T01', 'PRJ-WASCS-2024', '2025-02-12 11:45:00+01', 'MRI', 'T1w',       2500.00, 3.10,  8.0, 1.00, 1.00, 1.00, 256, 256, 176, '1.2.840.113619.2.410.20250212114501.21',     'sub-ANRDMSIBD002/ses-01/anat/sub-ANRDMSIBD002_ses-01_T1w.nii.gz',       19050000),
('SCN-IBD-002-DM',  'ANRDMS-IBD-002', 'SCN-IBD-3T01', 'PRJ-WASCS-2024', '2025-02-12 12:05:00+01', 'MRI', 'dMRI',      4100.00, 78.00, 90.0,  2.00, 2.00, 2.00, 128, 128, 68,  '1.2.840.113619.2.410.20250212120502.24',     'sub-ANRDMSIBD002/ses-01/dwi/sub-ANRDMSIBD002_ses-01_dwi.nii.gz',         98500000),
('SCN-IBD-003-T1',  'ANRDMS-IBD-003', 'SCN-IBD-3T01', 'PRJ-ABHI-2025',  '2025-03-24 14:15:00+01', 'MRI', 'T1w',       2500.00, 3.10,  8.0, 1.00, 1.00, 1.00, 256, 256, 176, '1.2.840.113619.2.410.20250324141501.35',     'sub-ANRDMSIBD003/ses-01/anat/sub-ANRDMSIBD003_ses-01_T1w.nii.gz',       19200000),
('SCN-IBD-004-T1',  'ANRDMS-IBD-004', 'SCN-IBD-3T01', 'PRJ-ABHI-2025',  '2025-04-26 09:20:00+01', 'MRI', 'T1w',       2500.00, 3.10,  8.0, 1.00, 1.00, 1.00, 256, 256, 176, '1.2.840.113619.2.410.20250426092001.42',     'sub-ANRDMSIBD004/ses-01/anat/sub-ANRDMSIBD004_ses-01_T1w.nii.gz',       18950000),
('SCN-IBD-005-T1',  'ANRDMS-IBD-005', 'SCN-IBD-3T01', 'PRJ-ABHI-2025',  '2025-05-28 16:00:00+01', 'MRI', 'T1w',       2500.00, 3.10,  8.0, 1.00, 1.00, 1.00, 256, 256, 176, '1.2.840.113619.2.410.20250528160001.51',     'sub-ANRDMSIBD005/ses-01/anat/sub-ANRDMSIBD005_ses-01_T1w.nii.gz',       19320000),

-- ENU Participants
('SCN-ENU-001-T1',  'ANRDMS-ENU-001', 'SCN-ENU-15T1', 'PRJ-WASCS-2024', '2025-02-18 10:30:00+01', 'MRI', 'T1w',       2000.00, 3.50,  8.0, 1.00, 1.00, 1.20, 240, 240, 150, '1.3.46.670589.11.710.20250218103001.01',     'sub-ANRDMSENU001/ses-01/anat/sub-ANRDMSENU001_ses-01_T1w.nii.gz',       15200000),
('SCN-ENU-001-FL',  'ANRDMS-ENU-001', 'SCN-ENU-15T1', 'PRJ-WASCS-2024', '2025-02-18 10:45:00+01', 'MRI', 'FLAIR',     8000.00, 100.00,120.0, 1.10, 1.10, 4.00, 220, 220, 36,  '1.3.46.670589.11.710.20250218104502.02',     'sub-ANRDMSENU001/ses-01/anat/sub-ANRDMSENU001_ses-01_FLAIR.nii.gz',     10100000),
('SCN-ENU-002-T1',  'ANRDMS-ENU-002', 'SCN-ENU-15T1', 'PRJ-ABHI-2025',  '2025-03-14 11:15:00+01', 'MRI', 'T1w',       2000.00, 3.50,  8.0, 1.00, 1.00, 1.20, 240, 240, 150, '1.3.46.670589.11.710.20250314111501.12',     'sub-ANRDMSENU002/ses-01/anat/sub-ANRDMSENU002_ses-01_T1w.nii.gz',       15150000),
('SCN-ENU-003-T1',  'ANRDMS-ENU-003', 'SCN-ENU-15T1', 'PRJ-SSADG-2026', '2025-04-10 14:00:00+01', 'MRI', 'T1w',       2000.00, 3.50,  8.0, 1.00, 1.00, 1.20, 240, 240, 150, '1.3.46.670589.11.710.20250410140001.21',     'sub-ANRDMSENU003/ses-01/anat/sub-ANRDMSENU003_ses-01_T1w.nii.gz',       15080000),
('SCN-ENU-004-T1',  'ANRDMS-ENU-004', 'SCN-ENU-15T1', 'PRJ-NPEPP-2025', '2025-05-08 12:40:00+01', 'MRI', 'T1w',       2000.00, 3.50,  8.0, 1.00, 1.00, 1.20, 240, 240, 150, '1.3.46.670589.11.710.20250508124001.31',     'sub-ANRDMSENU004/ses-01/anat/sub-ANRDMSENU004_ses-01_T1w.nii.gz',       15300000),
('SCN-ENU-005-T1',  'ANRDMS-ENU-005', 'SCN-ENU-15T1', 'PRJ-WASCS-2024', '2025-06-20 15:30:00+01', 'MRI', 'T1w',       2000.00, 3.50,  8.0, 1.00, 1.00, 1.20, 240, 240, 150, '1.3.46.670589.11.710.20250620153001.44',     'sub-ANRDMSENU005/ses-01/anat/sub-ANRDMSENU005_ses-01_T1w.nii.gz',       15110000),

-- ZAR Participants
('SCN-ZAR-001-T1',  'ANRDMS-ZAR-001', 'SCN-ZAR-15T1', 'PRJ-ABHI-2025',  '2025-03-08 09:15:00+01', 'MRI', 'T1w',       1950.00, 3.40,  8.0, 1.00, 1.00, 1.25, 240, 240, 144, '1.3.12.2.1107.5.2.22.55101.20250308091501', 'sub-ANRDMSZAR001/ses-01/anat/sub-ANRDMSZAR001_ses-01_T1w.nii.gz',       14800000),
('SCN-ZAR-002-T1',  'ANRDMS-ZAR-002', 'SCN-ZAR-15T1', 'PRJ-SSADG-2026', '2025-04-02 11:30:00+01', 'MRI', 'T1w',       1950.00, 3.40,  8.0, 1.00, 1.00, 1.25, 240, 240, 144, '1.3.12.2.1107.5.2.22.55101.20250402113001', 'sub-ANRDMSZAR002/ses-01/anat/sub-ANRDMSZAR002_ses-01_T1w.nii.gz',       14750000),
('SCN-ZAR-002-FL',  'ANRDMS-ZAR-002', 'SCN-ZAR-15T1', 'PRJ-SSADG-2026', '2025-04-02 11:45:00+01', 'MRI', 'FLAIR',     8800.00, 88.00, 145.0, 1.00, 1.00, 3.50, 220, 220, 38,  '1.3.12.2.1107.5.2.22.55101.20250402114502', 'sub-ANRDMSZAR002/ses-01/anat/sub-ANRDMSZAR002_ses-01_FLAIR.nii.gz',     10800000),
('SCN-ZAR-003-T1',  'ANRDMS-ZAR-003', 'SCN-ZAR-15T1', 'PRJ-ABHI-2025',  '2025-04-22 13:00:00+01', 'MRI', 'T1w',       1950.00, 3.40,  8.0, 1.00, 1.00, 1.25, 240, 240, 144, '1.3.12.2.1107.5.2.22.55101.20250422130001', 'sub-ANRDMSZAR003/ses-01/anat/sub-ANRDMSZAR003_ses-01_T1w.nii.gz',       14920000),
('SCN-ZAR-004-T1',  'ANRDMS-ZAR-004', 'SCN-ZAR-15T1', 'PRJ-WASCS-2024', '2025-05-12 10:15:00+01', 'MRI', 'T1w',       1950.00, 3.40,  8.0, 1.00, 1.00, 1.25, 240, 240, 144, '1.3.12.2.1107.5.2.22.55101.20250512101501', 'sub-ANRDMSZAR004/ses-01/anat/sub-ANRDMSZAR004_ses-01_T1w.nii.gz',       14690000),
('SCN-ZAR-005-T1',  'ANRDMS-ZAR-005', 'SCN-ZAR-15T1', 'PRJ-NPEPP-2025', '2025-06-25 14:40:00+01', 'MRI', 'T1w',       1950.00, 3.40,  8.0, 1.00, 1.00, 1.25, 240, 240, 144, '1.3.12.2.1107.5.2.22.55101.20250625144001', 'sub-ANRDMSZAR005/ses-01/anat/sub-ANRDMSZAR005_ses-01_T1w.nii.gz',       14830000);

-- ============================================================================
-- 10. SEED PROCESSING JOBS
-- ============================================================================
INSERT INTO processing_jobs (scan_id, pipeline_id, submitted_by_id, submission_time, start_time, end_time, status, exit_code, compute_node, output_directory, error_message) VALUES
('SCN-LOS-001-T1', 'PIP-FS-741',     'RES-004', '2025-02-14 10:10:00+01', '2025-02-14 10:15:00+01', '2025-02-14 16:45:00+01', 'COMPLETED', 0, 'node-gpu-01.luth.hpc', '/deriv/freesurfer/sub-ANRDMSLOS001', NULL),
('SCN-LOS-001-DM', 'PIP-QSIPREP-020','RES-007', '2025-02-14 11:00:00+01', '2025-02-14 11:05:00+01', '2025-02-14 14:30:00+01', 'COMPLETED', 0, 'node-gpu-02.luth.hpc', '/deriv/qsiprep/sub-ANRDMSLOS001', NULL),
('SCN-LOS-001-FL', 'PIP-FLAIR-WML',  'RES-007', '2025-02-14 11:30:00+01', '2025-02-14 11:32:00+01', '2025-02-14 12:15:00+01', 'COMPLETED', 0, 'node-cpu-01.luth.hpc', '/deriv/bianca/sub-ANRDMSLOS001', NULL),
('SCN-LOS-002-T1', 'PIP-FS-741',     'RES-004', '2025-02-20 12:00:00+01', '2025-02-20 12:05:00+01', '2025-02-20 18:35:00+01', 'COMPLETED', 0, 'node-gpu-01.luth.hpc', '/deriv/freesurfer/sub-ANRDMSLOS002', NULL),
('SCN-LOS-002-FL', 'PIP-FLAIR-WML',  'RES-007', '2025-02-20 12:15:00+01', '2025-02-20 12:20:00+01', '2025-02-20 13:00:00+01', 'COMPLETED', 0, 'node-cpu-02.luth.hpc', '/deriv/bianca/sub-ANRDMSLOS002', NULL),
('SCN-LOS-003-T1', 'PIP-FS-741',     'RES-004', '2025-03-05 14:30:00+01', '2025-03-05 14:35:00+01', '2025-03-05 21:00:00+01', 'COMPLETED', 0, 'node-gpu-03.luth.hpc', '/deriv/freesurfer/sub-ANRDMSLOS003', NULL),
('SCN-LOS-003-FM', 'PIP-FMRIPREP-23','RES-007', '2025-03-05 14:45:00+01', '2025-03-05 14:50:00+01', '2025-03-05 18:20:00+01', 'COMPLETED', 0, 'node-gpu-04.luth.hpc', '/deriv/fmriprep/sub-ANRDMSLOS003', NULL),
('SCN-LOS-004-T1', 'PIP-FS-741',     'RES-004', '2025-03-18 11:00:00+01', '2025-03-18 11:05:00+01', '2025-03-18 17:50:00+01', 'COMPLETED', 0, 'node-gpu-02.luth.hpc', '/deriv/freesurfer/sub-ANRDMSLOS004', NULL),
('SCN-LOS-005-T1', 'PIP-FS-741',     'RES-004', '2025-04-10 16:00:00+01', '2025-04-10 16:05:00+01', NULL,                       'FAILED',    137, 'node-gpu-01.luth.hpc', NULL, 'OOM Killer terminated process in recon-all stage 2.'),
('SCN-ABJ-001-T1', 'PIP-FS-741',     'RES-004', '2025-02-25 09:10:00+01', '2025-02-25 09:15:00+01', '2025-02-25 15:55:00+01', 'COMPLETED', 0, 'cloud-worker-01.nha',   '/deriv/freesurfer/sub-ANRDMSABJ001', NULL),
('SCN-ABJ-001-DM', 'PIP-QSIPREP-020','RES-003', '2025-02-25 09:30:00+01', '2025-02-25 09:35:00+01', '2025-02-25 13:10:00+01', 'COMPLETED', 0, 'cloud-worker-02.nha',   '/deriv/qsiprep/sub-ANRDMSABJ001', NULL),
('SCN-ABJ-002-T1', 'PIP-FS-741',     'RES-004', '2025-03-02 10:40:00+01', '2025-03-02 10:45:00+01', '2025-03-02 17:20:00+01', 'COMPLETED', 0, 'cloud-worker-01.nha',   '/deriv/freesurfer/sub-ANRDMSABJ002', NULL),
('SCN-ABJ-003-FM', 'PIP-FMRIPREP-23','RES-003', '2025-03-16 14:10:00+01', '2025-03-16 14:15:00+01', '2025-03-16 18:00:00+01', 'COMPLETED', 0, 'cloud-worker-03.nha',   '/deriv/fmriprep/sub-ANRDMSABJ003', NULL),
('SCN-ABJ-004-T1', 'PIP-FS-741',     'RES-004', '2025-04-10 11:30:00+01', '2025-04-10 11:35:00+01', '2025-04-10 18:10:00+01', 'COMPLETED', 0, 'cloud-worker-02.nha',   '/deriv/freesurfer/sub-ANRDMSABJ004', NULL),
('SCN-IBD-001-T1', 'PIP-FS-741',     'RES-004', '2025-01-28 11:00:00+01', '2025-01-28 11:05:00+01', '2025-01-28 17:40:00+01', 'COMPLETED', 0, 'uch-compute-01',       '/deriv/freesurfer/sub-ANRDMSIBD001', NULL),
('SCN-IBD-002-DM', 'PIP-QSIPREP-020','RES-007', '2025-02-12 12:30:00+01', '2025-02-12 12:35:00+01', '2025-02-12 16:15:00+01', 'COMPLETED', 0, 'uch-compute-02',       '/deriv/qsiprep/sub-ANRDMSIBD002', NULL),
('SCN-IBD-003-T1', 'PIP-FS-741',     'RES-004', '2025-03-24 14:40:00+01', '2025-03-24 14:45:00+01', '2025-03-24 21:10:00+01', 'COMPLETED', 0, 'uch-compute-01',       '/deriv/freesurfer/sub-ANRDMSIBD003', NULL),
('SCN-ENU-001-T1', 'PIP-FS-741',     'RES-004', '2025-02-18 11:10:00+01', '2025-02-18 11:15:00+01', '2025-02-18 18:00:00+01', 'COMPLETED', 0, 'unth-node-01',        '/deriv/freesurfer/sub-ANRDMSENU001', NULL),
('SCN-ENU-002-T1', 'PIP-FS-741',     'RES-004', '2025-03-14 11:45:00+01', '2025-03-14 11:50:00+01', '2025-03-14 18:25:00+01', 'COMPLETED', 0, 'unth-node-01',        '/deriv/freesurfer/sub-ANRDMSENU002', NULL),
('SCN-ZAR-001-T1', 'PIP-FS-741',     'RES-004', '2025-03-08 10:00:00+01', '2025-03-08 10:05:00+01', '2025-03-08 16:50:00+01', 'COMPLETED', 0, 'abuth-cluster-01',    '/deriv/freesurfer/sub-ANRDMSZAR001', NULL),
('SCN-ZAR-002-T1', 'PIP-FS-741',     'RES-004', '2025-04-02 12:10:00+01', '2025-04-02 12:15:00+01', '2025-04-02 19:00:00+01', 'COMPLETED', 0, 'abuth-cluster-01',    '/deriv/freesurfer/sub-ANRDMSZAR002', NULL),
('SCN-ENU-005-T1', 'PIP-FS-741',     'RES-004', '2025-06-20 16:00:00+01', '2025-06-20 16:05:00+01', NULL,                       'RUNNING',   NULL, 'unth-node-02',        NULL, NULL),
('SCN-ZAR-005-T1', 'PIP-FS-741',     'RES-004', '2025-06-25 15:00:00+01', NULL,                       NULL,                       'PENDING',   NULL, NULL,                  NULL, NULL);

-- ============================================================================
-- 11. SEED QUALITY CONTROL (QC) EVALUATIONS
-- ============================================================================
INSERT INTO qc_evaluations (scan_id, evaluator_id, evaluation_date, overall_quality, snr_score, cnr_score, head_motion_fd_mean_mm, usable_for_analysis, artifact_notes) VALUES
('SCN-LOS-001-T1',  'RES-002', '2025-02-14 17:00:00+01', 'PASS', 28.50, 3.40, 0.120, TRUE,  'Clean scan, sharp grey-white matter contrast. Well-demarcated MCA territory.'),
('SCN-LOS-001-FL',  'RES-002', '2025-02-14 17:15:00+01', 'PASS', 22.10, 2.80, 0.140, TRUE,  'Clear hyperintense infarct boundary without motion corruption.'),
('SCN-LOS-001-DM',  'RES-007', '2025-02-14 17:30:00+01', 'PASS', 19.80, 2.10, 0.160, TRUE,  'Diffusion tensor fit residuals within normal bounds.'),
('SCN-LOS-002-T1',  'RES-002', '2025-02-20 19:00:00+01', 'PASS', 27.20, 3.10, 0.180, TRUE,  'Mild age-related temporal lobe volume loss visible; excellent technical quality.'),
('SCN-LOS-002-FL',  'RES-002', '2025-02-20 19:15:00+01', 'PASS', 24.30, 2.90, 0.150, TRUE,  'Fazekas grade 2 deep white matter hyperintensities clearly segmented.'),
('SCN-LOS-003-T1',  'RES-002', '2025-03-05 21:15:00+01', 'PASS', 31.40, 3.80, 0.080, TRUE,  'Normative benchmark quality. No perceptible movement.'),
('SCN-LOS-003-FM',  'RES-007', '2025-03-05 21:30:00+01', 'PASS', 25.00, 2.60, 0.110, TRUE,  'Default Mode Network (DMN) coherence robust, FD < 0.2mm throughout run.'),
('SCN-LOS-004-T1',  'RES-002', '2025-03-18 18:10:00+01', 'WARN', 18.20, 2.05, 0.280, TRUE,  'Minor swallowing ghosting in anterior temporal pole; cortical parcel intact.'),
('SCN-LOS-005-T1',  'RES-002', '2025-04-10 16:30:00+01', 'FAIL', 11.50, 1.20, 0.650, FALSE, 'Excessive participant tremor artifacts. Not recommended for automated morphometry.'),
('SCN-ABJ-001-T1',  'RES-006', '2025-02-25 16:15:00+01', 'PASS', 34.80, 4.20, 0.070, TRUE,  'Prisma 3T high-resolution data; sub-millimeter isotropic resolution pristine.'),
('SCN-ABJ-001-DM',  'RES-003', '2025-02-25 16:30:00+01', 'PASS', 23.40, 2.70, 0.090, TRUE,  'Eddy current correction converged in 3 iterations. Excellent tractography substrate.'),
('SCN-ABJ-002-T1',  'RES-006', '2025-03-02 17:40:00+01', 'PASS', 33.10, 3.90, 0.110, TRUE,  'Bilateral hippocampal atrophy discernible without motion smear.'),
('SCN-ABJ-003-T1',  'RES-006', '2025-03-16 18:15:00+01', 'PASS', 35.60, 4.40, 0.060, TRUE,  'Exceptional SNR on 64-channel head coil.'),
('SCN-ABJ-003-FM',  'RES-003', '2025-03-16 18:30:00+01', 'PASS', 28.10, 3.00, 0.095, TRUE,  'fMRI resting state motion scrubbing excluded < 2% of volumes.'),
('SCN-IBD-001-T1',  'RES-002', '2025-01-28 18:00:00+01', 'PASS', 26.90, 3.15, 0.130, TRUE,  'Good SNR; minor bias field corrected during FreeSurfer Nu-correct.'),
('SCN-IBD-002-T1',  'RES-002', '2025-02-12 16:40:00+01', 'WARN', 19.50, 2.20, 0.240, TRUE,  'Hemiparetic patient restlessness; mild ringing on parietal vertex.'),
('SCN-ENU-001-T1',  'RES-005', '2025-02-18 18:15:00+01', 'PASS', 21.80, 2.50, 0.150, TRUE,  '1.5T Achieva acquisition within diagnostic protocol specifications.'),
('SCN-ENU-002-T1',  'RES-005', '2025-03-14 18:40:00+01', 'PASS', 22.40, 2.65, 0.120, TRUE,  'Normal healthy adult control structural acquisition.'),
('SCN-ZAR-001-T1',  'RES-003', '2025-03-08 17:10:00+01', 'PASS', 21.00, 2.45, 0.140, TRUE,  'Clean baseline scan from Zaria research cohort.'),
('SCN-ZAR-002-T1',  'RES-003', '2025-04-02 19:20:00+01', 'WARN', 17.80, 2.10, 0.270, TRUE,  'Moderate head motion; usable for manual volumetry but flagged for pipeline.');
