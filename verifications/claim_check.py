import mysql.connector

from verify import verify
from merkle_demo import get_db_config


def check_consent(student_id, verifier_id):
    config = get_db_config()
    conn = mysql.connector.connect(**config)
    cursor = conn.cursor(dictionary=True)

    cursor.execute(
        """
        SELECT consent_granted
        FROM verification_consent
        WHERE student_id = %s AND verifier_id = %s
        """,
        (student_id, verifier_id),
    )

    row = cursor.fetchone()
    conn.close()

    return row and row["consent_granted"]


def _normalize_text(value):
    return str(value).strip().lower()


def _normalize_number(value):
    return round(float(value), 2)


CLAIM_DEFINITIONS = {
    "gpa": {
        "label": "GPA",
        "query": """
            SELECT cumulative_gpa AS claim_value
            FROM student_institution_credential
            WHERE student_id = %s
        """,
        "normalizer": _normalize_number,
        "proof_actual": "actual_gpa",
        "proof_claimed": "claimed_gpa",
        "success_message": "GPA is correct and untampered",
        "failure_message": "Claimed GPA does not match database",
    },
    "city": {
        "label": "city",
        "query": """
            SELECT city AS claim_value
            FROM student_personal_credential
            WHERE student_id = %s
        """,
        "normalizer": _normalize_text,
        "proof_actual": "actual_city",
        "proof_claimed": "claimed_city",
        "success_message": "City is correct and untampered",
        "failure_message": "Claimed city does not match database",
    },
    "full_name": {
        "label": "full name",
        "query": """
            SELECT full_name AS claim_value
            FROM student
            WHERE id = %s
        """,
        "normalizer": _normalize_text,
        "proof_actual": "actual_full_name",
        "proof_claimed": "claimed_full_name",
        "success_message": "Full name is correct and untampered",
        "failure_message": "Claimed full name does not match database",
    },
    "date_of_birth": {
        "label": "date of birth",
        "query": """
            SELECT DATE_FORMAT(date_of_birth, '%Y-%m-%d') AS claim_value
            FROM student
            WHERE id = %s
        """,
        "normalizer": lambda value: str(value).strip(),
        "proof_actual": "actual_date_of_birth",
        "proof_claimed": "claimed_date_of_birth",
        "success_message": "Date of birth is correct and untampered",
        "failure_message": "Claimed date of birth does not match database",
    },
    "graduation_status": {
        "label": "graduation status",
        "query": """
            SELECT graduation_status AS claim_value
            FROM student_institution_credential
            WHERE student_id = %s
        """,
        "normalizer": _normalize_text,
        "proof_actual": "actual_graduation_status",
        "proof_claimed": "claimed_graduation_status",
        "success_message": "Graduation status is correct and untampered",
        "failure_message": "Claimed graduation status does not match database",
    },
    "department": {
        "label": "department",
        "query": """
            SELECT d.name AS claim_value
            FROM student_institution_credential sic
            INNER JOIN department d ON d.id = sic.department_id
            WHERE sic.student_id = %s
        """,
        "normalizer": _normalize_text,
        "proof_actual": "actual_department",
        "proof_claimed": "claimed_department",
        "success_message": "Department is correct and untampered",
        "failure_message": "Claimed department does not match database",
    },
    "institution_name": {
        "label": "institution name",
        "query": """
            SELECT i.name AS claim_value
            FROM student_institution_credential sic
            INNER JOIN institution i ON i.id = sic.institution_id
            WHERE sic.student_id = %s
        """,
        "normalizer": _normalize_text,
        "proof_actual": "actual_institution_name",
        "proof_claimed": "claimed_institution_name",
        "success_message": "Institution name is correct and untampered",
        "failure_message": "Claimed institution name does not match database",
    },
}


def _integrity_failure(student_id, integrity_result):
    proof = integrity_result.get("proof") or {}
    return {
        "student_id": student_id,
        "status": "FAILED",
        "integrity_status": "MISMATCH",
        "message": "Data integrity compromised",
        "proof": {
            "computed_root": proof.get("computed_root"),
            "stored_root": proof.get("stored_root"),
        },
    }


def _fetch_claim_value(student_id, query):
    config = get_db_config()
    connection = mysql.connector.connect(**config)
    cursor = connection.cursor(dictionary=True)

    cursor.execute(query, (student_id,))
    row = cursor.fetchone()
    connection.close()

    return row


def _verify_claim(student_id, claimed_value, verifier_id, claim_key):
    claim_definition = CLAIM_DEFINITIONS[claim_key]

    if not check_consent(student_id, verifier_id):
        return {
            "student_id": student_id,
            "status": "DENIED",
            "integrity_status": "UNKNOWN",
            "message": "No consent for verification",
            "proof": {},
        }

    integrity_result = verify(student_id)
    if integrity_result["integrity_status"] != "MATCH":
        return _integrity_failure(student_id, integrity_result)

    row = _fetch_claim_value(student_id, claim_definition["query"])
    if not row or row["claim_value"] is None:
        return {
            "student_id": student_id,
            "status": "ERROR",
            "integrity_status": "MATCH",
            "message": "Student data not found",
            "proof": {},
        }

    actual_value = row["claim_value"]
    normalized_actual = claim_definition["normalizer"](actual_value)
    normalized_claimed = claim_definition["normalizer"](claimed_value)
    is_match = normalized_actual == normalized_claimed

    return {
        "student_id": student_id,
        "status": "VERIFIED" if is_match else "INVALID",
        "integrity_status": "MATCH",
        "message": (
            claim_definition["success_message"]
            if is_match
            else claim_definition["failure_message"]
        ),
        "proof": {
            claim_definition["proof_actual"]: actual_value,
            claim_definition["proof_claimed"]: claimed_value,
            "integrity_verified": True,
        },
    }


def verify_gpa(student_id, claimed_gpa, verifier_id):
    return _verify_claim(student_id, claimed_gpa, verifier_id, "gpa")


def verify_city(student_id, claimed_city, verifier_id):
    return _verify_claim(student_id, claimed_city, verifier_id, "city")


def verify_full_name(student_id, claimed_full_name, verifier_id):
    return _verify_claim(student_id, claimed_full_name, verifier_id, "full_name")


def verify_date_of_birth(student_id, claimed_date_of_birth, verifier_id):
    return _verify_claim(student_id, claimed_date_of_birth, verifier_id, "date_of_birth")


def verify_graduation_status(student_id, claimed_graduation_status, verifier_id):
    return _verify_claim(
        student_id,
        claimed_graduation_status,
        verifier_id,
        "graduation_status",
    )


def verify_department(student_id, claimed_department, verifier_id):
    return _verify_claim(student_id, claimed_department, verifier_id, "department")


def verify_institution_name(student_id, claimed_institution_name, verifier_id):
    return _verify_claim(
        student_id,
        claimed_institution_name,
        verifier_id,
        "institution_name",
    )
