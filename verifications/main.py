from verify import verify
from claim_check import verify_gpa, verify_city, check_consent

# -------------------------------
# INPUT
# -------------------------------
student_id = input("Enter student ID: ")
verifier_id = input("Enter verifier ID: ")

# -------------------------------
# CONSENT CHECK FIRST
# -------------------------------
if not check_consent(student_id, verifier_id):
    print("\n❌ ACCESS DENIED: No consent for verification")
    exit()

# -------------------------------
# INTEGRITY CHECK
# -------------------------------
print("\n=== INTEGRITY CHECK ===")
print(verify(student_id))

# -------------------------------
# GPA CHECK
# -------------------------------
choice = input("\nDo you want to verify GPA? (y/n): ")

if choice.lower() == 'y':
    claimed_gpa = float(input("Enter claimed GPA: "))
    print("\n=== GPA VERIFICATION ===")
    print(verify_gpa(student_id, claimed_gpa, verifier_id))

# -------------------------------
# CITY CHECK
# -------------------------------
choice = input("\nDo you want to verify City? (y/n): ")

if choice.lower() == 'y':
    claimed_city = input("Enter claimed city: ")
    print("\n=== CITY VERIFICATION ===")
    print(verify_city(student_id, claimed_city, verifier_id))