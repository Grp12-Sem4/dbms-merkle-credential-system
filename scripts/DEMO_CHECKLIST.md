# Integrity Demo Checklist

## Environment

Create a repo-root `.env` file:

```dotenv
DB_HOST=localhost
DB_PORT=3306
DB_NAME=credential_verifiability_system
DB_USER=your_mysql_user
DB_PASSWORD=your_mysql_password
```

The Python and PowerShell scripts load `.env` automatically. Existing process
environment variables override `.env` values.

Install Python dependencies:

```powershell
python -m pip install -r scripts/requirements.txt
```

## Database Setup

Fresh smoke test:

```powershell
.\scripts\load_integrity_db.ps1 -RunSmokeTest
```

Manual setup with the PowerShell loader:

```powershell
.\scripts\load_integrity_db.ps1
```

## Demo Commands

One-command report runner:

```powershell
.\scripts\run_integrity_demo.ps1
```

Refresh before reporting:

```powershell
.\scripts\run_integrity_demo.ps1 -RefreshFirst
```

DB stale-root demo:

```powershell
.\scripts\load_integrity_db.ps1 -SkipLoad -RunDemo
```

## What To Show

- `vw_integrity_status` output from `database/integrity_demo.sql`
- Pretty console output from `scripts/run_integrity_demo.ps1`
- `reports/integrity_report.json`
- `reports/integrity_report.csv`

## Status Meanings

- `VALID`: DB status is healthy and Python recomputation matches.
- `STALE_ROOT`: credential data changed after the Merkle state was generated.
- `MISMATCH`: recomputed root and stored root disagree.
- `INVESTIGATE`: DB/Python signals are incomplete or conflict.
- `ERROR`: verification could not complete for that student.

## Quick Fallbacks

- If output shows `STALE_ROOT`, rerun with `-RefreshFirst`.
- If Python shows `MISMATCH`, run:

```powershell
python scripts/merkle_demo.py --student-id "student-uuid-here" --debug-sql-parity
```

- If environment errors appear, re-check the five `DB_*` variables.
