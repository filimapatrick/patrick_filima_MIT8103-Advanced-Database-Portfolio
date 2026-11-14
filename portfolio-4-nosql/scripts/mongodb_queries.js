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
//              negative validation tests, multikey execution plan capture,
//              and advanced multi-stage aggregation pipelines for BIDS metadata.
// ============================================================================

// Switch to ANRDMS NoSQL database (compatible with non-interactive mongosh execution)
db = db.getSiblingDB("anrdms_nosql");

// Drop collections if they exist to ensure clean, reproducible re-runs
db.scans_bids.drop();
db.pipeline_metrics.drop();

// ============================================================================
// 1. SCHEMA VALIDATION WITH $jsonSchema (DOCUMENT GOVERNANCE)
// ============================================================================
// Demonstrates that NoSQL in enterprise research is "schema-flexible" rather than
// "schema-less". Enforces mandatory research governance, participant identifiers,
// and physical scanner parameters (e.g. magnetic field 0.2T - 7.5T) while permitting
// sequence-specific polymorphic metadata (e.g. diffusion shells vs fMRI slice timing).
// ============================================================================

print("=== 1. CREATING COLLECTIONS WITH STRICT $jsonSchema VALIDATION ===");

// Collection 1: scans_bids
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
          description: "Must be a valid participant identifier conforming to site prefix"
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
              description: "Static magnetic field strength in Tesla (valid range: 0.2T - 7.5T)"
            }
          }
        }
      }
    }
  }
});

// Collection 2: pipeline_metrics
db.createCollection("pipeline_metrics", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["metric_id", "scan_id", "pipeline_info", "execution_metrics"],
      properties: {
        metric_id: {
          bsonType: "string",
          pattern: "^MET-[A-Z0-9-]+$",
          description: "Must be a valid ANRDMS metric identifier"
        },
        scan_id: {
          bsonType: "string",
          pattern: "^SCN-[A-Z]{3}-[0-9]{3}-[A-Z0-9]+$",
          description: "Foreign key reference to scan identifier"
        },
        pipeline_info: {
          bsonType: "object",
          required: ["pipeline_name"],
          properties: {
            pipeline_name: {
              enum: ["FreeSurfer", "FSL-TBSS", "QSIPrep", "fMRIPrep", "ANTs"],
              description: "Standard neuroimaging pipeline name"
            },
            version: {
              bsonType: "string"
            }
          }
        },
        execution_metrics: {
          bsonType: "object",
          required: ["runtime_seconds", "peak_ram_mb"],
          properties: {
            runtime_seconds: {
              bsonType: ["int", "double", "decimal"],
              minimum: 0,
              description: "Execution wall-clock time in seconds"
            },
            peak_ram_mb: {
              bsonType: ["int", "double", "decimal"],
              minimum: 0,
              description: "Peak RAM consumption in megabytes"
            }
          }
        }
      }
    }
  }
});
print("Collections scans_bids and pipeline_metrics created with validator constraints.");

// ============================================================================
// 2. INDEXING STRATEGY (MULTIKEY, COMPOUND & SPARSE INDEXES)
// ============================================================================

print("\n=== 2. CREATING SPECIALIZED NOSQL INDEXES ===");

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

print("Created 6 indexes across scans_bids and pipeline_metrics collections.");

// ============================================================================
// 3. AUTOMATED DOCUMENT INGESTION
// ============================================================================

print("\n=== 3. INGESTING HETEROGENEOUS BIDS DOCUMENTS ===");

const fs = require("fs");
const path = require("path");

function loadJsonDocument(fileName) {
  const candidatePaths = [
    path.join(__dirname, "..", "documents", fileName),
    path.join("portfolio-4-nosql", "documents", fileName),
    path.join("/Users/patrick/Downloads/patrick_filima_MIT8103-Advanced-Database-Portfolio/portfolio-4-nosql/documents", fileName)
  ];
  for (const p of candidatePaths) {
    if (fs.existsSync(p)) {
      return JSON.parse(fs.readFileSync(p, "utf8"));
    }
  }
  throw new Error("Could not find document file: " + fileName);
}

const scansData = loadJsonDocument("scans_bids.json");
const metricsData = loadJsonDocument("pipeline_metrics.json");

const scansResult = db.scans_bids.insertMany(scansData);
print("Successfully imported " + scansResult.insertedIds.length + " documents into scans_bids.");

const metricsResult = db.pipeline_metrics.insertMany(metricsData);
print("Successfully imported " + metricsResult.insertedIds.length + " documents into pipeline_metrics.");

// ============================================================================
// 4. NEGATIVE VALIDATION TESTS (GOVERNANCE & CONSTRAINT VERIFICATION)
// ============================================================================

print("\n=== 4. EXECUTING NEGATIVE VALIDATION TESTS ===");

// Test 1: Invalid static magnetic field strength (20.0T > 7.5T maximum threshold)
print("\n--- Negative Test 1: $jsonSchema Field Range Violation ---");
print("Attempting to insert scan with 20.0 Tesla magnetic field (limit: 0.2T - 7.5T)...");
try {
  db.scans_bids.insertOne({
    scan_id: "SCN-ERR-999-T1",
    participant_id: "ANRDMS-LOS-001",
    site_id: "SITE-LOS-01",
    modality: "MRI",
    sequence_type: "T1w",
    bids_metadata: { bids_version: "1.9.0" },
    scanner_hardware: {
      vendor: "Hypothetical Magnets",
      model: "Ultra-20T",
      magnetic_field_tesla: 20.0
    }
  });
  print("FAILURE: Document was accepted when schema should have rejected it!");
} catch (err) {
  print("EXPECTED REJECTION: Document failed $jsonSchema validation constraint.");
  print("Error code: " + err.code);
  print("Error name: " + err.name);
}

// Test 2: Duplicate scan_id (Unique Index Constraint Violation)
print("\n--- Negative Test 2: Unique Index Violation ---");
print("Attempting to insert duplicate scan_id 'SCN-LOS-001-T1'...");
try {
  db.scans_bids.insertOne({
    scan_id: "SCN-LOS-001-T1",
    participant_id: "ANRDMS-LOS-001",
    site_id: "SITE-LOS-01",
    modality: "MRI",
    sequence_type: "T1w",
    bids_metadata: { bids_version: "1.9.0" },
    scanner_hardware: {
      vendor: "Siemens Healthineers",
      model: "Magnetom Skyra",
      magnetic_field_tesla: 3.0
    }
  });
  print("FAILURE: Duplicate document was accepted!");
} catch (err) {
  print("EXPECTED REJECTION: Duplicate key rejected by unique index idx_scans_scan_id_unique.");
  print("Error code: " + err.code);
  print("Error message: " + err.message);
}

// ============================================================================
// 5. MULTIKEY INDEX QUERY EXECUTION PLAN (EXPLAIN EXECUTIONSTATS)
// ============================================================================

print("\n=== 5. MULTIKEY INDEX QUERY EXECUTION PLAN ===");
print("Analyzing execution plan for query on array element: diffusion_protocol.b_values = 2000");

const plan = db.scans_bids.find({ "diffusion_protocol.b_values": 2000 }).explain("executionStats");

print("\nQuery Planner Winning Plan:");
printjson({
  stage: plan.queryPlanner.winningPlan.stage,
  inputStage: plan.queryPlanner.winningPlan.inputStage ? {
    stage: plan.queryPlanner.winningPlan.inputStage.stage,
    indexName: plan.queryPlanner.winningPlan.inputStage.indexName,
    isMultiKey: plan.queryPlanner.winningPlan.inputStage.isMultiKey
  } : null
});

print("\nExecution Stats Summary:");
printjson({
  executionSuccess: plan.executionStats.executionSuccess,
  nReturned: plan.executionStats.nReturned,
  totalKeysExamined: plan.executionStats.totalKeysExamined,
  totalDocsExamined: plan.executionStats.totalDocsExamined,
  executionTimeMillis: plan.executionStats.executionTimeMillis
});


// ============================================================================
// 6. ADVANCED AGGREGATION PIPELINES
// ============================================================================

print("\n=== 6. EXECUTING ADVANCED AGGREGATION PIPELINES ===");

// ----------------------------------------------------------------------------
// PIPELINE 1: Subcortical Volumetric Atrophy across Clinical Cohorts
// Goal: Compare mean hippocampal volumes between Alzheimer's, Stroke, and Controls.
// ----------------------------------------------------------------------------
print("\n--- Pipeline 1: Subcortical Volumetric Atrophy across Clinical Cohorts ---");
const p1Results = db.pipeline_metrics.aggregate([
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
]).toArray();
printjson(p1Results);

// ----------------------------------------------------------------------------
// PIPELINE 2: Cortical Thinning Analysis via $unwind
// Goal: Measure localized cortical thinning in entorhinal cortex across cohorts.
// ----------------------------------------------------------------------------
print("\n--- Pipeline 2: Regional Cortical Thinning Analysis via $unwind ---");
const p2Results = db.pipeline_metrics.aggregate([
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
]).toArray();
printjson(p2Results);

// ----------------------------------------------------------------------------
// PIPELINE 3: Hardware & High-Dimensional BIDS Acquisition Query
// Goal: Filter multi-shell dMRI acquisitions with b-value=2000 on >=3.0T scanners.
// ----------------------------------------------------------------------------
print("\n--- Pipeline 3: Hardware & High-Dimensional BIDS Acquisition Query ---");
const p3Results = db.scans_bids.aggregate([
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
]).toArray();
printjson(p3Results);

// ----------------------------------------------------------------------------
// PIPELINE 4: Multi-Stage $facet Operational Analytics Dashboard
// Goal: Generate HPC compute performance and topological quality metrics in 1 pass.
// ----------------------------------------------------------------------------
print("\n--- Pipeline 4: Multi-Stage $facet Operational Analytics Dashboard ---");
const p4Results = db.pipeline_metrics.aggregate([
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
]).toArray();
printjson(p4Results);
print("\n=== MONGODB EXECUTION COMPLETE ===");
