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
    |-- INTEGRITY_DEMO.md
    |-- merkle_demo.py
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

### Full Smoke Test

For a clean MySQL instance where `credential_verifiability_system` does not
already exist, the smoke test performs the schema load, sample-data load,
Merkle refresh, procedure call, view query, and full integrity demo:

```powershell
mysql -u your_mysql_user -p < database/integrity_smoke_test.sql
```

### Manual Step-By-Step Run

1. Load the schema. `database/schema.sql` creates and selects
   `credential_verifiability_system`:

```powershell
mysql -u your_mysql_user -p < database/schema.sql
```

2. Load sample data:

```powershell
mysql -u your_mysql_user -p credential_verifiability_system < database/sample_data.sql
```

3. Run only the DB-side integrity demo:

```powershell
mysql -u your_mysql_user -p credential_verifiability_system < database/integrity_demo.sql
```

Inside an interactive MySQL session from the repo root, the equivalent is:

```sql
SOURCE database/integrity_demo.sql;
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
