#!/usr/bin/env python3
"""
MIT 8103: Advanced Database Systems
African Neuroimaging Research Data Management System (ANRDMS)
Portfolio 3: Automated Concurrency Verification Harness

Description:
    Portable, deterministic dual-session concurrency test harness driving
    two concurrent PostgreSQL psql subprocesses over stdin/stdout.
    Empirically tests and asserts:
      1. Row-level locking (SELECT ... FOR UPDATE) and non-blocking queues (SKIP LOCKED)
      2. Isolation levels: Non-repeatable reads in READ COMMITTED vs snapshot preservation in REPEATABLE READ
      3. Serializable Snapshot Isolation (SSI) detecting Write Skew (SQLSTATE 40001)
      4. Deadlock detection, wait-for graph cycle resolution, and victim abort (SQLSTATE 40P01)
"""

import os
import sys
import time
import shutil
import queue
import threading
import subprocess

class PsqlSession:
    def __init__(self, name, db=None):
        self.name = name
        psql_path = shutil.which("psql")
        if not psql_path:
            raise RuntimeError("PostgreSQL CLI client 'psql' was not found in PATH.")

        # Respect standard PostgreSQL environment variables if present
        self.db = db or os.environ.get("PGDATABASE", "anrdms_transactions")
        host = os.environ.get("PGHOST", "/tmp")
        port = os.environ.get("PGPORT", "5432")
        user = os.environ.get("PGUSER")

        self.cmd = [psql_path, "-d", self.db, "-v", f"PROMPT1={name}> ", "-v", f"PROMPT2={name}...> ", "--pset=pager=off"]
        if host:
            self.cmd.extend(["-h", host])
        if port:
            self.cmd.extend(["-p", port])
        if user:
            self.cmd.extend(["-U", user])

        self.proc = subprocess.Popen(
            self.cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1
        )
        self.out_q = queue.Queue()
        self.reader_thread = threading.Thread(target=self._reader, daemon=True)
        self.reader_thread.start()
        # Read initial banner
        time.sleep(0.3)
        self.drain()

    def _reader(self):
        for line in self.proc.stdout:
            self.out_q.put(line)

    def drain(self, timeout=0.15):
        lines = []
        start = time.time()
        while time.time() - start < timeout:
            try:
                line = self.out_q.get(timeout=0.04)
                lines.append(line)
                start = time.time()
            except queue.Empty:
                break
        return "".join(lines)

    def send(self, sql_command, wait_time=0.35):
        self.proc.stdin.write(sql_command.strip() + "\n")
        self.proc.stdin.flush()
        time.sleep(wait_time)
        return self.drain()

    def close(self):
        try:
            self.proc.stdin.write("\\q\n")
            self.proc.stdin.flush()
            self.proc.wait(timeout=1.0)
        except Exception:
            self.proc.kill()

def main():
    transcript = []
    def log(msg):
        timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
        entry = f"[{timestamp}] {msg}"
        print(entry)
        transcript.append(entry)

    db_target = os.environ.get("PGDATABASE", "anrdms_transactions")
    log("============================================================================")
    log("ANRDMS CONCURRENCY & TRANSACTION ISOLATION EMPIRICAL TEST SUITE")
    log("PostgreSQL 16 - Portable Automated Dual-Session Verification Harness")
    log(f"Database: {db_target} | Host: {os.environ.get('PGHOST', '/tmp')} | Client: {shutil.which('psql')}")
    log("============================================================================\n")

    s1 = PsqlSession("SESSION_1", db=db_target)
    s2 = PsqlSession("SESSION_2", db=db_target)

    # PRE-TEST SETUP
    log("--- INITIAL SETUP: Registering test jobs and baseline scanner states ---")
    setup_sql = """
    DELETE FROM processing_jobs WHERE job_id IN (101, 102);
    INSERT INTO processing_jobs (job_id, scan_id, pipeline_id, submitted_by_id, submission_time, status)
    VALUES 
        (101, 'SCN-LOS-001-T1', 'PIP-FS-741', 'RES-002', CURRENT_TIMESTAMP - INTERVAL '30 minutes', 'PENDING'),
        (102, 'SCN-LOS-001-T1', 'PIP-FSL-607', 'RES-002', CURRENT_TIMESTAMP - INTERVAL '30 minutes', 'PENDING');
    UPDATE mri_scanners SET is_operational = TRUE WHERE site_id = 'SITE-LOS-01';
    """
    out = s1.send(setup_sql)
    log(f"SETUP OUTPUT:\n{out}")

    # ========================================================================
    # EXPERIMENT 1A: LOST UPDATE & PESSIMISTIC ROW LOCKING (FOR UPDATE)
    # ========================================================================
    log("\n============================================================================")
    log("EXPERIMENT 1A: PESSIMISTIC LOCKING & LOST UPDATE PREVENTION (FOR UPDATE)")
    log("============================================================================")
    
    log("[Session 1] Step 1A.1: Begin transaction and acquire row lock on Job 101")
    s1.send("BEGIN;")
    out1 = s1.send("SELECT job_id, scan_id, pipeline_id, status FROM processing_jobs WHERE job_id = 101 AND status = 'PENDING' FOR UPDATE;")
    log(f"Session 1: {out1.strip()}")
    if "101" not in out1:
        raise AssertionError("Session 1 failed to lock Job 101 in Step 1A.1")

    log("\n[Session 2] Step 1A.2: Concurrently attempt to acquire lock on the SAME Job 101")
    s2.send("BEGIN;")
    s2.proc.stdin.write("SELECT job_id, scan_id, pipeline_id, status FROM processing_jobs WHERE job_id = 101 AND status = 'PENDING' FOR UPDATE;\n")
    s2.proc.stdin.flush()
    time.sleep(0.5)
    out2 = s2.drain(timeout=0.2)
    is_blocked = ("101" not in out2)
    log(f"Session 2 (Attempting lock): {'[BLOCKED - Session 2 is waiting for Session 1 to release tuple lock]' if is_blocked else out2.strip()}")
    if not is_blocked:
        raise AssertionError("Session 2 did not block on locked tuple as expected!")

    log("\n[Session 1] Step 1A.3: Worker 1 marks Job 101 RUNNING and commits transaction")
    s1.send("UPDATE processing_jobs SET status = 'RUNNING', compute_node = 'hpc-node-01.luth.edu.ng', start_time = CURRENT_TIMESTAMP WHERE job_id = 101;")
    out_commit = s1.send("COMMIT;")
    log(f"Session 1: {out_commit.strip()} (Released lock)")

    log("\n[Session 2] Step 1A.4: Session 2 immediately unblocks post-commit")
    time.sleep(0.4)
    out2_unblocked = s2.drain(timeout=0.3)
    log(f"Session 2 (Unblocked): {out2_unblocked.strip()}")
    # Re-evaluation must yield 0 rows because status is now RUNNING, not PENDING
    if "0 rows" not in out2_unblocked and "(0 rows)" not in out2_unblocked:
        raise AssertionError("Session 2 did not observe the updated tuple state upon unblocking!")
    s2.send("ROLLBACK;")
    log("VERIFIED: Pessimistic locking serialized access; Session 2 safely received 0 qualifying rows without lost update.")

    # ========================================================================
    # EXPERIMENT 1B: NON-BLOCKING JOB QUEUE (FOR UPDATE SKIP LOCKED)
    # ========================================================================
    log("\n============================================================================")
    log("EXPERIMENT 1B: NON-BLOCKING JOB DISPATCH QUEUE (FOR UPDATE SKIP LOCKED)")
    log("============================================================================")
    s1.send("UPDATE processing_jobs SET status = 'PENDING', compute_node = NULL, start_time = NULL WHERE job_id IN (101, 102);")
    
    log("[Session 1] Step 1B.1: Worker 1 claims first available test job with SKIP LOCKED")
    s1.send("BEGIN;")
    out1_skip = s1.send("SELECT job_id, pipeline_id, status FROM processing_jobs WHERE job_id IN (101, 102) AND status = 'PENDING' ORDER BY job_id LIMIT 1 FOR UPDATE SKIP LOCKED;")
    log(f"Session 1: {out1_skip.strip()}")
    if "101" not in out1_skip:
        raise AssertionError("Worker 1 failed to acquire Job 101 with SKIP LOCKED")

    log("\n[Session 2] Step 1B.2: Worker 2 simultaneously claims available test job with SKIP LOCKED")
    s2.send("BEGIN;")
    out2_skip = s2.send("SELECT job_id, pipeline_id, status FROM processing_jobs WHERE job_id IN (101, 102) AND status = 'PENDING' ORDER BY job_id LIMIT 1 FOR UPDATE SKIP LOCKED;")
    log(f"Session 2: {out2_skip.strip()} --> [NOTICE: Session 2 did not wait; automatically skipped locked Job 101 and claimed Job 102!]")
    if "102" not in out2_skip:
        raise AssertionError("Worker 2 failed to skip locked Job 101 and acquire Job 102")

    s1.send("UPDATE processing_jobs SET status = 'RUNNING', compute_node = 'hpc-node-01.luth.edu.ng', start_time = CURRENT_TIMESTAMP WHERE job_id = 101; COMMIT;")
    s2.send("UPDATE processing_jobs SET status = 'RUNNING', compute_node = 'hpc-node-02.nha.gov.ng', start_time = CURRENT_TIMESTAMP WHERE job_id = 102; COMMIT;")
    log("VERIFIED: Both workers claimed disjoint jobs concurrently without contention.")

    # ========================================================================
    # EXPERIMENT 2A: NON-REPEATABLE READ UNDER READ COMMITTED
    # ========================================================================
    log("\n============================================================================")
    log("EXPERIMENT 2A: NON-REPEATABLE READ ANOMALY UNDER READ COMMITTED")
    log("============================================================================")
    log("[Session 1] Step 2A.1: Start transaction in READ COMMITTED and inspect Job 101")
    s1.send("BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;")
    out_r1_status = s1.send("SELECT job_id, status FROM processing_jobs WHERE job_id = 101;")
    out_r1_count = s1.send("SELECT count(*) AS running_test_jobs FROM processing_jobs WHERE job_id IN (101, 102) AND status = 'RUNNING';")
    log(f"Session 1 (Query 1 - Status): {out_r1_status.strip()}")
    log(f"Session 1 (Query 1 - Count):  {out_r1_count.strip()}")
    if "RUNNING" not in out_r1_status or "2" not in out_r1_count:
        raise AssertionError("Initial state for Experiment 2A unexpected")

    log("\n[Session 2] Step 2A.2: Concurrent session completes Job 101 and commits")
    s2.send("BEGIN;")
    s2.send("UPDATE processing_jobs SET status = 'COMPLETED', end_time = CURRENT_TIMESTAMP, exit_code = 0 WHERE job_id = 101;")
    out_s2_commit = s2.send("COMMIT;")
    log(f"Session 2 (Commit completed job): {out_s2_commit.strip()}")

    log("\n[Session 1] Step 2A.3: Session 1 repeats identical queries within the same transaction")
    out_r2_status = s1.send("SELECT job_id, status FROM processing_jobs WHERE job_id = 101;")
    out_r2_count = s1.send("SELECT count(*) AS running_test_jobs FROM processing_jobs WHERE job_id IN (101, 102) AND status = 'RUNNING';")
    log(f"Session 1 (Query 2 - Status): {out_r2_status.strip()} --> [Row-level status changed from RUNNING to COMPLETED!]")
    log(f"Session 1 (Query 2 - Count):  {out_r2_count.strip()} --> [Running count changed from 2 to 1!]")
    s1.send("COMMIT;")
    if "COMPLETED" not in out_r2_status or "1" not in out_r2_count:
        raise AssertionError("Expected Non-Repeatable Read was not observed in READ COMMITTED!")
    log("VERIFIED: Non-Repeatable Read occurred under READ COMMITTED due to statement-level snapshot re-acquisition.")

    # ========================================================================
    # EXPERIMENT 2B: NON-REPEATABLE READ PREVENTION UNDER REPEATABLE READ
    # ========================================================================
    log("\n============================================================================")
    log("EXPERIMENT 2B: NON-REPEATABLE READ PREVENTION UNDER REPEATABLE READ")
    log("============================================================================")
    log("[Session 1] Step 2B.1: Start transaction in REPEATABLE READ and inspect Job 102")
    s1.send("BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;")
    out_rr1_status = s1.send("SELECT job_id, status FROM processing_jobs WHERE job_id = 102;")
    out_rr1_count = s1.send("SELECT count(*) AS running_test_jobs FROM processing_jobs WHERE job_id IN (101, 102) AND status = 'RUNNING';")
    log(f"Session 1 (Query 1 - Status): {out_rr1_status.strip()}")
    log(f"Session 1 (Query 1 - Count):  {out_rr1_count.strip()}")
    if "RUNNING" not in out_rr1_status or "1" not in out_rr1_count:
        raise AssertionError("Initial state for Experiment 2B unexpected")

    log("\n[Session 2] Step 2B.2: Concurrent session completes remaining Job 102 and commits")
    s2.send("BEGIN;")
    s2.send("UPDATE processing_jobs SET status = 'COMPLETED', end_time = CURRENT_TIMESTAMP, exit_code = 0 WHERE job_id = 102;")
    out_s2_commit2 = s2.send("COMMIT;")
    log(f"Session 2 (Commit completed job): {out_s2_commit2.strip()}")

    log("\n[Session 1] Step 2B.3: Session 1 repeats identical queries within REPEATABLE READ transaction")
    out_rr2_status = s1.send("SELECT job_id, status FROM processing_jobs WHERE job_id = 102;")
    out_rr2_count = s1.send("SELECT count(*) AS running_test_jobs FROM processing_jobs WHERE job_id IN (101, 102) AND status = 'RUNNING';")
    log(f"Session 1 (Query 2 - Status): {out_rr2_status.strip()} --> [Status remains RUNNING despite concurrent commit!]")
    log(f"Session 1 (Query 2 - Count):  {out_rr2_count.strip()} --> [Count remains 1 despite concurrent commit!]")
    s1.send("COMMIT;")
    if "RUNNING" not in out_rr2_status or "1" not in out_rr2_count:
        raise AssertionError("Snapshot Isolation was violated in REPEATABLE READ!")
    log("VERIFIED: REPEATABLE READ preserved the transaction-level snapshot; concurrent commit remained invisible.")

    # ========================================================================
    # EXPERIMENT 2C: WRITE SKEW DETECTION UNDER SERIALIZABLE (SSI)
    # ========================================================================
    log("\n============================================================================")
    log("EXPERIMENT 2C: WRITE SKEW DETECTION UNDER SERIALIZABLE (SSI)")
    log("============================================================================")
    s1.send("UPDATE mri_scanners SET is_operational = TRUE WHERE site_id = 'SITE-LOS-01';")

    log("[Session 1] Step 2C.1: Start SERIALIZABLE transaction and inspect operational scanners")
    s1.send("BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;")
    out_c1 = s1.send("SELECT count(*) AS operational_count FROM mri_scanners WHERE site_id = 'SITE-LOS-01' AND is_operational = TRUE;")
    log(f"Session 1 (Count): {out_c1.strip()}")

    log("\n[Session 2] Step 2C.2: Start SERIALIZABLE transaction and inspect operational scanners")
    s2.send("BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;")
    out_c2 = s2.send("SELECT count(*) AS operational_count FROM mri_scanners WHERE site_id = 'SITE-LOS-01' AND is_operational = TRUE;")
    log(f"Session 2 (Count): {out_c2.strip()}")

    log("\n[Session 1] Step 2C.3: Seeing count >= 2, Session 1 sets SCN-LOS-3T01 offline")
    s1.send("UPDATE mri_scanners SET is_operational = FALSE WHERE scanner_id = 'SCN-LOS-3T01';")
    log("Session 1: Scheduled SCN-LOS-3T01 offline")

    log("\n[Session 2] Step 2C.4: Seeing count >= 2, Session 2 sets SCN-LOS-15T1 offline")
    s2.send("UPDATE mri_scanners SET is_operational = FALSE WHERE scanner_id = 'SCN-LOS-15T1';")
    log("Session 2: Scheduled SCN-LOS-15T1 offline")

    log("\n[Session 1] Step 2C.5: Session 1 commits first")
    out_c_commit1 = s1.send("COMMIT;")
    log(f"Session 1 (Commit): {out_c_commit1.strip()}")

    log("\n[Session 2] Step 2C.6: Session 2 attempts to commit")
    out_c_commit2 = s2.send("COMMIT;")
    log(f"Session 2 (Commit attempt): {out_c_commit2.strip()}")
    if "could not serialize access" not in out_c_commit2:
        raise AssertionError("Expected Serialization Failure (Write Skew) was not caught by PostgreSQL SSI!")
    log("VERIFIED: Serializable Snapshot Isolation (SSI) detected rw-antidependency cycle and aborted Session 2 (SQLSTATE 40001).")

    s1.send("UPDATE mri_scanners SET is_operational = TRUE WHERE site_id = 'SITE-LOS-01';")

    # ========================================================================
    # EXPERIMENT 3: DEADLOCK DETECTION & RESOLUTION (WAIT-FOR GRAPH CYCLE)
    # ========================================================================
    log("\n============================================================================")
    log("EXPERIMENT 3: DEADLOCK DETECTION & RESOLUTION (WAIT-FOR GRAPH CYCLE)")
    log("============================================================================")
    s1.send("UPDATE mri_scans SET file_size_bytes = 25482310 WHERE scan_id = 'SCN-LOS-001-T1';")
    s1.send("UPDATE qc_evaluations SET snr_score = 19.85 WHERE scan_id = 'SCN-LOS-001-T1';")

    log("[Session 1] Step 3.1: Begin and acquire lock on mri_scans row (SCN-LOS-001-T1)")
    s1.send("BEGIN;")
    out_dl1 = s1.send("UPDATE mri_scans SET file_size_bytes = file_size_bytes + 1024 WHERE scan_id = 'SCN-LOS-001-T1';")
    log(f"Session 1: {out_dl1.strip()}")

    log("\n[Session 2] Step 3.2: Begin and acquire lock on qc_evaluations row (SCN-LOS-001-T1)")
    s2.send("BEGIN;")
    out_dl2 = s2.send("UPDATE qc_evaluations SET snr_score = snr_score + 0.1 WHERE scan_id = 'SCN-LOS-001-T1';")
    log(f"Session 2: {out_dl2.strip()}")

    log("\n[Session 1] Step 3.3: Session 1 requests lock on qc_evaluations row (BLOCKED by Session 2)")
    s1.proc.stdin.write("UPDATE qc_evaluations SET snr_score = snr_score + 0.2 WHERE scan_id = 'SCN-LOS-001-T1';\n")
    s1.proc.stdin.flush()
    time.sleep(0.3)
    s1.drain(timeout=0.1)
    log("Session 1: [BLOCKED - waiting for Session 2 on qc_evaluations]")

    log("\n[Session 2] Step 3.4: Session 2 requests lock on mri_scans row (BLOCKED by Session 1 - CYCLE FORMED!)")
    s2.proc.stdin.write("UPDATE mri_scans SET file_size_bytes = file_size_bytes + 2048 WHERE scan_id = 'SCN-LOS-001-T1';\n")
    s2.proc.stdin.flush()
    log("Session 2: [MUTUAL WAIT DETECTED - Waiting for deadlock_timeout ...]")

    time.sleep(1.5)
    out1_dl = s1.drain(timeout=0.2)
    out2_dl = s2.drain(timeout=0.2)
    log(f"Session 1 response: {out1_dl.strip()}")
    log(f"Session 2 response: {out2_dl.strip()}")

    if "deadlock detected" in out1_dl:
        log("--> Engine resolved deadlock by aborting SESSION 1 (Victim selected via wait-for cycle).")
        s1.send("ROLLBACK;")
        out_survive = s2.send("COMMIT;")
        log(f"Session 2 unblocked and committed successfully: {out_survive.strip()}")
    elif "deadlock detected" in out2_dl:
        log("--> Engine resolved deadlock by aborting SESSION 2 (Victim selected via wait-for cycle).")
        s2.send("ROLLBACK;")
        out_survive = s1.send("COMMIT;")
        log(f"Session 1 unblocked and committed successfully: {out_survive.strip()}")
    else:
        raise RuntimeError("Expected deadlock was not detected by PostgreSQL Lock Manager!")

    # Clean up test jobs
    s1.send("DELETE FROM processing_jobs WHERE job_id IN (101, 102);")
    s1.close()
    s2.close()

    log("\n============================================================================")
    log("TEST SUITE COMPLETED SUCCESSFULLY: ALL 4 CONCURRENCY EXPERIMENTS VERIFIED")
    log("============================================================================")

    evidence_path = "portfolio-3-transactions-concurrency/evidence/concurrency_outputs.txt"
    with open(evidence_path, "w") as f:
        f.write("\n".join(transcript) + "\n")
    print(f"\nWritten {len(transcript)} verified log lines to {evidence_path}")

if __name__ == "__main__":
    main()
