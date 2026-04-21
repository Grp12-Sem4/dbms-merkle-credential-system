# 🔐 Verification & Access Module – Documentation

## 📌 Overview

This module implements the **Verification & Access Logic** of the system. It ensures that:

* Only authorized users (via **consent system**) can access data
* Data integrity is verified using **Merkle Tree hashing**
* Claims (e.g., GPA, City) are validated against database records
* System returns **structured proof** for every verification

---

# 🧠 System Architecture

```
User → API / CLI → Consent Check → Integrity Check → Claim Validation → Proof Output
```

---

# ✅ Features Implemented

## 1. Consent System (Access Control)

* Stores which verifier can access which student’s data
* Blocks unauthorized access before any processing

## 2. Integrity Verification

* Uses Merkle Tree logic
* Compares computed root with stored root
* Detects tampering instantly

## 3. Claim Verification

* GPA verification
* City verification
* Can be extended for more fields

## 4. Proof Generation

* Returns:

  * Cryptographic proof (Merkle root)
  * Data proof (actual vs claimed values)

## 5. API Integration

* Flask-based backend
* Ready for frontend integration

---

# 🗄️ Database Setup (Consent System)

## 📄 File: `database/consent_system.sql`

### Run this in MySQL Workbench:

```sql
USE credential_verifiability_system;

DROP TABLE IF EXISTS verification_consent;

CREATE TABLE verification_consent (
    id INT AUTO_INCREMENT PRIMARY KEY,
    student_id CHAR(36) NOT NULL,
    verifier_id VARCHAR(50) NOT NULL,
    consent_granted BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_consent_student
        FOREIGN KEY (student_id)
        REFERENCES student(id)
        ON DELETE CASCADE,

    UNIQUE (student_id, verifier_id)
);

INSERT INTO verification_consent (student_id, verifier_id, consent_granted)
VALUES 
('1e8fed86-3da8-11f1-8674-00155d855c82', 'verifier_1', TRUE),
('1e8fed86-3da8-11f1-8674-00155d855c82', 'verifier_2', FALSE);
```

---

# 💻 Running the System (CLI)

## 📌 Step 1: Activate Virtual Environment

```bash
cd scripts
venv\Scripts\activate
cd ..
```

---

## 📌 Step 2: Run Main Program

```bash
python verifications/main.py
```

---

## 📌 Step 3: Provide Input

Example:

```
Enter student ID: 1e8fed86-3da8-11f1-8674-00155d855c82
Enter verifier ID: verifier_1
```

---

## 📌 Outputs

### ✅ Authorized + Correct

```
status: VERIFIED
```

### ❌ Unauthorized

```
ACCESS DENIED
```

### ❌ Wrong Claim

```
status: INVALID
```

---

# 🌐 Running the API (Flask)

## 📌 Step 1: Start Server

```bash
python verifications/app.py
```

---

## 📌 Step 2: Open Browser / Postman

---

## 🔗 API Endpoints

---

### 🟢 1. Integrity Check

```
GET /verify
```

Example:

```
http://127.0.0.1:5000/verify?student_id=STUDENT_ID&verifier_id=verifier_1
```

---

### 🟢 2. GPA Verification

```
GET /verify/gpa
```

Example:

```
http://127.0.0.1:5000/verify/gpa?student_id=STUDENT_ID&verifier_id=verifier_1&gpa=8.83
```

---

### 🟢 3. City Verification

```
GET /verify/city
```

Example:

```
http://127.0.0.1:5000/verify/city?student_id=STUDENT_ID&verifier_id=verifier_1&city=Pune
```

---

## ❌ Unauthorized Access

```
status: DENIED
message: No consent for verification
```

---

# 📦 Output Format (JSON)

## ✔ Integrity Output

```json
{
  "student_id": "...",
  "status": "MATCH",
  "integrity_status": "MATCH",
  "message": "Data is authentic and untampered",
  "proof": {
    "computed_root": "...",
    "stored_root": "...",
    "leaf_count": 19
  }
}
```

---

## ✔ Claim Verification Output

```json
{
  "student_id": "...",
  "status": "VERIFIED",
  "integrity_status": "MATCH",
  "message": "GPA is correct and untampered",
  "proof": {
    "actual_gpa": 8.83,
    "claimed_gpa": 8.83,
    "integrity_verified": true
  }
}
```

---

# 🔐 Security Flow

| Step | Action             |
| ---- | ------------------ |
| 1    | Check consent      |
| 2    | Verify Merkle root |
| 3    | Validate claim     |
| 4    | Return proof       |

---

# 🎯 Conclusion

This module ensures:

* ✔ Secure access (Consent-based)
* ✔ Data integrity (Merkle Trees)
* ✔ Claim correctness (DB validation)
* ✔ Transparency (Proof generation)
* ✔ Integration-ready backend (Flask API)

---

# 🚀 Final Statement

> This system provides a complete verification pipeline that ensures both **trust (integrity)** and **truth (correctness)** of student credentials.

---
