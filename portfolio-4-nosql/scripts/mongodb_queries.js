// ============================================================================
// MIT 8103: Advanced Database Systems
// Continuous Assessment (CA) - September Cohort 2026
// Student: Patrick Filima
// Institution: Miva Open University
// Portfolio 4: NoSQL and Advanced Data Models
// File: mongodb_queries.js
// 
// System: African Neuroimaging Research Data Management System (ANRDMS)
// Target Engine: MongoDB 6.0+ / mongosh
// Description: MongoDB schema validation, compound and multikey indexing,
//              and advanced multi-stage aggregation pipelines for BIDS metadata.
// ============================================================================

// Switch to ANRDMS NoSQL database
use anrdms_nosql;

// Drop collections if they exist to ensure clean re-runs
db.scans_bids.drop();
db.pipeline_metrics.drop();

// ============================================================================
// 1. SCHEMA VALIDATION WITH $jsonSchema (DOCUMENT GOVERNANCE)
// ============================================================================
// Demonstrates that NoSQL is "schema-flexible" rather than "schema-less".
// Enforces mandatory clinical and BIDS identifiers while permitting polymorphic
// sequence-specific parameters (e.g. diffusion vs functional protocols).
// ============================================================================

db.createCollection("scans_bids", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["scan_id", "participant_id", "site_id", "modality", "sequence_type", "bids_metadata", "scanner_hardware"],
      properties: {
        scan_id: {
          bsonType: "string",
          pattern: "^SCN-[A-Z]{3}-[0-9]{3}-[A-Z0-9]+$",
          description: "Must be a valid ANRDMS scan identifier (e.g. SCN-LOS-001-T1)"
        },
        participant_id: {
          bsonType: "string",
          pattern: "^ANRDMS-[A-Z]{3}-[0-9]{3}$",
          description: "Must be a valid participant identifier"
        },
        site_id: {
          bsonType: "string",
          description: "Research site hosting the acquisition"
        },
        sequence_type: {
          enum: ["T1w", "T2w", "FLAIR", "dMRI", "fMRI-rest", "fMRI-task", "MRA"],
          description: "Recognized BIDS MRI sequence classification"
        },
        scanner_hardware: {
          bsonType: "object",
          required: ["vendor", "model", "magnetic_field_tesla"],
          properties: {
            magnetic_field_tesla: {
              bsonType: ["double", "int", "decimal"],
              minimum: 0.2,
              maximum: 7.5,
              description: "Static magnetic field strength in Tesla"
            }
          }
        }
      }
    }
  }
});

// ============================================================================
// 2. INDEXING STRATEGY (MULTIKEY, COMPOUND & SPARSE INDEXES)
// ============================================================================

// Index 1: Unique primary key index on BIDS scan_id
db.scans_bids.createIndex({ "scan_id": 1 }, { unique: true, name: "idx_scans_scan_id_unique" });

// Index 2: Compound index for multi-site cohort queries
db.scans_bids.createIndex(
  { "site_id": 1, "sequence_type": 1, "acquisition_date": -1 },
  { name: "idx_scans_site_seq_date" }
);

// Index 3: Multikey index indexing elements of the diffusion b_values array
db.scans_bids.createIndex(
  { "diffusion_protocol.b_values": 1 },
  { name: "idx_scans_dmri_bvalues_multikey" }
);

// Index 4: Compound index on pipeline metrics
db.pipeline_metrics.createIndex(
  { "scan_id": 1, "pipeline_info.pipeline_name": 1 },
  { unique: true, name: "idx_metrics_scan_pipeline" }
);

// Index 5: Multikey index on nested cortical parcellation region names
db.pipeline_metrics.createIndex(
  { "cortical_parcellations.region_name": 1 },
  { name: "idx_metrics_cortical_region_multikey" }
);

// Index 6: Sparse index on HPC compute execution nodes
db.pipeline_metrics.createIndex(
  { "execution_metrics.compute_node": 1 },
  { sparse: true, name: "idx_metrics_compute_node_sparse" }
);


// ============================================================================
// 3. ADVANCED AGGREGATION PIPELINES
// ============================================================================

// ----------------------------------------------------------------------------
// PIPELINE 1: Subcortical Volumetric Atrophy across Clinical Cohorts
// Goal: Compare mean hippocampal volumes between Alzheimer's, Stroke, and Controls.
// ----------------------------------------------------------------------------
db.pipeline_metrics.aggregate([
  {
    $match: {
      "subcortical_structures": { $exists: true }
    }
  },
  {
    $group: {
      _id: "$clinical_cohort.condition_name",
      cohort_category: { $first: "$clinical_cohort.diagnosis_category" },
      scans_analyzed_count: { $sum: 1 },
      avg_left_hippocampus_mm3: { $avg: "$subcortical_structures.left_hippocampus_mm3" },
      avg_right_hippocampus_mm3: { $avg: "$subcortical_structures.right_hippocampus_mm3" },
      avg_ventricle_volume_mm3: { $avg: "$whole_brain_morphometry.ventricular_system_volume_mm3" }
    }
  },
  {
    $project: {
      condition: "$_id",
      cohort_category: 1,
      scans_analyzed_count: 1,
      avg_left_hippocampus_mm3: { $round: ["$avg_left_hippocampus_mm3", 1] },
      avg_right_hippocampus_mm3: { $round: ["$avg_right_hippocampus_mm3", 1] },
      bilateral_hippocampus_total_mm3: {
        $round: [{ $add: ["$avg_left_hippocampus_mm3", "$avg_right_hippocampus_mm3"] }, 1]
      },
      avg_ventricle_volume_mm3: { $round: ["$avg_ventricle_volume_mm3", 1] }
    }
  },
  {
    $sort: { bilateral_hippocampus_total_mm3: 1 } // Lower volumes indicate higher neurodegenerative atrophy
  }
]);

// ----------------------------------------------------------------------------
// PIPELINE 2: Cortical Thinning Analysis via $unwind
// Goal: Measure localized cortical thinning in entorhinal cortex across cohorts.
// ----------------------------------------------------------------------------
db.pipeline_metrics.aggregate([
  {
    $match: {
      "cortical_parcellations": { $exists: true }
    }
  },
  {
    $unwind: "$cortical_parcellations"
  },
  {
    $match: {
      "cortical_parcellations.region_name": { $in: ["entorhinal", "superiorfrontal"] }
    }
  },
  {
    $group: {
      _id: {
        region: "$cortical_parcellations.region_name",
        condition: "$clinical_cohort.condition_name"
      },
      sample_hemispheres_count: { $sum: 1 },
      mean_thickness_mm: { $avg: "$cortical_parcellations.mean_thickness_mm" },
      min_thickness_mm: { $min: "$cortical_parcellations.mean_thickness_mm" },
      max_thickness_mm: { $max: "$cortical_parcellations.mean_thickness_mm" }
    }
  },
  {
    $project: {
      _id: 0,
      anatomical_region: "$_id.region",
      clinical_condition: "$_id.condition",
      sample_count: "$sample_hemispheres_count",
      mean_thickness_mm: { $round: ["$mean_thickness_mm", 3] },
      min_thickness_mm: { $round: ["$min_thickness_mm", 3] },
      max_thickness_mm: { $round: ["$max_thickness_mm", 3] }
    }
  },
  {
    $sort: { anatomical_region: 1, mean_thickness_mm: 1 }
  }
]);

// ----------------------------------------------------------------------------
// PIPELINE 3: Hardware & High-Dimensional BIDS Acquisition Query
// Goal: Filter multi-shell dMRI acquisitions with b-value=2000 on >=3.0T scanners.
// ----------------------------------------------------------------------------
db.scans_bids.aggregate([
  {
    $match: {
      "modality": "MRI",
      "sequence_type": "dMRI",
      "scanner_hardware.magnetic_field_tesla": { $gte: 3.0 },
      "diffusion_protocol.b_values": 2000
    }
  },
  {
    $project: {
      _id: 0,
      scan_id: 1,
      participant_id: 1,
      site_id: 1,
      scanner_model: "$scanner_hardware.model",
      field_strength: "$scanner_hardware.magnetic_field_tesla",
      gradient_directions: "$diffusion_protocol.gradient_directions_count",
      b_shells: "$diffusion_protocol.b_values",
      phase_encoding: "$acquisition_parameters.phase_encoding_direction"
    }
  }
]);

// ----------------------------------------------------------------------------
// PIPELINE 4: Multi-Stage $facet Operational Analytics Dashboard
// Goal: Generate HPC compute performance and topological quality metrics in 1 pass.
// ----------------------------------------------------------------------------
db.pipeline_metrics.aggregate([
  {
    $facet: {
      "hpc_performance_by_pipeline": [
        {
          $group: {
            _id: "$pipeline_info.pipeline_name",
            total_jobs_run: { $sum: 1 },
            avg_runtime_hours: { $avg: { $divide: ["$execution_metrics.runtime_seconds", 3600] } },
            avg_peak_ram_gb: { $avg: { $divide: ["$execution_metrics.peak_ram_mb", 1024] } }
          }
        },
        {
          $project: {
            pipeline: "$_id",
            total_jobs_run: 1,
            avg_runtime_hours: { $round: ["$avg_runtime_hours", 2] },
            avg_peak_ram_gb: { $round: ["$avg_peak_ram_gb", 2] }
          }
        }
      ],
      "morphometric_surface_quality": [
        {
          $match: { "quality_metrics.euler_number_lh": { $exists: true } }
        },
        {
          $group: {
            _id: "$clinical_cohort.condition_name",
            avg_lh_euler: { $avg: "$quality_metrics.euler_number_lh" },
            avg_rh_euler: { $avg: "$quality_metrics.euler_number_rh" },
            avg_repaired_holes: { $avg: "$quality_metrics.surface_holes_repaired_count" },
            avg_cnr: { $avg: "$quality_metrics.contrast_to_noise_ratio" }
          }
        },
        {
          $project: {
            clinical_condition: "$_id",
            avg_lh_euler: { $round: ["$avg_lh_euler", 1] },
            avg_rh_euler: { $round: ["$avg_rh_euler", 1] },
            avg_repaired_holes: { $round: ["$avg_repaired_holes", 1] },
            avg_cnr: { $round: ["$avg_cnr", 2] }
          }
        }
      ]
    }
  }
]);
