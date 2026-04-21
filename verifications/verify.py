import sys
import os

# Add scripts folder to path
CURRENT_DIR = os.path.dirname(__file__)
SCRIPTS_PATH = os.path.join(CURRENT_DIR, "..", "scripts")
sys.path.append(SCRIPTS_PATH)

# Import from your existing script
from merkle_demo import verify_student as core_verify
from merkle_demo import get_db_config, DemoError

import mysql.connector


def verify(student_id, refresh_first=False):
    """
    Main verification function (your reusable API)

    Args:
        student_id (str): student UUID
        refresh_first (bool): rebuild Merkle before verifying

    Returns:
        dict: structured verification result
    """

    try:
        # DB connection
        config = get_db_config()
        connection = mysql.connector.connect(**config)
        cursor = connection.cursor(dictionary=True)

        # Call your existing verification logic
        result = core_verify(
            cursor,
            connection,
            student_id=student_id,
            version=None,
            refresh_first=refresh_first,
            debug_sql_parity_enabled=False
        )

        connection.close()

        return {
            "student_id": result.student_id,
            "status": result.status,
            "integrity_status": result.status,
            "message": (
                "Data is authentic and untampered"
                if result.status == "MATCH"
                else "Data integrity compromised"
            ),
            "proof": {
                "computed_root": result.computed_root,
                "stored_root": result.stored_root,
                "leaf_count": result.leaf_count
            }
        }

    except DemoError as e:
        return {
            "student_id": student_id,
            "status": "ERROR",
            "message": str(e)
        }

    except Exception as e:
        return {
            "student_id": student_id,
            "status": "ERROR",
            "message": f"Unexpected error: {str(e)}"
        }