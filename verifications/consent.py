import mysql.connector
from merkle_demo import get_db_config

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