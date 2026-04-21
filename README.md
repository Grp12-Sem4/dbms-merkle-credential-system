# Dynamic Credential Verifiability & Fraud-Resistant Academic Records System

## Overview

This project is a DBMS-based academic credential management system designed to
provide tamper-evident storage, auditability, controlled credential
modification, verification workflows, and Merkle-based integrity tracking
without using blockchain.

The system is built around structured relational design, credential hashing,
event logs, approval workflows, and field-level Merkle leaves for fraud
resistance and verification support.

## Main Features

- Student and alumni credential storage
- Separation of personal and institutional credentials
- Admin-request and student-approval workflow for credential changes
- Credential tracking and tamper logs
- Verification request and verification log workflows
- Institutional credential transfer tracking
- Field-level Merkle leaf generation
- Merkle root history for integrity monitoring
- Stored procedures, triggers, and functions for DB-side logic
- DB-side integrity status view for frontend/demo queries
- External Python Merkle verifier for independent recomputation

## Repository Structure

```text
dbms-merkle-credential-system/
|
|-- README.md
|-- database/
|   |-- DATABASE_SCHEMA.md
|   |-- schema.sql
|   |-- sample_data.sql
|   |-- integrity_smoke_test.sql
|   `-- integrity_demo.sql
`-- scripts/
    |-- DEMO_CHECKLIST.md
    |-- INTEGRITY_DEMO.md
    |-- generate_integrity_report.py
    |-- load_integrity_db.ps1
    |-- merkle_demo.py
    |-- run_integrity_demo.ps1
    `-- requirements.txt
```

## Stage 1: External Python Integrity Verification

`scripts/merkle_demo.py` acts as an external verifier. It reads raw credential
rows from MySQL, independently reproduces the SQL normalization and SHA-256
Merkle hashing behavior in Python, rebuilds the Merkle root, and compares it
with the current DB-stored root.

The Python verifier may read DB data and optionally call refresh procedures, but
it does not depend on SQL hash functions for the primary verification path. See
`scripts/INTEGRITY_DEMO.md` for setup and examples.

## Stage 2: DB-Side Integrity Status Layer

The database now exposes official operational integrity status through:

- `sp_verify_student_merkle_integrity(IN p_student_id CHAR(36))`
- `vw_integrity_status`
- `database/integrity_smoke_test.sql`
- `database/integrity_demo.sql`

The stored procedure recomputes the active Merkle root inside SQL using the
existing DB helper logic, compares it with the current stored root, and returns:

- `student_id`
- `stored_root`
- `recomputed_root`
- `leaf_count`
- `version_no`
- `current_root_count`
- `current_root_timestamp`
- `latest_credential_modified_at`
- `status`
- `remarks`

The view provides a frontend/demo-friendly per-student summary with:

- `student_id`
- `current_root_hash`
- `leaf_count`
- `root_generated_at`
- `current_root_count`
- `integrity_status`
- `latest_tamper_time`
- `remarks`

### Integrity Status Values

- `VALID`: current DB Merkle root matches active leaves and is not stale.
- `STALE_ROOT`: a credential was updated after the current root/leaves were
  generated, so Merkle refresh is needed.
- `MISMATCH`: DB-side recomputation from active leaves differs from the stored
  current root. The procedure logs this to `tampered_credential_log` as a
  Merkle root mismatch.
- `MULTIPLE_CURRENT_ROOTS`: more than one root row is marked `is_current = TRUE`
  for a student, so the current root is ambiguous.
- `TAMPERED_OR_MISMATCHED`: the status view found a pending tamper/mismatch log
  for the student.
- `MISSING_ROOT`: active leaves exist but there is no current stored root.
- `MISSING_LEAVES`: no active Merkle leaves exist for the student.

## From-Scratch Demo Run

Run these commands from the repository root.

### PowerShell Setup Path

Set the database connection environment variables:

```powershell
$env:DB_HOST = "localhost"
$env:DB_PORT = "3306"
$env:DB_NAME = "credential_verifiability_system"
$env:DB_USER = "your_mysql_user"
$env:DB_PASSWORD = "your_mysql_password"
```

Load schema and sample data:

```powershell
.\scripts\load_integrity_db.ps1
```

Load schema only:

```powershell
.\scripts\load_integrity_db.ps1 -LoadSchemaOnly
```

Run the full smoke test on a clean database name:

```powershell
.\scripts\load_integrity_db.ps1 -RunSmokeTest
```

Load schema/sample data and run the stale-root DB demo:

```powershell
.\scripts\load_integrity_db.ps1 -RunDemo
```

Run only the stale-root DB demo when the DB is already loaded:

```powershell
.\scripts\load_integrity_db.ps1 -SkipLoad -RunDemo
```

`scripts/load_integrity_db.ps1` uses the MySQL CLI `SOURCE` command internally
and does not rely on PowerShell input redirection.

### Optional cmd/bash Style

In `cmd.exe`, Git Bash, or another shell where input redirection is expected to
work, the equivalent manual sequence is:

```bash
mysql -u your_mysql_user -p < database/schema.sql
mysql -u your_mysql_user -p credential_verifiability_system < database/sample_data.sql
mysql -u your_mysql_user -p credential_verifiability_system < database/integrity_demo.sql
```

The demo:

1. refreshes the sample student's Merkle state
2. shows `VALID`
3. updates a credential field without refreshing Merkle state
4. shows `STALE_ROOT`
5. refreshes Merkle state
6. shows `VALID` again

This differs from Stage 1: the DB layer is the official operational status that
frontend/backend code can query directly, while Python is an independent
external verifier used to prove the DB result can be recomputed outside SQL.

4. Run the Python external verifier:

```powershell
python -m pip install -r scripts/requirements.txt

$env:DB_HOST = "localhost"
$env:DB_PORT = "3306"
$env:DB_NAME = "credential_verifiability_system"
$env:DB_USER = "your_mysql_user"
$env:DB_PASSWORD = "your_mysql_password"

python scripts/merkle_demo.py --student-id "student-uuid-here"
```

5. Generate a combined integrity report:

```powershell
python scripts/generate_integrity_report.py --student-id "student-uuid-here" --pretty
python scripts/generate_integrity_report.py --all-students --pretty
python scripts/generate_integrity_report.py --all-students --json-out reports/integrity.json --csv-out reports/integrity.csv
```

Or run the Windows-friendly one-shot report demo:

```powershell
.\scripts\run_integrity_demo.ps1
```

## Stage 4: Combined Integrity Reports

`scripts/generate_integrity_report.py` combines the official DB operational
status from `vw_integrity_status` with the external Python Merkle recomputation
from `scripts/merkle_demo.py`.

Supported modes:

- `--student-id <id>`: report for one student.
- `--all-students`: report for every student.
- `--refresh-first`: refresh Merkle state before reporting.
- `--pretty`: print a demo-friendly console report.
- `--json-out <path>`: write structured JSON containing `summary` and
  `students`.
- `--csv-out <path>`: write flat per-student rows for quick review.

Parent directories for `--json-out` and `--csv-out` are created automatically.
Generated report files under `reports/` are ignored by Git.

The report includes:

- student identity
- DB integrity status and remarks
- stored current root
- Python recomputed root
- leaf count
- root timestamp
- Python verification result
- final `overall_result`

Overall result meanings:

- `VALID`: DB status is healthy and Python recomputation matches the stored root.
- `STALE_ROOT`: DB reports the Merkle state is stale after credential changes.
- `MISMATCH`: Python and stored root disagree.
- `INVESTIGATE`: DB and Python signals are incomplete or do not align cleanly.
- `ERROR`: the student could not be verified cleanly.

Exit-code behavior:

- `0`: every checked student has `overall_result = VALID`.
- `1`: at least one checked student is `STALE_ROOT`, `MISMATCH`,
  `INVESTIGATE`, or `ERROR`.
- `2`: the script could not run because of setup/configuration/DB errors.

For a compact demo script and fallback checklist, see
`scripts/DEMO_CHECKLIST.md`.
