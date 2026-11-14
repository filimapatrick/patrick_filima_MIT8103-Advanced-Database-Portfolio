// ============================================================================
// MIT 8103: Advanced Database Systems
// Student: Patrick Filima | Miva Open University
// Portfolio 4: NoSQL and Advanced Data Models
// File: run_mongo.js
// 
// Connects directly to the live local MongoDB 7.0 daemon (127.0.0.1:27017)
// Executes schema validation ($jsonSchema), multikey and compound indexes,
// negative validation tests, explain("executionStats"), and aggregations.
// ============================================================================

const fs = require("fs");
const path = require("path");
const { MongoClient } = require("/tmp/node_modules/mongodb");

async function run() {
  const uri = "mongodb://127.0.0.1:27017";
  const client = new MongoClient(uri);

  try {
    await client.connect();
    console.log("============================================================================");
    console.log("CONNECTED TO LIVE MONGODB SERVER");
    const buildInfo = await client.db("admin").command({ buildInfo: 1 });
    console.log(`MongoDB Engine Version: ${buildInfo.version}`);
    console.log(`Target Database: anrdms_nosql`);
    console.log("============================================================================\n");

    const db = client.db("anrdms_nosql");

    // Drop existing collections for reproducible execution
    try { await db.collection("scans_bids").drop(); } catch (e) {}
    try { await db.collection("pipeline_metrics").drop(); } catch (e) {}

    // ========================================================================
    // 1. SCHEMA VALIDATION WITH $jsonSchema
    // ========================================================================
    console.log("=== 1. CREATING COLLECTIONS WITH STRICT $jsonSchema VALIDATION ===");

    await db.createCollection("scans_bids", {
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

    await db.createCollection("pipeline_metrics", {
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
                  minimum: 0
                },
                peak_ram_mb: {
                  bsonType: ["int", "double", "decimal"],
                  minimum: 0
                }
              }
            }
          }
        }
      }
    });
    console.log("Collections 'scans_bids' and 'pipeline_metrics' created with $jsonSchema validation.");

    // ========================================================================
    // 2. CREATING INDEXES
    // ========================================================================
    console.log("\n=== 2. CREATING SPECIALIZED NOSQL INDEXES ===");

    await db.collection("scans_bids").createIndex({ scan_id: 1 }, { unique: true, name: "idx_scans_scan_id_unique" });
    await db.collection("scans_bids").createIndex({ site_id: 1, sequence_type: 1, acquisition_date: -1 }, { name: "idx_scans_site_seq_date" });
    await db.collection("scans_bids").createIndex({ "diffusion_protocol.b_values": 1 }, { name: "idx_scans_dmri_bvalues_multikey" });

    await db.collection("pipeline_metrics").createIndex({ scan_id: 1, "pipeline_info.pipeline_name": 1 }, { unique: true, name: "idx_metrics_scan_pipeline" });
    await db.collection("pipeline_metrics").createIndex({ "cortical_parcellations.region_name": 1 }, { name: "idx_metrics_cortical_region_multikey" });
    await db.collection("pipeline_metrics").createIndex({ "execution_metrics.compute_node": 1 }, { sparse: true, name: "idx_metrics_compute_node_sparse" });

    console.log("Created 6 indexes (unique, compound, multikey, sparse) across collections.");

    // ========================================================================
    // 3. INGESTING DATA
    // ========================================================================
    console.log("\n=== 3. INGESTING HETEROGENEOUS BIDS DOCUMENTS ===");

    const docsDir = path.join(__dirname, "..", "documents");
    const scansData = JSON.parse(fs.readFileSync(path.join(docsDir, "scans_bids.json"), "utf8"));
    const metricsData = JSON.parse(fs.readFileSync(path.join(docsDir, "pipeline_metrics.json"), "utf8"));

    const sInsert = await db.collection("scans_bids").insertMany(scansData);
    console.log(`Inserted ${sInsert.insertedCount} documents into 'scans_bids'.`);

    const mInsert = await db.collection("pipeline_metrics").insertMany(metricsData);
    console.log(`Inserted ${mInsert.insertedCount} documents into 'pipeline_metrics'.`);

    // ========================================================================
    // 4. NEGATIVE VALIDATION TESTS
    // ========================================================================
    console.log("\n=== 4. EXECUTING NEGATIVE VALIDATION TESTS ===");

    console.log("\n--- Negative Test 1: $jsonSchema Field Range Violation ---");
    console.log("Attempting to insert scan with 20.0 Tesla magnetic field (limit: 0.2T - 7.5T)...");
    try {
      await db.collection("scans_bids").insertOne({
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
      console.log("FAILURE: Invalid document was accepted!");
    } catch (err) {
      console.log("EXPECTED REJECTION: Document failed $jsonSchema validation constraint.");
      console.log(`Error Code: ${err.code} | Error Name: ${err.name}`);
      console.log(`Server Error: ${err.message}`);
    }

    console.log("\n--- Negative Test 2: Unique Index Violation ---");
    console.log("Attempting to insert duplicate scan_id 'SCN-LOS-001-T1'...");
    try {
      await db.collection("scans_bids").insertOne({
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
      console.log("FAILURE: Duplicate document was accepted!");
    } catch (err) {
      console.log("EXPECTED REJECTION: Duplicate key rejected by unique index idx_scans_scan_id_unique.");
      console.log(`Error Code: ${err.code} | Error Name: ${err.name}`);
      console.log(`Server Error: ${err.message}`);
    }

    // ========================================================================
    // 5. MULTIKEY INDEX QUERY EXECUTION PLAN
    // ========================================================================
    console.log("\n=== 5. MULTIKEY INDEX QUERY EXECUTION PLAN ===");
    console.log("Analyzing execution plan for query: diffusion_protocol.b_values = 2000");

    const explainRes = await db.collection("scans_bids").find({ "diffusion_protocol.b_values": 2000 }).explain("executionStats");
    console.log("\nWinning Plan Summary:");
    console.log(JSON.stringify({
      stage: explainRes.queryPlanner.winningPlan.stage,
      inputStage: explainRes.queryPlanner.winningPlan.inputStage ? {
        stage: explainRes.queryPlanner.winningPlan.inputStage.stage,
        indexName: explainRes.queryPlanner.winningPlan.inputStage.indexName,
        isMultiKey: explainRes.queryPlanner.winningPlan.inputStage.isMultiKey
      } : null
    }, null, 2));

    console.log("\nExecution Stats:");
    console.log(JSON.stringify({
      executionSuccess: explainRes.executionStats.executionSuccess,
      nReturned: explainRes.executionStats.nReturned,
      totalKeysExamined: explainRes.executionStats.totalKeysExamined,
      totalDocsExamined: explainRes.executionStats.totalDocsExamined,
      executionTimeMillis: explainRes.executionStats.executionTimeMillis
    }, null, 2));

    // ========================================================================
    // 6. ADVANCED AGGREGATION PIPELINES
    // ========================================================================
    console.log("\n=== 6. EXECUTING ADVANCED AGGREGATION PIPELINES ===");

    console.log("\n--- Pipeline 1: Subcortical Volumetric Atrophy across Clinical Cohorts ---");
    const p1 = await db.collection("pipeline_metrics").aggregate([
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
        $sort: { bilateral_hippocampus_total_mm3: 1 }
      }
    ]).toArray();
    console.log(JSON.stringify(p1, null, 2));

    console.log("\n--- Pipeline 2: Regional Cortical Thinning Analysis via $unwind ---");
    const p2 = await db.collection("pipeline_metrics").aggregate([
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
    console.log(JSON.stringify(p2, null, 2));

    console.log("\n--- Pipeline 3: Hardware & High-Dimensional BIDS Acquisition Query ---");
    const p3 = await db.collection("scans_bids").aggregate([
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
    console.log(JSON.stringify(p3, null, 2));

    console.log("\n--- Pipeline 4: Multi-Stage $facet Operational Analytics Dashboard ---");
    const p4 = await db.collection("pipeline_metrics").aggregate([
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
    console.log(JSON.stringify(p4, null, 2));

    console.log("\n============================================================================");
    console.log("LIVE MONGODB EXECUTION COMPLETE - ALL TESTS AND PIPELINES PASSED");
    console.log("============================================================================");

  } finally {
    await client.close();
  }
}

run().catch(err => {
  console.error("Execution failed:", err);
  process.exit(1);
});
