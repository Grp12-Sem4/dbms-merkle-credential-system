from flask import Flask, jsonify, render_template, request

from claim_check import (
    check_consent,
    verify_city,
    verify_date_of_birth,
    verify_department,
    verify_full_name,
    verify_gpa,
    verify_graduation_status,
    verify_institution_name,
)
from verify import verify

app = Flask(__name__, template_folder="templates", static_folder="static")


def _required_arg(name):
    value = request.args.get(name, "").strip()
    if not value:
        raise ValueError(f"Missing required query parameter: {name}")
    return value


@app.route("/", methods=["GET"])
def index():
    return render_template("index.html")


@app.route("/verify", methods=["GET"])
def verify_api():
    try:
        student_id = _required_arg("student_id")
        verifier_id = _required_arg("verifier_id")
    except ValueError as exc:
        return jsonify({"status": "ERROR", "message": str(exc)}), 400

    if not check_consent(student_id, verifier_id):
        return jsonify(
            {
                "student_id": student_id,
                "status": "DENIED",
                "message": "No consent for verification",
            }
        )

    return jsonify(verify(student_id))


@app.route("/verify/gpa", methods=["GET"])
def verify_gpa_api():
    try:
        student_id = _required_arg("student_id")
        verifier_id = _required_arg("verifier_id")
        gpa = float(_required_arg("gpa"))
    except ValueError as exc:
        return jsonify({"status": "ERROR", "message": str(exc)}), 400

    return jsonify(verify_gpa(student_id, gpa, verifier_id))


@app.route("/verify/city", methods=["GET"])
def verify_city_api():
    try:
        student_id = _required_arg("student_id")
        verifier_id = _required_arg("verifier_id")
        city = _required_arg("city")
    except ValueError as exc:
        return jsonify({"status": "ERROR", "message": str(exc)}), 400

    return jsonify(verify_city(student_id, city, verifier_id))


@app.route("/verify/full-name", methods=["GET"])
def verify_full_name_api():
    try:
        student_id = _required_arg("student_id")
        verifier_id = _required_arg("verifier_id")
        full_name = _required_arg("full_name")
    except ValueError as exc:
        return jsonify({"status": "ERROR", "message": str(exc)}), 400

    return jsonify(verify_full_name(student_id, full_name, verifier_id))


@app.route("/verify/date-of-birth", methods=["GET"])
def verify_date_of_birth_api():
    try:
        student_id = _required_arg("student_id")
        verifier_id = _required_arg("verifier_id")
        date_of_birth = _required_arg("date_of_birth")
    except ValueError as exc:
        return jsonify({"status": "ERROR", "message": str(exc)}), 400

    return jsonify(verify_date_of_birth(student_id, date_of_birth, verifier_id))


@app.route("/verify/graduation-status", methods=["GET"])
def verify_graduation_status_api():
    try:
        student_id = _required_arg("student_id")
        verifier_id = _required_arg("verifier_id")
        graduation_status = _required_arg("graduation_status")
    except ValueError as exc:
        return jsonify({"status": "ERROR", "message": str(exc)}), 400

    return jsonify(
        verify_graduation_status(student_id, graduation_status, verifier_id)
    )


@app.route("/verify/department", methods=["GET"])
def verify_department_api():
    try:
        student_id = _required_arg("student_id")
        verifier_id = _required_arg("verifier_id")
        department = _required_arg("department")
    except ValueError as exc:
        return jsonify({"status": "ERROR", "message": str(exc)}), 400

    return jsonify(verify_department(student_id, department, verifier_id))


@app.route("/verify/institution-name", methods=["GET"])
def verify_institution_name_api():
    try:
        student_id = _required_arg("student_id")
        verifier_id = _required_arg("verifier_id")
        institution_name = _required_arg("institution_name")
    except ValueError as exc:
        return jsonify({"status": "ERROR", "message": str(exc)}), 400

    return jsonify(
        verify_institution_name(student_id, institution_name, verifier_id)
    )


if __name__ == "__main__":
    app.run(debug=True)
