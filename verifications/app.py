from flask import Flask, request, jsonify
from verify import verify
from claim_check import verify_gpa, verify_city, check_consent

app = Flask(__name__)


# -------------------------------
# BASE VERIFICATION (INTEGRITY)
# -------------------------------
@app.route("/verify", methods=["GET"])
def verify_api():
    student_id = request.args.get("student_id")
    verifier_id = request.args.get("verifier_id")

    # 🔴 Consent check FIRST
    if not check_consent(student_id, verifier_id):
        return jsonify({
            "student_id": student_id,
            "status": "DENIED",
            "message": "No consent for verification"
        })

    return jsonify(verify(student_id))


# -------------------------------
# GPA VERIFICATION
# -------------------------------
@app.route("/verify/gpa", methods=["GET"])
def verify_gpa_api():
    student_id = request.args.get("student_id")
    verifier_id = request.args.get("verifier_id")
    gpa = request.args.get("gpa")

    return jsonify(
        verify_gpa(student_id, float(gpa), verifier_id)
    )


# -------------------------------
# CITY VERIFICATION
# -------------------------------
@app.route("/verify/city", methods=["GET"])
def verify_city_api():
    student_id = request.args.get("student_id")
    verifier_id = request.args.get("verifier_id")
    city = request.args.get("city")

    return jsonify(
        verify_city(student_id, city, verifier_id)
    )


# -------------------------------
# RUN SERVER
# -------------------------------
if __name__ == "__main__":
    app.run(debug=True)