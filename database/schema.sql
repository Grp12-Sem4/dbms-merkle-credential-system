CREATE DATABASE credential_verifiability_system;
USE credential_verifiability_system;
CREATE TABLE admin (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    full_name TEXT NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    phone_number VARCHAR(20),
    city VARCHAR(100),
    state VARCHAR(100),
    address TEXT,
    password_hash CHAR(64) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE student (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    full_name TEXT NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    date_of_birth DATE,
    password_hash CHAR(64) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE existing_student (
    id CHAR(36) PRIMARY KEY,
    enrollment_year INT NOT NULL,
    graduation_year INT,
    FOREIGN KEY (id) REFERENCES student(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE alumni (
    id CHAR(36) PRIMARY KEY,
    graduation_year INT NOT NULL,
    FOREIGN KEY (id) REFERENCES student(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE verifier (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    name TEXT NOT NULL,
    verifier_type ENUM('COMPANY','EDUCATIONAL_INSTITUTION','GOVERNMENT_AGENCY') NOT NULL,
    organization_name TEXT,
    contact_email VARCHAR(255),
    password_hash CHAR(64) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE department (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    name VARCHAR(255) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE institution (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    name VARCHAR(255) NOT NULL UNIQUE,
    accreditation_type ENUM('NAAC','NBA','NIRF'),
    accreditation_grade ENUM('A++','A+','A','B++','B+','B','C','D'),
    contact TEXT,
    institution_email VARCHAR(255) UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE student_institution_credential (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    student_id CHAR(36) NOT NULL,
    institution_id CHAR(36) NOT NULL,
    department_id CHAR(36) NOT NULL,
    personal_registration_number VARCHAR(100) NOT NULL,
    cumulative_gpa DECIMAL(4,2),
    graduation_status ENUM('PURSUING','GRADUATED','DROPPED','WITHHELD'),
    status ENUM('ACTIVE','REVOKED','EXPIRED') DEFAULT 'ACTIVE',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_modified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    credential_hash CHAR(64) NOT NULL,
    FOREIGN KEY (student_id) REFERENCES student(id),
    FOREIGN KEY (institution_id) REFERENCES institution(id),
    FOREIGN KEY (department_id) REFERENCES department(id)
) ENGINE=InnoDB;

CREATE TABLE student_personal_credential (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    student_id CHAR(36) NOT NULL UNIQUE,
    father_name TEXT,
    mother_name TEXT,
    tenth_grade_marks DECIMAL(5,2),
    twelfth_grade_marks DECIMAL(5,2),
    city VARCHAR(100),
    state VARCHAR(100),
    permanent_address TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_modified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    credential_hash CHAR(64) NOT NULL,
    FOREIGN KEY (student_id) REFERENCES student(id)
) ENGINE=InnoDB;

CREATE TABLE credential_change_request (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    admin_id CHAR(36) NOT NULL,
    student_id CHAR(36) NOT NULL,
    credential_type ENUM('PERSONAL','INSTITUTIONAL'),
    credential_id_personal CHAR(36),
    credential_id_institution CHAR(36),
    reason TEXT,
    requested_changes JSON,
    status ENUM('PENDING','ACCEPTED','REJECTED','INACTIVE') DEFAULT 'PENDING',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reviewed_at TIMESTAMP NULL DEFAULT NULL,
    FOREIGN KEY (admin_id) REFERENCES admin(id),
    FOREIGN KEY (student_id) REFERENCES student(id),
    FOREIGN KEY (credential_id_personal) REFERENCES student_personal_credential(id),
    FOREIGN KEY (credential_id_institution) REFERENCES student_institution_credential(id)
) ENGINE=InnoDB;

CREATE TABLE credential_change_approval (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    request_id CHAR(36) NOT NULL,
    student_id CHAR(36) NOT NULL,
    admin_id CHAR(36) NOT NULL,
    approval_hash CHAR(64) NOT NULL,
    approved_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    remarks TEXT,
    FOREIGN KEY (request_id) REFERENCES credential_change_request(id),
    FOREIGN KEY (student_id) REFERENCES student(id),
    FOREIGN KEY (admin_id) REFERENCES admin(id)
) ENGINE=InnoDB;

CREATE TABLE credential_track_log (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    credential_type ENUM('PERSONAL','INSTITUTIONAL') NOT NULL,
    credential_id_personal CHAR(36),
    credential_id_institution CHAR(36),
    action ENUM('CREATED','UPDATED','REVOKED','EXPIRED','ROLLED_BACK') NOT NULL,
    old_hash CHAR(64),
    new_hash CHAR(64),
    old_snapshot JSON,
    new_snapshot JSON,
    changed_by_admin_id CHAR(36),
    changed_by_student_id CHAR(36),
    request_id CHAR(36),
    remarks TEXT,
    modified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (credential_id_personal) REFERENCES student_personal_credential(id),
    FOREIGN KEY (credential_id_institution) REFERENCES student_institution_credential(id),
    FOREIGN KEY (changed_by_admin_id) REFERENCES admin(id),
    FOREIGN KEY (changed_by_student_id) REFERENCES student(id),
    FOREIGN KEY (request_id) REFERENCES credential_change_request(id)
) ENGINE=InnoDB;

CREATE TABLE tampered_credential_log (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    student_id CHAR(36),
    credential_type ENUM('PERSONAL','INSTITUTIONAL'),
    credential_id_personal CHAR(36),
    credential_id_institution CHAR(36),
    stored_hash CHAR(64),
    recalculated_hash CHAR(64),
    tampering_found TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    detected_by VARCHAR(100),
    rollback_status ENUM('PENDING','COMPLETED','FAILED') DEFAULT 'PENDING',
    resolved_at TIMESTAMP NULL DEFAULT NULL,
    remarks TEXT,
    FOREIGN KEY (student_id) REFERENCES student(id),
    FOREIGN KEY (credential_id_personal) REFERENCES student_personal_credential(id),
    FOREIGN KEY (credential_id_institution) REFERENCES student_institution_credential(id)
) ENGINE=InnoDB;

CREATE TABLE credential_transfer_log (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    student_id CHAR(36) NOT NULL,
    credential_type ENUM('PERSONAL','INSTITUTIONAL') NOT NULL,
    credential_id_personal CHAR(36),
    credential_id_institution CHAR(36),
    source_institution_id CHAR(36) NOT NULL,
    destination_institution_id CHAR(36) NOT NULL,
    transfer_status ENUM('INITIATED','APPROVED','COMPLETED','REJECTED') DEFAULT 'INITIATED',
    transfer_hash CHAR(64) NOT NULL,
    remarks TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (student_id) REFERENCES student(id),
    FOREIGN KEY (credential_id_personal) REFERENCES student_personal_credential(id),
    FOREIGN KEY (credential_id_institution) REFERENCES student_institution_credential(id),
    FOREIGN KEY (source_institution_id) REFERENCES institution(id),
    FOREIGN KEY (destination_institution_id) REFERENCES institution(id)
) ENGINE=InnoDB;

CREATE TABLE verification_requests (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    verifier_id CHAR(36) NOT NULL,
    student_id CHAR(36) NOT NULL,
    credential_type ENUM('PERSONAL','INSTITUTIONAL'),
    credential_id_personal CHAR(36),
    credential_id_institution CHAR(36),
    issued_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    request_status ENUM('PENDING','CONSENT_REQUESTED','CONSENT_GRANTED','CONSENT_DENIED','COMPLETED','REJECTED','EXPIRED') DEFAULT 'PENDING',
    purpose TEXT,
    requested_fields JSON,
    consent_status ENUM('PENDING','GRANTED','DENIED','EXPIRED') DEFAULT 'PENDING',
    consent_expires_at TIMESTAMP NULL DEFAULT NULL,
    request_hash CHAR(64) NOT NULL,
    FOREIGN KEY (verifier_id) REFERENCES verifier(id),
    FOREIGN KEY (student_id) REFERENCES student(id),
    FOREIGN KEY (credential_id_personal) REFERENCES student_personal_credential(id),
    FOREIGN KEY (credential_id_institution) REFERENCES student_institution_credential(id)
) ENGINE=InnoDB;

CREATE TABLE verification_logs (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    request_id CHAR(36),
    verifier_id CHAR(36) NOT NULL,
    student_id CHAR(36) NOT NULL,
    credential_id_personal CHAR(36),
    credential_id_institution CHAR(36),
    verified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    verification_status ENUM('VERIFIED','FAULTY','UNCERTAINTY'),
    verified_claim TEXT,
    merkle_root_hash CHAR(64),
    verification_hash CHAR(64) NOT NULL,
    proof_payload JSON,
    remarks TEXT,
    FOREIGN KEY (request_id) REFERENCES verification_requests(id),
    FOREIGN KEY (verifier_id) REFERENCES verifier(id),
    FOREIGN KEY (student_id) REFERENCES student(id),
    FOREIGN KEY (credential_id_personal) REFERENCES student_personal_credential(id),
    FOREIGN KEY (credential_id_institution) REFERENCES student_institution_credential(id)
) ENGINE=InnoDB;

CREATE TABLE merkle_tree_leaf_nodes (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    student_id CHAR(36) NOT NULL,
    credential_type ENUM('PERSONAL','INSTITUTIONAL') NOT NULL,
    credential_id_personal CHAR(36),
    credential_id_institution CHAR(36),
    field_name VARCHAR(100) NOT NULL,
    field_hash CHAR(64) NOT NULL,
    leaf_hash CHAR(64) NOT NULL,
    leaf_position INT NOT NULL,
    version_no INT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (student_id) REFERENCES student(id),
    FOREIGN KEY (credential_id_personal) REFERENCES student_personal_credential(id),
    FOREIGN KEY (credential_id_institution) REFERENCES student_institution_credential(id)
) ENGINE=InnoDB;

CREATE TABLE merkle_tree_root_history (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    student_id CHAR(36) NOT NULL,
    root_hash CHAR(64) NOT NULL,
    leaf_count INT NOT NULL,
    tree_level_count INT NOT NULL,
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_current BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (student_id) REFERENCES student(id)
) ENGINE=InnoDB;

DELIMITER $$
CREATE FUNCTION fn_normalize_text(p_input TEXT)
RETURNS TEXT
DETERMINISTIC
BEGIN
    RETURN LOWER(TRIM(IFNULL(p_input, '')));
END$$

CREATE FUNCTION fn_hash_personal_credential(
    p_student_id CHAR(36),
    p_father_name TEXT,
    p_mother_name TEXT,
    p_tenth_grade_marks DECIMAL(5,2),
    p_twelfth_grade_marks DECIMAL(5,2),
    p_city TEXT,
    p_state TEXT,
    p_permanent_address TEXT
)
RETURNS CHAR(64)
DETERMINISTIC
BEGIN
    RETURN SHA2(
        CONCAT_WS('|',
            fn_normalize_text(p_student_id),
            fn_normalize_text(p_father_name),
            fn_normalize_text(p_mother_name),
            IFNULL(CAST(p_tenth_grade_marks AS CHAR), ''),
            IFNULL(CAST(p_twelfth_grade_marks AS CHAR), ''),
            fn_normalize_text(p_city),
            fn_normalize_text(p_state),
            fn_normalize_text(p_permanent_address)
        ),
        256
    );
END$$

CREATE FUNCTION fn_hash_institution_credential(
    p_student_id CHAR(36),
    p_institution_id CHAR(36),
    p_department_id CHAR(36),
    p_personal_registration_number TEXT,
    p_cumulative_gpa DECIMAL(4,2),
    p_graduation_status VARCHAR(20),
    p_status VARCHAR(20)
)
RETURNS CHAR(64)
DETERMINISTIC
BEGIN
    RETURN SHA2(
        CONCAT_WS('|',
            fn_normalize_text(p_student_id),
            fn_normalize_text(p_institution_id),
            fn_normalize_text(p_department_id),
            fn_normalize_text(p_personal_registration_number),
            IFNULL(CAST(p_cumulative_gpa AS CHAR), ''),
            fn_normalize_text(p_graduation_status),
            fn_normalize_text(p_status)
        ),
        256
    );
END$$

CREATE FUNCTION fn_hash_merkle_leaf(
    p_field_name TEXT,
    p_field_value TEXT
)
RETURNS CHAR(64)
DETERMINISTIC
BEGIN
    RETURN SHA2(
        CONCAT_WS('|',
            fn_normalize_text(p_field_name),
            fn_normalize_text(p_field_value)
        ),
        256
    );
END$$

CREATE FUNCTION fn_merkle_parent_hash(
    p_left_hash CHAR(64),
    p_right_hash CHAR(64)
)
RETURNS CHAR(64)
DETERMINISTIC
BEGIN
    RETURN SHA2(CONCAT(IFNULL(p_left_hash, ''), '|', IFNULL(p_right_hash, '')), 256);
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER trg_hash_personal_bi
BEFORE INSERT ON student_personal_credential
FOR EACH ROW
BEGIN
    SET NEW.credential_hash = fn_hash_personal_credential(
        NEW.student_id,
        NEW.father_name,
        NEW.mother_name,
        NEW.tenth_grade_marks,
        NEW.twelfth_grade_marks,
        NEW.city,
        NEW.state,
        NEW.permanent_address
    );
END$$

CREATE TRIGGER trg_hash_personal_bu
BEFORE UPDATE ON student_personal_credential
FOR EACH ROW
BEGIN
    SET NEW.credential_hash = fn_hash_personal_credential(
        NEW.student_id,
        NEW.father_name,
        NEW.mother_name,
        NEW.tenth_grade_marks,
        NEW.twelfth_grade_marks,
        NEW.city,
        NEW.state,
        NEW.permanent_address
    );
END$$

CREATE TRIGGER trg_hash_institution_bi
BEFORE INSERT ON student_institution_credential
FOR EACH ROW
BEGIN
    SET NEW.credential_hash = fn_hash_institution_credential(
        NEW.student_id,
        NEW.institution_id,
        NEW.department_id,
        NEW.personal_registration_number,
        NEW.cumulative_gpa,
        NEW.graduation_status,
        NEW.status
    );
END$$

CREATE TRIGGER trg_hash_institution_bu
BEFORE UPDATE ON student_institution_credential
FOR EACH ROW
BEGIN
    SET NEW.credential_hash = fn_hash_institution_credential(
        NEW.student_id,
        NEW.institution_id,
        NEW.department_id,
        NEW.personal_registration_number,
        NEW.cumulative_gpa,
        NEW.graduation_status,
        NEW.status
    );
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER trg_personal_audit_ai
AFTER INSERT ON student_personal_credential
FOR EACH ROW
BEGIN
    INSERT INTO credential_track_log (
        id,
        credential_type,
        credential_id_personal,
        credential_id_institution,
        action,
        old_hash,
        new_hash,
        old_snapshot,
        new_snapshot,
        changed_by_admin_id,
        changed_by_student_id,
        request_id,
        remarks
    )
    VALUES (
        UUID(),
        'PERSONAL',
        NEW.id,
        NULL,
        'CREATED',
        NULL,
        NEW.credential_hash,
        NULL,
        JSON_OBJECT(
            'student_id', NEW.student_id,
            'father_name', NEW.father_name,
            'mother_name', NEW.mother_name,
            'tenth_grade_marks', NEW.tenth_grade_marks,
            'twelfth_grade_marks', NEW.twelfth_grade_marks,
            'city', NEW.city,
            'state', NEW.state,
            'permanent_address', NEW.permanent_address
        ),
        @actor_admin_id,
        @actor_student_id,
        @request_id,
        IFNULL(@change_remarks, 'Personal credential created')
    );
END$$

CREATE TRIGGER trg_personal_audit_au
AFTER UPDATE ON student_personal_credential
FOR EACH ROW
BEGIN
    INSERT INTO credential_track_log (
        id,
        credential_type,
        credential_id_personal,
        credential_id_institution,
        action,
        old_hash,
        new_hash,
        old_snapshot,
        new_snapshot,
        changed_by_admin_id,
        changed_by_student_id,
        request_id,
        remarks
    )
    VALUES (
        UUID(),
        'PERSONAL',
        NEW.id,
        NULL,
        IFNULL(@audit_action_override, 'UPDATED'),
        OLD.credential_hash,
        NEW.credential_hash,
        JSON_OBJECT(
            'student_id', OLD.student_id,
            'father_name', OLD.father_name,
            'mother_name', OLD.mother_name,
            'tenth_grade_marks', OLD.tenth_grade_marks,
            'twelfth_grade_marks', OLD.twelfth_grade_marks,
            'city', OLD.city,
            'state', OLD.state,
            'permanent_address', OLD.permanent_address
        ),
        JSON_OBJECT(
            'student_id', NEW.student_id,
            'father_name', NEW.father_name,
            'mother_name', NEW.mother_name,
            'tenth_grade_marks', NEW.tenth_grade_marks,
            'twelfth_grade_marks', NEW.twelfth_grade_marks,
            'city', NEW.city,
            'state', NEW.state,
            'permanent_address', NEW.permanent_address
        ),
        @actor_admin_id,
        @actor_student_id,
        @request_id,
        IFNULL(@change_remarks, 'Personal credential updated')
    );
END$$

CREATE TRIGGER trg_institution_audit_ai
AFTER INSERT ON student_institution_credential
FOR EACH ROW
BEGIN
    INSERT INTO credential_track_log (
        id,
        credential_type,
        credential_id_personal,
        credential_id_institution,
        action,
        old_hash,
        new_hash,
        old_snapshot,
        new_snapshot,
        changed_by_admin_id,
        changed_by_student_id,
        request_id,
        remarks
    )
    VALUES (
        UUID(),
        'INSTITUTIONAL',
        NULL,
        NEW.id,
        'CREATED',
        NULL,
        NEW.credential_hash,
        NULL,
        JSON_OBJECT(
            'student_id', NEW.student_id,
            'institution_id', NEW.institution_id,
            'department_id', NEW.department_id,
            'personal_registration_number', NEW.personal_registration_number,
            'cumulative_gpa', NEW.cumulative_gpa,
            'graduation_status', NEW.graduation_status,
            'status', NEW.status
        ),
        @actor_admin_id,
        @actor_student_id,
        @request_id,
        IFNULL(@change_remarks, 'Institution credential created')
    );
END$$

CREATE TRIGGER trg_institution_audit_au
AFTER UPDATE ON student_institution_credential
FOR EACH ROW
BEGIN
    INSERT INTO credential_track_log (
        id,
        credential_type,
        credential_id_personal,
        credential_id_institution,
        action,
        old_hash,
        new_hash,
        old_snapshot,
        new_snapshot,
        changed_by_admin_id,
        changed_by_student_id,
        request_id,
        remarks
    )
    VALUES (
        UUID(),
        'INSTITUTIONAL',
        NULL,
        NEW.id,
        IFNULL(@audit_action_override, 'UPDATED'),
        OLD.credential_hash,
        NEW.credential_hash,
        JSON_OBJECT(
            'student_id', OLD.student_id,
            'institution_id', OLD.institution_id,
            'department_id', OLD.department_id,
            'personal_registration_number', OLD.personal_registration_number,
            'cumulative_gpa', OLD.cumulative_gpa,
            'graduation_status', OLD.graduation_status,
            'status', OLD.status
        ),
        JSON_OBJECT(
            'student_id', NEW.student_id,
            'institution_id', NEW.institution_id,
            'department_id', NEW.department_id,
            'personal_registration_number', NEW.personal_registration_number,
            'cumulative_gpa', NEW.cumulative_gpa,
            'graduation_status', NEW.graduation_status,
            'status', NEW.status
        ),
        @actor_admin_id,
        @actor_student_id,
        @request_id,
        IFNULL(@change_remarks, 'Institution credential updated')
    );
END$$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE sp_verify_personal_credential_integrity(IN p_credential_id CHAR(36))
BEGIN
    DECLARE v_student_id CHAR(36);
    DECLARE v_stored_hash CHAR(64);
    DECLARE v_recalculated_hash CHAR(64);

    SELECT
        student_id,
        credential_hash,
        fn_hash_personal_credential(
            student_id,
            father_name,
            mother_name,
            tenth_grade_marks,
            twelfth_grade_marks,
            city,
            state,
            permanent_address
        )
    INTO v_student_id, v_stored_hash, v_recalculated_hash
    FROM student_personal_credential
    WHERE id = p_credential_id;

    IF v_stored_hash <> v_recalculated_hash THEN
        INSERT INTO tampered_credential_log (
            id,
            student_id,
            credential_type,
            credential_id_personal,
            credential_id_institution,
            stored_hash,
            recalculated_hash,
            detected_by,
            rollback_status,
            remarks
        )
        VALUES (
            UUID(),
            v_student_id,
            'PERSONAL',
            p_credential_id,
            NULL,
            v_stored_hash,
            v_recalculated_hash,
            'DB_PROCEDURE',
            'PENDING',
            'Personal credential hash mismatch detected'
        );
    END IF;
END$$

CREATE PROCEDURE sp_verify_institution_credential_integrity(IN p_credential_id CHAR(36))
BEGIN
    DECLARE v_student_id CHAR(36);
    DECLARE v_stored_hash CHAR(64);
    DECLARE v_recalculated_hash CHAR(64);

    SELECT
        student_id,
        credential_hash,
        fn_hash_institution_credential(
            student_id,
            institution_id,
            department_id,
            personal_registration_number,
            cumulative_gpa,
            graduation_status,
            status
        )
    INTO v_student_id, v_stored_hash, v_recalculated_hash
    FROM student_institution_credential
    WHERE id = p_credential_id;

    IF v_stored_hash <> v_recalculated_hash THEN
        INSERT INTO tampered_credential_log (
            id,
            student_id,
            credential_type,
            credential_id_personal,
            credential_id_institution,
            stored_hash,
            recalculated_hash,
            detected_by,
            rollback_status,
            remarks
        )
        VALUES (
            UUID(),
            v_student_id,
            'INSTITUTIONAL',
            NULL,
            p_credential_id,
            v_stored_hash,
            v_recalculated_hash,
            'DB_PROCEDURE',
            'PENDING',
            'Institution credential hash mismatch detected'
        );
    END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE sp_rebuild_merkle_leaves_for_student(IN p_student_id CHAR(36))
BEGIN
    DECLARE v_next_version INT;

    SET v_next_version = IFNULL(
        (SELECT MAX(version_no) FROM merkle_tree_leaf_nodes WHERE student_id = p_student_id),
        0
    ) + 1;

    UPDATE merkle_tree_leaf_nodes
    SET is_active = FALSE
    WHERE student_id = p_student_id
      AND is_active = TRUE;

    SET @leaf_pos := 0;

    INSERT INTO merkle_tree_leaf_nodes (
        student_id,
        credential_type,
        credential_id_personal,
        credential_id_institution,
        field_name,
        field_hash,
        leaf_hash,
        leaf_position,
        version_no,
        is_active
    )
    SELECT
        p_student_id,
        src.credential_type,
        src.credential_id_personal,
        src.credential_id_institution,
        src.field_name,
        SHA2(fn_normalize_text(src.field_value), 256) AS field_hash,
        fn_hash_merkle_leaf(src.field_name, src.field_value) AS leaf_hash,
        (@leaf_pos := @leaf_pos + 1) AS leaf_position,
        v_next_version,
        TRUE
    FROM (
        SELECT
            'PERSONAL' AS credential_type,
            spc.id AS credential_id_personal,
            NULL AS credential_id_institution,
            'father_name' AS field_name,
            IFNULL(spc.father_name, '') AS field_value,
            1 AS sort_group,
            1 AS sort_order,
            spc.id AS record_id
        FROM student_personal_credential spc
        WHERE spc.student_id = p_student_id

        UNION ALL
        SELECT 'PERSONAL', spc.id, NULL, 'mother_name', IFNULL(spc.mother_name, ''), 1, 2, spc.id
        FROM student_personal_credential spc
        WHERE spc.student_id = p_student_id

        UNION ALL
        SELECT 'PERSONAL', spc.id, NULL, 'tenth_grade_marks', IFNULL(CAST(spc.tenth_grade_marks AS CHAR), ''), 1, 3, spc.id
        FROM student_personal_credential spc
        WHERE spc.student_id = p_student_id

        UNION ALL
        SELECT 'PERSONAL', spc.id, NULL, 'twelfth_grade_marks', IFNULL(CAST(spc.twelfth_grade_marks AS CHAR), ''), 1, 4, spc.id
        FROM student_personal_credential spc
        WHERE spc.student_id = p_student_id

        UNION ALL
        SELECT 'PERSONAL', spc.id, NULL, 'city', IFNULL(spc.city, ''), 1, 5, spc.id
        FROM student_personal_credential spc
        WHERE spc.student_id = p_student_id

        UNION ALL
        SELECT 'PERSONAL', spc.id, NULL, 'state', IFNULL(spc.state, ''), 1, 6, spc.id
        FROM student_personal_credential spc
        WHERE spc.student_id = p_student_id

        UNION ALL
        SELECT 'PERSONAL', spc.id, NULL, 'permanent_address', IFNULL(spc.permanent_address, ''), 1, 7, spc.id
        FROM student_personal_credential spc
        WHERE spc.student_id = p_student_id

        UNION ALL
        SELECT
            'INSTITUTIONAL',
            NULL,
            sic.id,
            'institution_id',
            IFNULL(sic.institution_id, ''),
            2,
            1,
            sic.id
        FROM student_institution_credential sic
        WHERE sic.student_id = p_student_id

        UNION ALL
        SELECT 'INSTITUTIONAL', NULL, sic.id, 'department_id', IFNULL(sic.department_id, ''), 2, 2, sic.id
        FROM student_institution_credential sic
        WHERE sic.student_id = p_student_id

        UNION ALL
        SELECT 'INSTITUTIONAL', NULL, sic.id, 'personal_registration_number', IFNULL(sic.personal_registration_number, ''), 2, 3, sic.id
        FROM student_institution_credential sic
        WHERE sic.student_id = p_student_id

        UNION ALL
        SELECT 'INSTITUTIONAL', NULL, sic.id, 'cumulative_gpa', IFNULL(CAST(sic.cumulative_gpa AS CHAR), ''), 2, 4, sic.id
        FROM student_institution_credential sic
        WHERE sic.student_id = p_student_id

        UNION ALL
        SELECT 'INSTITUTIONAL', NULL, sic.id, 'graduation_status', IFNULL(sic.graduation_status, ''), 2, 5, sic.id
        FROM student_institution_credential sic
        WHERE sic.student_id = p_student_id

        UNION ALL
        SELECT 'INSTITUTIONAL', NULL, sic.id, 'status', IFNULL(sic.status, ''), 2, 6, sic.id
        FROM student_institution_credential sic
        WHERE sic.student_id = p_student_id
    ) AS src
    ORDER BY src.sort_group, src.record_id, src.sort_order;
END$$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE sp_store_merkle_root(IN p_student_id CHAR(36))
BEGIN
    DECLARE v_active_version INT;
    DECLARE v_leaf_count INT;
    DECLARE v_tree_level_count INT DEFAULT 0;
    DECLARE v_current_count INT;
    DECLARE v_root_hash CHAR(64);

    SELECT MAX(version_no)
    INTO v_active_version
    FROM merkle_tree_leaf_nodes
    WHERE student_id = p_student_id
      AND is_active = TRUE;

    IF v_active_version IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No active Merkle leaves found for this student';
    END IF;

    SELECT COUNT(*)
    INTO v_leaf_count
    FROM merkle_tree_leaf_nodes
    WHERE student_id = p_student_id
      AND version_no = v_active_version
      AND is_active = TRUE;

    DROP TEMPORARY TABLE IF EXISTS tmp_merkle_nodes;
    DROP TEMPORARY TABLE IF EXISTS tmp_merkle_nodes_copy;
    DROP TEMPORARY TABLE IF EXISTS tmp_merkle_next;

    CREATE TEMPORARY TABLE tmp_merkle_nodes (
        seq INT AUTO_INCREMENT PRIMARY KEY,
        node_hash CHAR(64) NOT NULL
    );

    INSERT INTO tmp_merkle_nodes (node_hash)
    SELECT leaf_hash
    FROM merkle_tree_leaf_nodes
    WHERE student_id = p_student_id
      AND version_no = v_active_version
      AND is_active = TRUE
    ORDER BY leaf_position;

    SET v_current_count = (SELECT COUNT(*) FROM tmp_merkle_nodes);
    SET v_tree_level_count = 1;

    WHILE v_current_count > 1 DO

        DROP TEMPORARY TABLE IF EXISTS tmp_merkle_nodes_copy;
        CREATE TEMPORARY TABLE tmp_merkle_nodes_copy
        AS
        SELECT seq, node_hash
        FROM tmp_merkle_nodes;

        DROP TEMPORARY TABLE IF EXISTS tmp_merkle_next;
        CREATE TEMPORARY TABLE tmp_merkle_next (
            seq INT AUTO_INCREMENT PRIMARY KEY,
            node_hash CHAR(64) NOT NULL
        );

        INSERT INTO tmp_merkle_next (node_hash)
        SELECT fn_merkle_parent_hash(
                   t1.node_hash,
                   COALESCE(t2.node_hash, t1.node_hash)
               )
        FROM tmp_merkle_nodes t1
        LEFT JOIN tmp_merkle_nodes_copy t2
               ON t2.seq = t1.seq + 1
        WHERE MOD(t1.seq, 2) = 1
        ORDER BY t1.seq;

        TRUNCATE TABLE tmp_merkle_nodes;

        INSERT INTO tmp_merkle_nodes (node_hash)
        SELECT node_hash
        FROM tmp_merkle_next
        ORDER BY seq;

        DROP TEMPORARY TABLE IF EXISTS tmp_merkle_nodes_copy;
        DROP TEMPORARY TABLE IF EXISTS tmp_merkle_next;

        SET v_current_count = (SELECT COUNT(*) FROM tmp_merkle_nodes);
        SET v_tree_level_count = v_tree_level_count + 1;
    END WHILE;

    SELECT node_hash
    INTO v_root_hash
    FROM tmp_merkle_nodes
    LIMIT 1;

    UPDATE merkle_tree_root_history
    SET is_current = FALSE
    WHERE student_id = p_student_id
      AND is_current = TRUE;

    INSERT INTO merkle_tree_root_history (
        id,
        student_id,
        root_hash,
        leaf_count,
        tree_level_count,
        is_current
    )
    VALUES (
        UUID(),
        p_student_id,
        v_root_hash,
        v_leaf_count,
        v_tree_level_count,
        TRUE
    );

    DROP TEMPORARY TABLE IF EXISTS tmp_merkle_nodes;
    DROP TEMPORARY TABLE IF EXISTS tmp_merkle_nodes_copy;
    DROP TEMPORARY TABLE IF EXISTS tmp_merkle_next;
END$$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE sp_verify_student_merkle_integrity(IN p_student_id CHAR(36))
BEGIN
    DECLARE v_active_version INT;
    DECLARE v_leaf_count INT DEFAULT 0;
    DECLARE v_tree_level_count INT DEFAULT 0;
    DECLARE v_current_count INT DEFAULT 0;
    DECLARE v_stored_root CHAR(64);
    DECLARE v_recomputed_root CHAR(64);
    DECLARE v_stored_leaf_count INT;
    DECLARE v_stored_tree_level_count INT;
    DECLARE v_current_root_count INT DEFAULT 0;
    DECLARE v_root_generated_at DATETIME DEFAULT NULL;
    DECLARE v_latest_credential_modified_at DATETIME DEFAULT NULL;
    DECLARE v_latest_active_leaf_created_at DATETIME DEFAULT NULL;
    DECLARE v_status VARCHAR(30);
    DECLARE v_remarks TEXT;

    SELECT MAX(version_no)
    INTO v_active_version
    FROM merkle_tree_leaf_nodes
    WHERE student_id = p_student_id
      AND is_active = TRUE;

    SELECT COUNT(*), MAX(created_at)
    INTO v_leaf_count, v_latest_active_leaf_created_at
    FROM merkle_tree_leaf_nodes
    WHERE student_id = p_student_id
      AND version_no = v_active_version
      AND is_active = TRUE;

    SELECT COUNT(*)
    INTO v_current_root_count
    FROM merkle_tree_root_history
    WHERE student_id = p_student_id
      AND is_current = TRUE;

    SELECT
        current_root.root_hash,
        current_root.leaf_count,
        current_root.tree_level_count,
        current_root.generated_at
    INTO
        v_stored_root,
        v_stored_leaf_count,
        v_stored_tree_level_count,
        v_root_generated_at
    FROM (SELECT 1) AS anchor
    LEFT JOIN (
        SELECT root_hash, leaf_count, tree_level_count, generated_at
        FROM merkle_tree_root_history
        WHERE student_id = p_student_id
          AND is_current = TRUE
        ORDER BY generated_at DESC, id DESC
        LIMIT 1
    ) AS current_root
      ON TRUE;

    SELECT MAX(modified_at)
    INTO v_latest_credential_modified_at
    FROM (
        SELECT last_modified_at AS modified_at
        FROM student_personal_credential
        WHERE student_id = p_student_id

        UNION ALL

        SELECT last_modified_at
        FROM student_institution_credential
        WHERE student_id = p_student_id
    ) AS credential_updates;

    IF v_active_version IS NULL OR v_leaf_count = 0 THEN
        SET v_status = 'MISSING_LEAVES';
        SET v_remarks = 'No active Merkle leaves found for this student';
    ELSEIF v_stored_root IS NULL THEN
        SET v_status = 'MISSING_ROOT';
        SET v_remarks = 'No current Merkle root found for this student';
    ELSE
        DROP TEMPORARY TABLE IF EXISTS tmp_verify_merkle_nodes;
        DROP TEMPORARY TABLE IF EXISTS tmp_verify_merkle_nodes_copy;
        DROP TEMPORARY TABLE IF EXISTS tmp_verify_merkle_next;

        CREATE TEMPORARY TABLE tmp_verify_merkle_nodes (
            seq INT AUTO_INCREMENT PRIMARY KEY,
            node_hash CHAR(64) NOT NULL
        );

        INSERT INTO tmp_verify_merkle_nodes (node_hash)
        SELECT leaf_hash
        FROM merkle_tree_leaf_nodes
        WHERE student_id = p_student_id
          AND version_no = v_active_version
          AND is_active = TRUE
        ORDER BY leaf_position;

        SET v_current_count = (SELECT COUNT(*) FROM tmp_verify_merkle_nodes);
        SET v_tree_level_count = 1;

        WHILE v_current_count > 1 DO
            DROP TEMPORARY TABLE IF EXISTS tmp_verify_merkle_nodes_copy;
            CREATE TEMPORARY TABLE tmp_verify_merkle_nodes_copy
            AS
            SELECT seq, node_hash
            FROM tmp_verify_merkle_nodes;

            DROP TEMPORARY TABLE IF EXISTS tmp_verify_merkle_next;
            CREATE TEMPORARY TABLE tmp_verify_merkle_next (
                seq INT AUTO_INCREMENT PRIMARY KEY,
                node_hash CHAR(64) NOT NULL
            );

            INSERT INTO tmp_verify_merkle_next (node_hash)
            SELECT fn_merkle_parent_hash(
                       t1.node_hash,
                       COALESCE(t2.node_hash, t1.node_hash)
                   )
            FROM tmp_verify_merkle_nodes t1
            LEFT JOIN tmp_verify_merkle_nodes_copy t2
                   ON t2.seq = t1.seq + 1
            WHERE MOD(t1.seq, 2) = 1
            ORDER BY t1.seq;

            TRUNCATE TABLE tmp_verify_merkle_nodes;

            INSERT INTO tmp_verify_merkle_nodes (node_hash)
            SELECT node_hash
            FROM tmp_verify_merkle_next
            ORDER BY seq;

            DROP TEMPORARY TABLE IF EXISTS tmp_verify_merkle_nodes_copy;
            DROP TEMPORARY TABLE IF EXISTS tmp_verify_merkle_next;

            SET v_current_count = (SELECT COUNT(*) FROM tmp_verify_merkle_nodes);
            SET v_tree_level_count = v_tree_level_count + 1;
        END WHILE;

        SELECT node_hash
        INTO v_recomputed_root
        FROM tmp_verify_merkle_nodes
        LIMIT 1;

        IF v_current_root_count > 1 THEN
            SET v_status = 'MULTIPLE_CURRENT_ROOTS';
            SET v_remarks = 'Multiple Merkle roots are marked current for this student';
        ELSEIF v_recomputed_root <> v_stored_root
           OR v_leaf_count <> IFNULL(v_stored_leaf_count, -1)
           OR v_tree_level_count <> IFNULL(v_stored_tree_level_count, -1) THEN
            SET v_status = 'MISMATCH';
            SET v_remarks = 'Merkle root mismatch detected';

            INSERT INTO tampered_credential_log (
                id,
                student_id,
                credential_type,
                credential_id_personal,
                credential_id_institution,
                stored_hash,
                recalculated_hash,
                detected_by,
                rollback_status,
                remarks
            )
            SELECT
                UUID(),
                p_student_id,
                NULL,
                NULL,
                NULL,
                v_stored_root,
                v_recomputed_root,
                'DB_MERKLE_VERIFY',
                'PENDING',
                'Merkle root mismatch detected'
            WHERE NOT EXISTS (
                SELECT 1
                FROM tampered_credential_log
                WHERE student_id = p_student_id
                  AND detected_by = 'DB_MERKLE_VERIFY'
                  AND rollback_status = 'PENDING'
                  AND stored_hash <=> v_stored_root
                  AND recalculated_hash <=> v_recomputed_root
                  AND remarks = 'Merkle root mismatch detected'
            );
        ELSEIF v_latest_credential_modified_at IS NOT NULL
              AND (
                  v_latest_credential_modified_at > v_root_generated_at
                  OR v_latest_credential_modified_at > v_latest_active_leaf_created_at
              ) THEN
            SET v_status = 'STALE_ROOT';
            SET v_remarks = 'Merkle state stale after credential update';
        ELSE
            SET v_status = 'VALID';
            SET v_remarks = 'Stored Merkle root matches active leaves';
        END IF;

        DROP TEMPORARY TABLE IF EXISTS tmp_verify_merkle_nodes;
        DROP TEMPORARY TABLE IF EXISTS tmp_verify_merkle_nodes_copy;
        DROP TEMPORARY TABLE IF EXISTS tmp_verify_merkle_next;
    END IF;

    SELECT
        p_student_id AS student_id,
        v_stored_root AS stored_root,
        v_recomputed_root AS recomputed_root,
        v_leaf_count AS leaf_count,
        v_active_version AS version_no,
        v_current_root_count AS current_root_count,
        v_tree_level_count AS recomputed_tree_level_count,
        v_root_generated_at AS current_root_timestamp,
        v_latest_credential_modified_at AS latest_credential_modified_at,
        v_status AS status,
        v_remarks AS remarks;
END$$
DELIMITER ;

CREATE VIEW vw_integrity_status AS
SELECT
    s.id AS student_id,
    r.root_hash AS current_root_hash,
    IFNULL(l.leaf_count, 0) AS leaf_count,
    r.generated_at AS root_generated_at,
    IFNULL(rc.current_root_count, 0) AS current_root_count,
    t.latest_tamper_time,
    CASE
        WHEN IFNULL(l.leaf_count, 0) = 0 THEN 'MISSING_LEAVES'
        WHEN r.root_hash IS NULL THEN 'MISSING_ROOT'
        WHEN IFNULL(rc.current_root_count, 0) > 1 THEN 'MULTIPLE_CURRENT_ROOTS'
        WHEN t.latest_tamper_time IS NOT NULL THEN 'TAMPERED_OR_MISMATCHED'
        WHEN c.latest_credential_modified_at IS NOT NULL
             AND (
                 c.latest_credential_modified_at > r.generated_at
                 OR c.latest_credential_modified_at > l.latest_leaf_created_at
             ) THEN 'STALE_ROOT'
        ELSE 'VALID'
    END AS integrity_status,
    CASE
        WHEN IFNULL(l.leaf_count, 0) = 0 THEN 'No active Merkle leaves found'
        WHEN r.root_hash IS NULL THEN 'No current Merkle root found'
        WHEN IFNULL(rc.current_root_count, 0) > 1 THEN 'Multiple Merkle roots are marked current'
        WHEN t.latest_tamper_time IS NOT NULL THEN t.latest_tamper_remarks
        WHEN c.latest_credential_modified_at IS NOT NULL
             AND (
                 c.latest_credential_modified_at > r.generated_at
                 OR c.latest_credential_modified_at > l.latest_leaf_created_at
             ) THEN 'Merkle state stale after credential update'
        ELSE 'Stored Merkle root is current with active leaves'
    END AS remarks
FROM student s
LEFT JOIN (
    SELECT
        student_id,
        COUNT(*) AS leaf_count,
        MAX(version_no) AS active_version_no,
        MAX(created_at) AS latest_leaf_created_at
    FROM merkle_tree_leaf_nodes
    WHERE is_active = TRUE
    GROUP BY student_id
) l
  ON l.student_id = s.id
LEFT JOIN (
    SELECT r1.student_id, r1.root_hash, r1.leaf_count, r1.generated_at
    FROM merkle_tree_root_history r1
    WHERE r1.is_current = TRUE
      AND NOT EXISTS (
          SELECT 1
          FROM merkle_tree_root_history r2
          WHERE r2.student_id = r1.student_id
            AND r2.is_current = TRUE
            AND (
                r2.generated_at > r1.generated_at
                OR (
                    r2.generated_at = r1.generated_at
                    AND r2.id > r1.id
                )
            )
      )
) r
  ON r.student_id = s.id
LEFT JOIN (
    SELECT student_id, COUNT(*) AS current_root_count
    FROM merkle_tree_root_history
    WHERE is_current = TRUE
    GROUP BY student_id
) rc
  ON rc.student_id = s.id
LEFT JOIN (
    SELECT student_id, MAX(modified_at) AS latest_credential_modified_at
    FROM (
        SELECT student_id, last_modified_at AS modified_at
        FROM student_personal_credential

        UNION ALL

        SELECT student_id, last_modified_at
        FROM student_institution_credential
    ) credential_updates
    GROUP BY student_id
) c
  ON c.student_id = s.id
LEFT JOIN (
    SELECT
        student_id,
        MAX(tampering_found) AS latest_tamper_time,
        MAX(remarks) AS latest_tamper_remarks
    FROM tampered_credential_log
    WHERE rollback_status = 'PENDING'
    GROUP BY student_id
) t
  ON t.student_id = s.id;

DELIMITER $$
CREATE PROCEDURE sp_refresh_all_merkle()
BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE v_student_id CHAR(36);

    DECLARE cur CURSOR FOR
        SELECT DISTINCT student_id
        FROM (
            SELECT student_id FROM student_personal_credential
            UNION
            SELECT student_id FROM student_institution_credential
        ) AS combined_students;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    OPEN cur;

    read_loop: LOOP
        FETCH cur INTO v_student_id;
        IF done = 1 THEN
            LEAVE read_loop;
        END IF;

        CALL sp_rebuild_merkle_leaves_for_student(v_student_id);
        CALL sp_store_merkle_root(v_student_id);
    END LOOP;

    CLOSE cur;
END$$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE sp_rollback_personal_credential(IN p_credential_id CHAR(36))
BEGIN
    DECLARE v_student_id CHAR(36);
    DECLARE v_snapshot JSON;

    SELECT student_id
    INTO v_student_id
    FROM student_personal_credential
    WHERE id = p_credential_id;

    SELECT old_snapshot
    INTO v_snapshot
    FROM credential_track_log
    WHERE credential_id_personal = p_credential_id
      AND old_snapshot IS NOT NULL
    ORDER BY modified_at DESC
    LIMIT 1;

    IF v_snapshot IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No valid rollback snapshot found for personal credential';
    END IF;

    SET @audit_action_override = 'ROLLED_BACK';
    SET @change_remarks = 'Rollback executed after tamper detection';
    SET @actor_admin_id = NULL;
    SET @actor_student_id = NULL;
    SET @request_id = NULL;

    UPDATE student_personal_credential
    SET
        father_name = JSON_UNQUOTE(JSON_EXTRACT(v_snapshot, '$.father_name')),
        mother_name = JSON_UNQUOTE(JSON_EXTRACT(v_snapshot, '$.mother_name')),
        tenth_grade_marks = CAST(JSON_UNQUOTE(JSON_EXTRACT(v_snapshot, '$.tenth_grade_marks')) AS DECIMAL(5,2)),
        twelfth_grade_marks = CAST(JSON_UNQUOTE(JSON_EXTRACT(v_snapshot, '$.twelfth_grade_marks')) AS DECIMAL(5,2)),
        city = JSON_UNQUOTE(JSON_EXTRACT(v_snapshot, '$.city')),
        state = JSON_UNQUOTE(JSON_EXTRACT(v_snapshot, '$.state')),
        permanent_address = JSON_UNQUOTE(JSON_EXTRACT(v_snapshot, '$.permanent_address'))
    WHERE id = p_credential_id;

    SET @audit_action_override = NULL;
    SET @change_remarks = NULL;
    SET @actor_admin_id = NULL;
    SET @actor_student_id = NULL;
    SET @request_id = NULL;

    UPDATE tampered_credential_log
    SET rollback_status = 'COMPLETED',
        resolved_at = CURRENT_TIMESTAMP,
        remarks = CONCAT(IFNULL(remarks, ''), ' | Personal credential rolled back successfully')
    WHERE credential_id_personal = p_credential_id
      AND rollback_status = 'PENDING';

    CALL sp_rebuild_merkle_leaves_for_student(v_student_id);
    CALL sp_store_merkle_root(v_student_id);
END$$

CREATE PROCEDURE sp_rollback_institution_credential(IN p_credential_id CHAR(36))
BEGIN
    DECLARE v_student_id CHAR(36);
    DECLARE v_snapshot JSON;

    SELECT student_id
    INTO v_student_id
    FROM student_institution_credential
    WHERE id = p_credential_id;

    SELECT old_snapshot
    INTO v_snapshot
    FROM credential_track_log
    WHERE credential_id_institution = p_credential_id
      AND old_snapshot IS NOT NULL
    ORDER BY modified_at DESC
    LIMIT 1;

    IF v_snapshot IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No valid rollback snapshot found for institution credential';
    END IF;

    SET @audit_action_override = 'ROLLED_BACK';
    SET @change_remarks = 'Rollback executed after tamper detection';
    SET @actor_admin_id = NULL;
    SET @actor_student_id = NULL;
    SET @request_id = NULL;

    UPDATE student_institution_credential
    SET
        institution_id = JSON_UNQUOTE(JSON_EXTRACT(v_snapshot, '$.institution_id')),
        department_id = JSON_UNQUOTE(JSON_EXTRACT(v_snapshot, '$.department_id')),
        personal_registration_number = JSON_UNQUOTE(JSON_EXTRACT(v_snapshot, '$.personal_registration_number')),
        cumulative_gpa = CAST(JSON_UNQUOTE(JSON_EXTRACT(v_snapshot, '$.cumulative_gpa')) AS DECIMAL(4,2)),
        graduation_status = JSON_UNQUOTE(JSON_EXTRACT(v_snapshot, '$.graduation_status')),
        status = JSON_UNQUOTE(JSON_EXTRACT(v_snapshot, '$.status'))
    WHERE id = p_credential_id;

    SET @audit_action_override = NULL;
    SET @change_remarks = NULL;
    SET @actor_admin_id = NULL;
    SET @actor_student_id = NULL;
    SET @request_id = NULL;

    UPDATE tampered_credential_log
    SET rollback_status = 'COMPLETED',
        resolved_at = CURRENT_TIMESTAMP,
        remarks = CONCAT(IFNULL(remarks, ''), ' | Institution credential rolled back successfully')
    WHERE credential_id_institution = p_credential_id
      AND rollback_status = 'PENDING';

    CALL sp_rebuild_merkle_leaves_for_student(v_student_id);
    CALL sp_store_merkle_root(v_student_id);
END$$
DELIMITER ;
