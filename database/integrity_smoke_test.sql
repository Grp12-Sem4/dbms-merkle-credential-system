-- Fresh database smoke test for the Merkle integrity layer.
--
-- Run from the repository root with the MySQL client, for example:
--   mysql -u your_mysql_user -p < database/integrity_smoke_test.sql
--
-- This script is intended for a clean MySQL instance/database name. It loads
-- schema.sql first, then sample_data.sql, then runs basic integrity checks and
-- finally executes the full integrity demo.

SELECT 'SMOKE 1 - loading schema' AS smoke_step;
SOURCE database/schema.sql;

SELECT 'SMOKE 2 - loading sample data' AS smoke_step;
SOURCE database/sample_data.sql;

USE credential_verifiability_system;

SET @smoke_student_id = (
    SELECT id
    FROM student
    WHERE email = 'rahul.patil@student.com'
    LIMIT 1
);

SELECT 'SMOKE 3 - refresh Merkle state' AS smoke_step;
CALL sp_rebuild_merkle_leaves_for_student(@smoke_student_id);
CALL sp_store_merkle_root(@smoke_student_id);

SELECT 'SMOKE 4 - run DB-side verification procedure' AS smoke_step;
CALL sp_verify_student_merkle_integrity(@smoke_student_id);

SELECT 'SMOKE 5 - query frontend/demo integrity view' AS smoke_step;
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
WHERE student_id = @smoke_student_id;

SELECT 'SMOKE 6 - run full integrity demo sequence' AS smoke_step;
SOURCE database/integrity_demo.sql;

SELECT 'SMOKE COMPLETE' AS smoke_step;
