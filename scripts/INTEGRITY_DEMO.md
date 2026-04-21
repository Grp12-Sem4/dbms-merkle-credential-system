# Merkle Integrity Demo

This demo independently recomputes a student's Merkle root in Python from raw
credential rows, then compares that value with the current root stored in
`merkle_tree_root_history`.

The database remains the authoritative source for official credential hashing,
Merkle storage, triggers, procedures, audit logs, and tamper logs. The Python
script is an external verifier: it mirrors the SQL hashing behavior in Python
instead of asking MySQL to perform the main verification hashes.

## Setup

Install the Python dependency:

```powershell
python -m pip install -r scripts/requirements.txt
```

Create a repo-root `.env` file:

```dotenv
DB_HOST=localhost
DB_PORT=3306
DB_NAME=credential_verifiability_system
DB_USER=your_mysql_user
DB_PASSWORD=your_mysql_password
```

The Python and PowerShell scripts load `.env` automatically. Process
environment variables override `.env` values when present.

Load schema and sample data on Windows PowerShell:

```powershell
.\scripts\load_integrity_db.ps1
```

Run the DB stale-root demo after the DB is loaded:

```powershell
.\scripts\load_integrity_db.ps1 -SkipLoad -RunDemo
```

Run the full DB smoke test on a clean database name:

```powershell
.\scripts\load_integrity_db.ps1 -RunSmokeTest
```

## Run

Pass the student UUID to verify:

```powershell
python scripts/merkle_demo.py --student-id "student-uuid-here"
```

To rebuild the student's Merkle leaves and current root before checking:

```powershell
python scripts/merkle_demo.py --student-id "student-uuid-here" --refresh-first
```

For machine-readable output:

```powershell
python scripts/merkle_demo.py --student-id "student-uuid-here" --json
```

For troubleshooting only, compare Python leaf hashes with SQL
`fn_hash_merkle_leaf` outputs:

```powershell
python scripts/merkle_demo.py --student-id "student-uuid-here" --debug-sql-parity
```

If a mismatch appears unexpectedly, run `--debug-sql-parity` before changing
the verifier. Decimal and timestamp-like values can expose formatting
differences between SQL `CAST(... AS CHAR)` and Python value stringification;
the parity mode helps identify whether the mismatch begins at leaf hashing or
at the Merkle parent/root layer.

## Combined Report Generation

Use `scripts/generate_integrity_report.py` when you need one demo/submission
output that combines:

- DB operational status from `vw_integrity_status`
- Python external Merkle recomputation from `merkle_demo.py`
- an aggregate summary
- optional JSON/CSV export files

One-student report:

```powershell
python scripts/generate_integrity_report.py --student-id "student-uuid-here" --pretty
```

All-students report:

```powershell
python scripts/generate_integrity_report.py --all-students --pretty
```

Export JSON and CSV:

```powershell
python scripts/generate_integrity_report.py --all-students --json-out reports/integrity.json --csv-out reports/integrity.csv
```

Windows one-shot demo runner:

```powershell
.\scripts\run_integrity_demo.ps1
```

Add `--refresh-first` when you want the report to refresh Merkle leaves and
roots before checking. The DB status remains the official operational state;
the Python result is the independent external proof/check layered into the
report.

Report exit codes:

- `0`: all checked students are `VALID`
- `1`: at least one checked student is non-valid
- `2`: setup, dependency, or DB connection error

## Result Meaning

`MATCH` means the root recomputed outside the database from raw credential
values exactly equals the student's current stored Merkle root. In this project,
that shows Python can independently reproduce the DB's current Merkle result.

`MISMATCH` means the recomputed root differs from the stored root. That can
indicate stale Merkle data, tampering, or a Python/SQL behavior mismatch that
needs investigation.

## SQL Behavior Mirrored

The Python script mirrors these SQL functions/procedures without calling them
for the primary verification hashes:

- `fn_normalize_text`: `LOWER(TRIM(IFNULL(value, '')))`
- `fn_hash_merkle_leaf`: `SHA256(normalized_field_name + "|" + normalized_field_value)`
- `sp_rebuild_merkle_leaves_for_student`: personal fields first, then
  institutional fields ordered by credential id
- `fn_merkle_parent_hash`: `SHA256(left_hash + "|" + right_hash)`
- `sp_store_merkle_root`: adjacent hashes are paired from left to right
- an odd final node is duplicated and paired with itself

## What SQL Is Still Used For

The script still uses SQL for:

- reading current raw credential rows
- reading active Merkle metadata and the current stored root
- optional `--refresh-first` calls to `sp_rebuild_merkle_leaves_for_student`
  and `sp_store_merkle_root`
- optional debug-only `--debug-sql-parity` calls to `fn_hash_merkle_leaf`

The script does not use SQL hash functions as the primary verification path.

## Version Limitation

`merkle_tree_root_history` stores current roots but does not store a
`version_no`, and the schema does not keep raw historical credential snapshots
for old Merkle versions. For that reason, independent Python verification is
limited to the active version. If `--version` is supplied for a non-current
version, the script exits with a clear error instead of treating DB-stored leaf
hashes as external proof.
