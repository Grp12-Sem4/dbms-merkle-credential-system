import mysql.connector
from verify import verify
from merkle_demo import get_db_config


# -------------------------------
# CONSENT CHECK
# -------------------------------
def check_consent(student_id, verifier_id):
    config = get_db_config()
    conn = mysql.connector.connect(**config)
    cursor = conn.cursor(dictionary=True)

    cursor.execute("""
        SELECT consent_granted
        FROM verification_consent
        WHERE student_id = %s AND verifier_id = %s
    """, (student_id, verifier_id))

    row = cursor.fetchone()
    conn.close()

    return row and row["consent_granted"]


# -------------------------------
# GPA VERIFICATION
# -------------------------------
def verify_gpa(student_id, claimed_gpa, verifier_id):
    
    # 🔴 Step 1: Consent check
    if not check_consent(student_id, verifier_id):
        return {
            "student_id": student_id,
            "status": "DENIED",
            "integrity_status": "UNKNOWN",
            "message": "No consent for verification",
            "proof": {}
        }

    # 🟢 Step 2: Integrity check
    integrity_result = verify(student_id)

    if integrity_result["integrity_status"] != "MATCH":
        return {
            "student_id": student_id,
            "status": "FAILED",
            "integrity_status": "MISMATCH",
            "message": "Data integrity compromised",
            "proof": {
                "computed_root": integrity_result["proof"]["computed_root"],
                "stored_root": integrity_result["proof"]["stored_root"]
            }
        }

    # 🟢 Step 3: Fetch actual GPA
    config = get_db_config()
    connection = mysql.connector.connect(**config)
    cursor = connection.cursor(dictionary=True)

    cursor.execute("""
        SELECT cumulative_gpa
        FROM student_institution_credential
        WHERE student_id = %s
    """, (student_id,))

    row = cursor.fetchone()
    connection.close()

    if not row:
        return {
            "student_id": student_id,
            "status": "ERROR",
            "integrity_status": "MATCH",
            "message": "Student data not found",
            "proof": {}
        }

    actual_gpa = float(row["cumulative_gpa"])

    # 🟢 Step 4: Compare
    if actual_gpa == float(claimed_gpa):
        return {
            "student_id": student_id,
            "status": "VERIFIED",
            "integrity_status": "MATCH",
            "message": "GPA is correct and untampered",
            "proof": {
                "actual_gpa": actual_gpa,
                "claimed_gpa": float(claimed_gpa),
                "integrity_verified": True
            }
        }
    else:
        return {
            "student_id": student_id,
            "status": "INVALID",
            "integrity_status": "MATCH",
            "message": "Claimed GPA does not match database",
            "proof": {
                "actual_gpa": actual_gpa,
                "claimed_gpa": float(claimed_gpa),
                "integrity_verified": True
            }
        }


# -------------------------------
# CITY VERIFICATION
# -------------------------------
def verify_city(student_id, claimed_city, verifier_id):

    # 🔴 Step 1: Consent check
    if not check_consent(student_id, verifier_id):
        return {
            "student_id": student_id,
            "status": "DENIED",
            "integrity_status": "UNKNOWN",
            "message": "No consent for verification",
            "proof": {}
        }

    # 🟢 Step 2: Integrity check
    integrity_result = verify(student_id)

    if integrity_result["integrity_status"] != "MATCH":
        return {
            "student_id": student_id,
            "status": "FAILED",
            "integrity_status": "MISMATCH",
            "message": "Data integrity compromised",
            "proof": {
                "computed_root": integrity_result["proof"]["computed_root"],
                "stored_root": integrity_result["proof"]["stored_root"]
            }
        }

    # 🟢 Step 3: Fetch actual city
    config = get_db_config()
    connection = mysql.connector.connect(**config)
    cursor = connection.cursor(dictionary=True)

    cursor.execute("""
        SELECT city
        FROM student_personal_credential
        WHERE student_id = %s
    """, (student_id,))

    row = cursor.fetchone()
    connection.close()

    if not row:
        return {
            "student_id": student_id,
            "status": "ERROR",
            "integrity_status": "MATCH",
            "message": "Student data not found",
            "proof": {}
        }

    actual_city = row["city"]

    # 🟢 Step 4: Compare
    if actual_city.lower() == claimed_city.lower():
        return {
            "student_id": student_id,
            "status": "VERIFIED",
            "integrity_status": "MATCH",
            "message": "City is correct and untampered",
            "proof": {
                "actual_city": actual_city,
                "claimed_city": claimed_city,
                "integrity_verified": True
            }
        }
    else:
        return {
            "student_id": student_id,
            "status": "INVALID",
            "integrity_status": "MATCH",
            "message": "Claimed city does not match database",
            "proof": {
                "actual_city": actual_city,
                "claimed_city": claimed_city,
                "integrity_verified": True
            }
        }