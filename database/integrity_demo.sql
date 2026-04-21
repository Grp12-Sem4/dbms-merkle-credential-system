USE credential_verifiability_system;

-- Stage 2 DB-side integrity demo.
-- This script uses normal UPDATE behavior. Triggers refresh credential_hash,
-- but Merkle leaves/root remain stale until the Merkle refresh procedures run.

SET @demo_student_id = (
    SELECT id
    FROM student
    WHERE email = 'rahul.patil@student.com'
    LIMIT 1
);

-- 1. Ensure baseline Merkle state is refreshed.
CALL sp_rebuild_merkle_leaves_for_student(@demo_student_id);
CALL sp_store_merkle_root(@demo_student_id);

-- 2. Show current valid integrity status.
SELECT 'STEP 2 - valid baseline from procedure' AS demo_step;
CALL sp_verify_student_merkle_integrity(@demo_student_id);

SELECT 'STEP 2 - valid baseline from view' AS demo_step;
SELECT
    student_id,
    current_root_hash,
    leaf_count,
    root_generated_at,
    current_root_count,
    integrity_status,
    latest_tamper_time,
    remarks
FROM vw_integrity_status
WHERE student_id = @demo_student_id;

-- Make timestamp comparisons deterministic on systems with one-second TIMESTAMP precision.
DO SLEEP(1);

-- 3. Update one credential field. Do not refresh Merkle state yet.
SET @actor_admin_id = NULL;
SET @actor_student_id = @demo_student_id;
SET @request_id = NULL;
SET @change_remarks = 'Stage 2 integrity demo update without immediate Merkle refresh';
SET @audit_action_override = 'UPDATED';

UPDATE student_institution_credential
SET cumulative_gpa = CASE
    WHEN cumulative_gpa = 8.82 THEN 8.83
    ELSE 8.82
END
WHERE student_id = @demo_student_id
  AND personal_registration_number = 'PRN001';

SET @actor_admin_id = NULL;
SET @actor_student_id = NULL;
SET @request_id = NULL;
SET @change_remarks = NULL;
SET @audit_action_override = NULL;

-- 4. The credential hash was refreshed by trigger, but Merkle state is stale.
SELECT 'STEP 4 - stale state from procedure' AS demo_step;
CALL sp_verify_student_merkle_integrity(@demo_student_id);

SELECT 'STEP 4 - stale state from view' AS demo_step;
SELECT
    student_id,
    current_root_hash,
    leaf_count,
    root_generated_at,
    current_root_count,
    integrity_status,
    latest_tamper_time,
    remarks
FROM vw_integrity_status
WHERE student_id = @demo_student_id;

-- 5. Refresh Merkle leaves and root.
CALL sp_rebuild_merkle_leaves_for_student(@demo_student_id);
CALL sp_store_merkle_root(@demo_student_id);

-- 6. Verify the state is valid again.
SELECT 'STEP 6 - restored valid state from procedure' AS demo_step;
CALL sp_verify_student_merkle_integrity(@demo_student_id);

SELECT 'STEP 6 - restored valid state from view' AS demo_step;
SELECT
    student_id,
    current_root_hash,
    leaf_count,
    root_generated_at,
    current_root_count,
    integrity_status,
    latest_tamper_time,
    remarks
FROM vw_integrity_status
WHERE student_id = @demo_student_id;
