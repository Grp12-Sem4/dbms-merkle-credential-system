#!/usr/bin/env python3
"""Recompute and verify a student's Merkle root outside MySQL.

The main verification path reads raw credential rows and independently mirrors
the SQL normalization, leaf hashing, and Merkle parent/root logic in Python.
SQL hash functions are used only by the optional debug parity check.

Relevant SQL behavior:
    fn_normalize_text(x) = LOWER(TRIM(IFNULL(x, '')))
    fn_hash_merkle_leaf(name, value) = SHA2(normalize(name) + '|' + normalize(value), 256)
    fn_merkle_parent_hash(left, right) = SHA2(left + '|' + right, 256)
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
from dataclasses import dataclass
from typing import Any

try:
    import mysql.connector
    from mysql.connector import Error as MySQLError
except ImportError:  # pragma: no cover - exercised by users without deps
    mysql = None
    MySQLError = Exception


REQUIRED_ENV_VARS = ("DB_HOST", "DB_PORT", "DB_NAME", "DB_USER", "DB_PASSWORD")


@dataclass
class VerificationResult:
    status: str
    student_id: str
    version_no: int
    leaf_count: int
    computed_root: str | None
    stored_root: str | None
    message: str | None = None
    sql_parity: list[dict[str, Any]] | None = None

    def as_dict(self) -> dict[str, Any]:
        return {
            "status": self.status,
            "student_id": self.student_id,
            "version_no": self.version_no,
            "leaf_count": self.leaf_count,
            "computed_root": self.computed_root,
            "stored_root": self.stored_root,
            "message": self.message,
            "sql_parity": self.sql_parity,
        }


class DemoError(Exception):
    """Raised for expected user-facing verification errors."""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Verify a student's stored Merkle root by recomputing it in Python."
    )
    parser.add_argument("--student-id", required=True, help="Student UUID to verify.")
    parser.add_argument(
        "--version",
        type=int,
        help="Leaf version_no to verify. Defaults to the current active version.",
    )
    parser.add_argument(
        "--refresh-first",
        action="store_true",
        help="Call sp_rebuild_merkle_leaves_for_student and sp_store_merkle_root first.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Print machine-readable JSON output.",
    )
    parser.add_argument(
        "--debug-sql-parity",
        action="store_true",
        help=(
            "Debug only: compare Python leaf hashes with SQL fn_hash_merkle_leaf "
            "for fetched raw fields."
        ),
    )
    return parser.parse_args()


def get_db_config() -> dict[str, Any]:
    missing = [name for name in REQUIRED_ENV_VARS if not os.getenv(name)]
    if missing:
        raise DemoError("Missing required environment variables: " + ", ".join(missing))

    try:
        port = int(os.environ["DB_PORT"])
    except ValueError as exc:
        raise DemoError("DB_PORT must be an integer.") from exc

    return {
        "host": os.environ["DB_HOST"],
        "port": port,
        "database": os.environ["DB_NAME"],
        "user": os.environ["DB_USER"],
        "password": os.environ["DB_PASSWORD"],
    }


def merkle_parent_hash(left_hash: str, right_hash: str) -> str:
    payload = f"{left_hash or ''}|{right_hash or ''}".encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def normalize_text(value: Any) -> str:
    """Mirror fn_normalize_text: LOWER(TRIM(IFNULL(value, '')))."""
    return "" if value is None else str(value).strip().lower()


def hash_merkle_leaf(field_name: str, field_value: Any) -> str:
    payload = f"{normalize_text(field_name)}|{normalize_text(field_value)}"
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def recompute_root(leaf_hashes: list[str]) -> tuple[str, int]:
    if not leaf_hashes:
        raise DemoError("No Merkle leaves found for this student/version.")

    level = leaf_hashes[:]
    tree_level_count = 1

    while len(level) > 1:
        next_level: list[str] = []
        for index in range(0, len(level), 2):
            left_hash = level[index]
            right_hash = level[index + 1] if index + 1 < len(level) else left_hash
            next_level.append(merkle_parent_hash(left_hash, right_hash))
        level = next_level
        tree_level_count += 1

    return level[0], tree_level_count


def student_exists(cursor: Any, student_id: str) -> bool:
    cursor.execute("SELECT 1 FROM student WHERE id = %s LIMIT 1", (student_id,))
    return cursor.fetchone() is not None


def refresh_merkle(cursor: Any, connection: Any, student_id: str) -> None:
    cursor.callproc("sp_rebuild_merkle_leaves_for_student", (student_id,))
    cursor.callproc("sp_store_merkle_root", (student_id,))
    connection.commit()


def get_current_version(cursor: Any, student_id: str) -> int:
    cursor.execute(
        """
        SELECT MAX(version_no) AS version_no
        FROM merkle_tree_leaf_nodes
        WHERE student_id = %s
          AND is_active = TRUE
        """,
        (student_id,),
    )
    row = cursor.fetchone()
    if not row or row["version_no"] is None:
        raise DemoError("No active Merkle leaf version found for this student.")
    return int(row["version_no"])


def get_current_leaf_metadata(cursor: Any, student_id: str) -> dict[str, Any]:
    cursor.execute(
        """
        SELECT COUNT(*) AS leaf_count, MAX(version_no) AS version_no
        FROM merkle_tree_leaf_nodes
        WHERE student_id = %s
          AND is_active = TRUE
        """,
        (student_id,),
    )
    row = cursor.fetchone()
    if not row or row["version_no"] is None:
        raise DemoError("No active Merkle leaves found for this student.")
    return row


def get_python_leaf_inputs(cursor: Any, student_id: str) -> list[tuple[str, Any]]:
    """Fetch raw credential fields in the same order used by sp_rebuild_merkle_leaves_for_student."""
    leaf_inputs: list[tuple[str, Any]] = []

    cursor.execute(
        """
        SELECT
            id,
            father_name,
            mother_name,
            tenth_grade_marks,
            twelfth_grade_marks,
            city,
            state,
            permanent_address
        FROM student_personal_credential
        WHERE student_id = %s
        ORDER BY id
        """,
        (student_id,),
    )
    for row in cursor.fetchall():
        leaf_inputs.extend(
            [
                ("father_name", row["father_name"]),
                ("mother_name", row["mother_name"]),
                ("tenth_grade_marks", row["tenth_grade_marks"]),
                ("twelfth_grade_marks", row["twelfth_grade_marks"]),
                ("city", row["city"]),
                ("state", row["state"]),
                ("permanent_address", row["permanent_address"]),
            ]
        )

    cursor.execute(
        """
        SELECT
            id,
            institution_id,
            department_id,
            personal_registration_number,
            cumulative_gpa,
            graduation_status,
            status
        FROM student_institution_credential
        WHERE student_id = %s
        ORDER BY id
        """,
        (student_id,),
    )
    for row in cursor.fetchall():
        leaf_inputs.extend(
            [
                ("institution_id", row["institution_id"]),
                ("department_id", row["department_id"]),
                ("personal_registration_number", row["personal_registration_number"]),
                ("cumulative_gpa", row["cumulative_gpa"]),
                ("graduation_status", row["graduation_status"]),
                ("status", row["status"]),
            ]
        )

    return leaf_inputs


def debug_sql_parity(cursor: Any, leaf_inputs: list[tuple[str, Any]]) -> list[dict[str, Any]]:
    parity_rows: list[dict[str, Any]] = []

    for position, (field_name, field_value) in enumerate(leaf_inputs, start=1):
        python_hash = hash_merkle_leaf(field_name, field_value)
        cursor.execute(
            "SELECT fn_hash_merkle_leaf(%s, %s) AS sql_hash",
            (field_name, "" if field_value is None else str(field_value)),
        )
        sql_hash = cursor.fetchone()["sql_hash"]
        parity_rows.append(
            {
                "leaf_position": position,
                "field_name": field_name,
                "python_hash": python_hash,
                "sql_hash": sql_hash,
                "match": python_hash == sql_hash,
            }
        )

    return parity_rows


def get_current_root(cursor: Any, student_id: str) -> dict[str, Any]:
    cursor.execute(
        """
        SELECT root_hash, leaf_count, tree_level_count, generated_at
        FROM merkle_tree_root_history
        WHERE student_id = %s
          AND is_current = TRUE
        ORDER BY generated_at DESC
        LIMIT 1
        """,
        (student_id,),
    )
    row = cursor.fetchone()
    if not row:
        raise DemoError("No current stored Merkle root found for this student.")
    return row


def verify(args: argparse.Namespace) -> VerificationResult:
    if mysql is None:
        raise DemoError(
            "Missing dependency mysql-connector-python. Install with "
            "`python -m pip install -r scripts/requirements.txt`."
        )

    config = get_db_config()
    connection = mysql.connector.connect(**config)

    try:
        cursor = connection.cursor(dictionary=True)

        if not student_exists(cursor, args.student_id):
            raise DemoError(f"Student not found: {args.student_id}")

        if args.refresh_first:
            refresh_merkle(cursor, connection, args.student_id)

        current_version = get_current_version(cursor, args.student_id)
        version_no = args.version if args.version is not None else current_version

        if version_no != current_version:
            raise DemoError(
                "Independent verification is available only for the active version. "
                "The schema does not store raw historical values or versioned roots "
                f"needed to recompute version {version_no} outside SQL."
            )

        leaf_metadata = get_current_leaf_metadata(cursor, args.student_id)
        leaf_inputs = get_python_leaf_inputs(cursor, args.student_id)
        leaf_hashes = [
            hash_merkle_leaf(field_name, field_value)
            for field_name, field_value in leaf_inputs
        ]

        if len(leaf_hashes) != int(leaf_metadata["leaf_count"]):
            raise DemoError(
                "Raw credential leaf count does not match active DB leaf metadata: "
                f"python={len(leaf_hashes)}, db={leaf_metadata['leaf_count']}. "
                "Run with --refresh-first if DB Merkle rows are stale."
            )

        computed_root, computed_tree_levels = recompute_root(leaf_hashes)
        stored_root = get_current_root(cursor, args.student_id)
        parity = debug_sql_parity(cursor, leaf_inputs) if args.debug_sql_parity else None

        status = "MATCH" if computed_root == stored_root["root_hash"] else "MISMATCH"
        message = None
        if computed_tree_levels != int(stored_root["tree_level_count"]):
            message = (
                "Computed tree level count differs from the stored metadata even "
                "though root comparison is authoritative for MATCH/MISMATCH."
            )

        return VerificationResult(
            status=status,
            student_id=args.student_id,
            version_no=version_no,
            leaf_count=len(leaf_hashes),
            computed_root=computed_root,
            stored_root=stored_root["root_hash"],
            message=message,
            sql_parity=parity,
        )
    finally:
        connection.close()


def print_result(result: VerificationResult, as_json: bool) -> None:
    if as_json:
        print(json.dumps(result.as_dict(), indent=2, sort_keys=True))
        return

    print(result.status)
    print(f"student_id: {result.student_id}")
    print(f"version_no: {result.version_no}")
    print(f"leaf_count: {result.leaf_count}")
    print(f"computed_root: {result.computed_root}")
    print(f"stored_root: {result.stored_root}")
    if result.message:
        print(f"note: {result.message}")
    if result.sql_parity is not None:
        mismatches = [row for row in result.sql_parity if not row["match"]]
        print(
            "sql_parity: "
            f"{len(result.sql_parity) - len(mismatches)}/{len(result.sql_parity)} "
            "leaf hashes matched SQL fn_hash_merkle_leaf"
        )


def print_error(message: str, as_json: bool) -> None:
    if as_json:
        print(
            json.dumps(
                {
                    "status": "ERROR",
                    "message": message,
                },
                indent=2,
                sort_keys=True,
            ),
            file=sys.stderr,
        )
        return
    print(f"ERROR: {message}", file=sys.stderr)


def main() -> int:
    args = parse_args()

    try:
        result = verify(args)
    except (DemoError, MySQLError) as exc:
        print_error(str(exc), args.json)
        return 2

    print_result(result, args.json)
    return 0 if result.status == "MATCH" else 1


if __name__ == "__main__":
    raise SystemExit(main())
