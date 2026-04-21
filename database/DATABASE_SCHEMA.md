Note: This document is a simplified schema summary for team understanding. The exact implementation source of truth is `schema.sql`.
# Database Schema Summary

## Project Title
Dynamic Credential Verifiability & Fraud-Resistant Academic Records System

## Purpose
This database is designed to store and manage academic credentials in a tamper-evident and auditable way using:
- credential hashes
- audit logs
- approval workflows
- Merkle leaf storage
- Merkle root history
- verification request and verification result tracking

---

## Core Entity Structure

### Student Hierarchy
- `student` stores the base identity of every student
- `existing_student` stores currently enrolled students
- `alumni` stores graduated students

### Credential Types
The system uses two credential categories:
- `student_personal_credential`
- `student_institution_credential`

### Verification Actors
- `verifier` stores external verifying bodies such as companies, institutions, and government agencies

### Administrative Control
- `admin` stores system administrators
- admins can request credential changes
- students must approve those requests before updates happen

---

## Main Tables

### 1. `admin`
Stores administrator details.

Important fields:
- `id`
- `full_name`
- `email`
- `phone_number`
- `city`
- `state`
- `address`
- `password_hash`
- `created_at`

### 2. `student`
Stores basic student identity data.

Important fields:
- `id`
- `full_name`
- `email`
- `date_of_birth`
- `password_hash`
- `created_at`

### 3. `existing_student`
Subtype table for active students.

Important fields:
- `id`
- `enrollment_year`
- `graduation_year`

### 4. `alumni`
Subtype table for alumni.

Important fields:
- `id`
- `graduation_year`

### 5. `verifier`
Stores verifier entities.

Important fields:
- `id`
- `name`
- `verifier_type`
- `organization_name`
- `contact_email`
- `password_hash`
- `created_at`

### 6. `department`
Stores department names.

Important fields:
- `id`
- `name`

### 7. `institution`
Stores institution details.

Important fields:
- `id`
- `name`
- `accreditation_type`
- `accreditation_grade`
- `contact`
- `institution_email`
- `created_at`

---

## Credential Tables

### 8. `student_personal_credential`
Stores one personal credential record per student.

Important fields:
- `id`
- `student_id`
- `father_name`
- `mother_name`
- `tenth_grade_marks`
- `twelfth_grade_marks`
- `city`
- `state`
- `permanent_address`
- `created_at`
- `last_modified_at`
- `credential_hash`

### 9. `student_institution_credential`
Stores academic/institutional credential details.

Important fields:
- `id`
- `student_id`
- `institution_id`
- `department_id`
- `personal_registration_number`
- `cumulative_gpa`
- `graduation_status`
- `status`
- `created_at`
- `last_modified_at`
- `credential_hash`

---

## Audit and Change Workflow Tables

### 10. `credential_track_log`
Stores audit history for creation, update, expiry, revocation, and rollback.

Important fields:
- `id`
- `credential_type`
- `credential_id_personal`
- `credential_id_institution`
- `action`
- `old_hash`
- `new_hash`
- `old_snapshot`
- `new_snapshot`
- `changed_by_admin_id`
- `changed_by_student_id`
- `request_id`
- `remarks`
- `modified_at`

### 11. `credential_change_request`
Stores admin-raised requests to modify credentials.

Important fields:
- `id`
- `admin_id`
- `student_id`
- `credential_type`
- `credential_id_personal`
- `credential_id_institution`
- `reason`
- `requested_changes`
- `status`
- `created_at`
- `reviewed_at`

### 12. `credential_change_approval`
Stores student approval for credential change requests.

Important fields:
- `id`
- `request_id`
- `student_id`
- `admin_id`
- `approval_hash`
- `approved_at`
- `remarks`

---

## Verification Tables

### 13. `verification_requests`
Stores incoming requests from verifiers.

Important fields:
- `id`
- `verifier_id`
- `student_id`
- `credential_type`
- `credential_id_personal`
- `credential_id_institution`
- `issued_at`
- `request_status`
- `purpose`
- `requested_fields`
- `consent_status`
- `consent_expires_at`
- `request_hash`

### 14. `verification_logs`
Stores the final result of a verification operation.

Important fields:
- `id`
- `request_id`
- `verifier_id`
- `student_id`
- `credential_id_personal`
- `credential_id_institution`
- `verified_at`
- `verification_status`
- `verified_claim`
- `merkle_root_hash`
- `verification_hash`
- `proof_payload`
- `remarks`

---

## Transfer and Tamper Tables

### 15. `credential_transfer_log`
Stores credential transfer activity between institutions.

Important fields:
- `id`
- `student_id`
- `credential_type`
- `credential_id_personal`
- `credential_id_institution`
- `source_institution_id`
- `destination_institution_id`
- `transfer_status`
- `transfer_hash`
- `remarks`
- `created_at`

### 16. `tampered_credential_log`
Stores logs whenever tampering is detected.

Important fields:
- `id`
- `student_id`
- `credential_type`
- `credential_id_personal`
- `credential_id_institution`
- `stored_hash`
- `recalculated_hash`
- `tampering_found`
- `detected_by`
- `rollback_status`
- `resolved_at`
- `remarks`

---

## Merkle Tables

### 17. `merkle_tree_leaf_nodes`
Stores field-level Merkle leaves for a student record version.

Important fields:
- `id`
- `student_id`
- `credential_type`
- `credential_id_personal`
- `credential_id_institution`
- `field_name`
- `field_hash`
- `leaf_hash`
- `leaf_position`
- `version_no`
- `is_active`
- `created_at`

### 18. `merkle_tree_root_history`
Stores current and historical Merkle roots.

Important fields:
- `id`
- `student_id`
- `root_hash`
- `leaf_count`
- `tree_level_count`
- `generated_at`
- `is_current`

---

## Important Design Rules

### 1. Password handling
Only main identity tables store login credentials:
- `admin`
- `student`
- `verifier`

Subtype tables do not store separate passwords:
- `existing_student`
- `alumni`

### 2. One personal credential row per student
`student_personal_credential` is maintained as one row per student in this design.

### 3. Split credential references
Where credential references are needed, the schema uses:
- `credential_id_personal`
- `credential_id_institution`

instead of one generic credential ID.

### 4. Admin-controlled update workflow
The valid flow is:
1. Admin raises request
2. Student approves or rejects
3. Admin modifies credential only after approval
4. Logs are written
5. Merkle leaves and roots are refreshed

### 5. Merkle design
The system uses:
- one Merkle tree per student record version
- one leaf per field/claim
- one current root per version/state

This gives field-level tamper detection and compact integrity proofs.

---

## DB Logic Included
The SQL implementation includes:
- triggers for automatic hash generation
- functions for normalization and hash generation
- procedures for integrity verification
- procedures for rollback
- procedures for Merkle leaf rebuild
- procedures for Merkle root storage

### Stage 2 Merkle Integrity Status

Additional DB-side integrity objects:

- `sp_verify_student_merkle_integrity(IN p_student_id CHAR(36))`
- `vw_integrity_status`

`sp_verify_student_merkle_integrity` recomputes the active Merkle root from
active leaf rows using the same SQL parent-hash behavior as
`sp_store_merkle_root`, compares it against the current root in
`merkle_tree_root_history`, and returns a status result set.

`vw_integrity_status` provides one frontend/demo-friendly row per student with
the current root, active leaf count, root timestamp, current-root row count,
latest pending tamper time, and an integrity status.

Status values:

- `VALID`: current root matches active leaves and is not stale.
- `STALE_ROOT`: credential data changed after the current root/leaves were
  generated.
- `MISMATCH`: recomputed root or Merkle metadata differs from the stored root.
- `MULTIPLE_CURRENT_ROOTS`: more than one root is marked current for the
  student.
- `TAMPERED_OR_MISMATCHED`: the view found a pending tamper/mismatch log.
- `MISSING_ROOT`: active leaves exist but no current root exists.
- `MISSING_LEAVES`: no active leaves exist for the student.
