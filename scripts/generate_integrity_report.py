#!/usr/bin/env python3
"""Generate demo-ready integrity reports from DB status plus Python verification."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from datetime import date, datetime
from decimal import Decimal
from pathlib import Path
from typing import Any

from merkle_demo import (
    DemoError,
    MySQLError,
    get_db_config,
    mysql,
    refresh_merkle,
    verify_student,
)


REPORT_FIELDS = [
    "student_id",
    "student_name",
    "student_email",
    "db_integrity_status",
    "db_remarks",
    "stored_current_root",
    "python_recomputed_root",
    "leaf_count",
    "root_generated_at",
    "python_verification_result",
    "overall_result",
    "current_root_count",
    "latest_tamper_time",
    "python_error",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate an integrity report combining DB status and Python verification."
    )
    target = parser.add_mutually_exclusive_group(required=True)
    target.add_argument("--student-id", help="Generate a report for one student UUID.")
    target.add_argument(
        "--all-students",
        action="store_true",
        help="Generate a report for every student.",
    )
    parser.add_argument(
        "--refresh-first",
        action="store_true",
        help="Refresh Merkle state before generating the report.",
    )
    parser.add_argument("--json-out", help="Write structured JSON report to this path.")
    parser.add_argument("--csv-out", help="Write flat CSV report rows to this path.")
    parser.add_argument(
        "--pretty",
        action="store_true",
        help="Print a human-readable summary and per-student details.",
    )
    return parser.parse_args()


def json_default(value: Any) -> str:
    if isinstance(value, (datetime, date)):
        return value.isoformat(sep=" ")
    if isinstance(value, Decimal):
        return str(value)
    return str(value)


def normalize_db_row(row: dict[str, Any] | None) -> dict[str, Any]:
    if row is None:
        return {
            "current_root_hash": None,
            "leaf_count": None,
            "root_generated_at": None,
            "current_root_count": None,
            "integrity_status": "ERROR",
            "latest_tamper_time": None,
            "remarks": "No vw_integrity_status row found for this student",
        }
    return row


def get_student_ids(cursor: Any, student_id: str | None) -> list[str]:
    if student_id:
        cursor.execute("SELECT id FROM student WHERE id = %s", (student_id,))
        rows = cursor.fetchall()
        if not rows:
            raise DemoError(f"Student not found: {student_id}")
        return [rows[0]["id"]]

    cursor.execute("SELECT id FROM student ORDER BY full_name, id")
    return [row["id"] for row in cursor.fetchall()]


def get_student_profile(cursor: Any, student_id: str) -> dict[str, Any]:
    cursor.execute(
        "SELECT id, full_name, email FROM student WHERE id = %s LIMIT 1",
        (student_id,),
    )
    row = cursor.fetchone()
    if not row:
        raise DemoError(f"Student not found: {student_id}")
    return row


def get_db_integrity_status(cursor: Any, student_id: str) -> dict[str, Any]:
    cursor.execute(
        """
        SELECT
            student_id,
            current_root_hash,
            leaf_count,
            root_generated_at,
            current_root_count,
            integrity_status,
            latest_tamper_time,
            remarks
        FROM vw_integrity_status
        WHERE student_id = %s
        LIMIT 1
        """,
        (student_id,),
    )
    return normalize_db_row(cursor.fetchone())


def compute_overall_result(
    db_status: str | None, python_result: str, stored_root: str | None, computed_root: str | None
) -> str:
    if python_result == "ERROR":
        return "ERROR"
    if db_status == "STALE_ROOT":
        return "STALE_ROOT"
    if python_result == "MISMATCH" or (
        stored_root is not None and computed_root is not None and stored_root != computed_root
    ):
        return "MISMATCH"
    if db_status == "VALID" and python_result == "MATCH":
        return "VALID"
    return "INVESTIGATE"


def build_student_report(cursor: Any, connection: Any, student_id: str) -> dict[str, Any]:
    profile = get_student_profile(cursor, student_id)
    db_status = get_db_integrity_status(cursor, student_id)

    python_result = "ERROR"
    python_error = None
    python_root = None
    stored_root = db_status.get("current_root_hash")
    leaf_count = db_status.get("leaf_count")

    try:
        verification = verify_student(cursor, connection, student_id=student_id)
        python_result = verification.status
        python_root = verification.computed_root
        stored_root = verification.stored_root or stored_root
        leaf_count = verification.leaf_count
        if verification.message:
            python_error = verification.message
    except (DemoError, MySQLError) as exc:
        python_error = str(exc)

    overall_result = compute_overall_result(
        db_status.get("integrity_status"), python_result, stored_root, python_root
    )

    return {
        "student_id": student_id,
        "student_name": profile["full_name"],
        "student_email": profile["email"],
        "db_integrity_status": db_status.get("integrity_status"),
        "db_remarks": db_status.get("remarks"),
        "stored_current_root": stored_root,
        "python_recomputed_root": python_root,
        "leaf_count": leaf_count,
        "root_generated_at": db_status.get("root_generated_at"),
        "python_verification_result": python_result,
        "overall_result": overall_result,
        "current_root_count": db_status.get("current_root_count"),
        "latest_tamper_time": db_status.get("latest_tamper_time"),
        "python_error": python_error,
    }


def summarize(rows: list[dict[str, Any]]) -> dict[str, int]:
    summary = {
        "total_students_checked": len(rows),
        "valid_count": 0,
        "stale_root_count": 0,
        "mismatch_count": 0,
        "investigate_count": 0,
        "error_count": 0,
    }

    for row in rows:
        result = row["overall_result"]
        if result == "VALID":
            summary["valid_count"] += 1
        elif result == "STALE_ROOT":
            summary["stale_root_count"] += 1
        elif result == "MISMATCH":
            summary["mismatch_count"] += 1
        elif result == "ERROR":
            summary["error_count"] += 1
        else:
            summary["investigate_count"] += 1

    return summary


def write_json(path: str, summary: dict[str, int], rows: list[dict[str, Any]]) -> None:
    output_path = Path(path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(
            {"summary": summary, "students": rows},
            indent=2,
            sort_keys=True,
            default=json_default,
        ),
        encoding="utf-8",
    )


def write_csv(path: str, rows: list[dict[str, Any]]) -> None:
    output_path = Path(path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=REPORT_FIELDS)
        writer.writeheader()
        for row in rows:
            writer.writerow(
                {
                    field: "" if row.get(field) is None else json_default(row.get(field))
                    for field in REPORT_FIELDS
                }
            )


def print_pretty(summary: dict[str, int], rows: list[dict[str, Any]]) -> None:
    print("Integrity Report Summary")
    print(f"total_students_checked: {summary['total_students_checked']}")
    print(f"valid_count: {summary['valid_count']}")
    print(f"stale_root_count: {summary['stale_root_count']}")
    print(f"mismatch_count: {summary['mismatch_count']}")
    print(f"investigate_count: {summary['investigate_count']}")
    print(f"error_count: {summary['error_count']}")
    print()

    for row in rows:
        print(f"{row['overall_result']} | {row['student_name']} | {row['student_id']}")
        print(f"  db_status: {row['db_integrity_status']}")
        print(f"  python: {row['python_verification_result']}")
        print(f"  leaf_count: {row['leaf_count']}")
        print(f"  root_generated_at: {json_default(row['root_generated_at'])}")
        print(f"  stored_root: {row['stored_current_root']}")
        print(f"  python_root: {row['python_recomputed_root']}")
        if row["db_remarks"]:
            print(f"  remarks: {row['db_remarks']}")
        if row["python_error"]:
            print(f"  python_note: {row['python_error']}")
        print()


def print_compact_summary(summary: dict[str, int]) -> None:
    print(
        "summary: "
        f"total={summary['total_students_checked']} "
        f"valid={summary['valid_count']} "
        f"stale_root={summary['stale_root_count']} "
        f"mismatch={summary['mismatch_count']} "
        f"investigate={summary['investigate_count']} "
        f"error={summary['error_count']}"
    )


def has_non_valid_results(summary: dict[str, int]) -> bool:
    return summary["total_students_checked"] != summary["valid_count"]


def generate_report(args: argparse.Namespace) -> tuple[dict[str, int], list[dict[str, Any]]]:
    if mysql is None:
        raise DemoError(
            "Missing dependency mysql-connector-python. Install with "
            "`python -m pip install -r scripts/requirements.txt`."
        )

    connection = mysql.connector.connect(**get_db_config())
    try:
        cursor = connection.cursor(dictionary=True)
        student_ids = get_student_ids(cursor, args.student_id)

        if args.refresh_first:
            if args.all_students:
                cursor.callproc("sp_refresh_all_merkle")
                connection.commit()
            else:
                refresh_merkle(cursor, connection, student_ids[0])

        rows = [build_student_report(cursor, connection, student_id) for student_id in student_ids]
        rows.sort(key=lambda row: (row["student_name"], row["student_id"]))
        return summarize(rows), rows
    finally:
        connection.close()


def main() -> int:
    args = parse_args()

    try:
        summary, rows = generate_report(args)
    except (DemoError, MySQLError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    if args.json_out:
        write_json(args.json_out, summary, rows)
    if args.csv_out:
        write_csv(args.csv_out, rows)

    if args.pretty or not (args.json_out or args.csv_out):
        print_pretty(summary, rows)
    elif args.all_students:
        print_compact_summary(summary)

    return 1 if has_non_valid_results(summary) else 0


if __name__ == "__main__":
    raise SystemExit(main())
