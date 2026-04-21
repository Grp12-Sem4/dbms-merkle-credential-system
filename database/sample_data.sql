INSERT INTO admin (full_name, email, phone_number, city, state, address, password_hash)
VALUES
('Amit Sharma', 'amit.admin@system.com', '9876543210', 'Pune', 'Maharashtra', 'Shivajinagar', SHA2('adminpass1',256)),
('Neha Kulkarni', 'neha.admin@system.com', '9876543211', 'Mumbai', 'Maharashtra', 'Andheri', SHA2('adminpass2',256));

INSERT INTO student (full_name, email, date_of_birth, password_hash)
VALUES
('Rahul Patil', 'rahul.patil@student.com', '2002-03-12', SHA2('pass1',256)),
('Sneha Joshi', 'sneha.joshi@student.com', '2001-11-21', SHA2('pass2',256)),
('Aditya Deshmukh', 'aditya.d@student.com', '2000-07-08', SHA2('pass3',256)),
('Pooja Kulkarni', 'pooja.k@student.com', '2003-02-14', SHA2('pass4',256)),
('Rohan Mehta', 'rohan.m@student.com', '2002-09-19', SHA2('pass5',256));

INSERT INTO existing_student (id, enrollment_year, graduation_year)
SELECT id, 2022, 2026
FROM student
WHERE email = 'rahul.patil@student.com';

INSERT INTO existing_student (id, enrollment_year, graduation_year)
SELECT id, 2023, 2027
FROM student
WHERE email = 'sneha.joshi@student.com';

INSERT INTO alumni (id, graduation_year)
SELECT id, 2022
FROM student
WHERE email = 'aditya.d@student.com';

INSERT INTO alumni (id, graduation_year)
SELECT id, 2023
FROM student
WHERE email = 'rohan.m@student.com';

INSERT INTO department (name)
VALUES
('Computer Engineering'),
('Information Technology'),
('Electronics Engineering'),
('Mechanical Engineering');

INSERT INTO institution (name, accreditation_type, accreditation_grade, contact, institution_email)
VALUES
('Vishwakarma Institute of Technology', 'NAAC', 'A++', '02024567890', 'vit@edu.in'),
('Pune University', 'NIRF', 'A+', '02025678901', 'puneuni@edu.in'),
('MIT World Peace University', 'NBA', 'A', '02027890012', 'mitwpu@edu.in');

INSERT INTO verifier (name, verifier_type, organization_name, contact_email, password_hash)
VALUES
('TCS HR', 'COMPANY', 'Tata Consultancy Services', 'hr@tcs.com', SHA2('tcsverify',256)),
('Infosys Recruitment', 'COMPANY', 'Infosys Ltd', 'verify@infosys.com', SHA2('infosysverify',256)),
('Government Education Board', 'GOVERNMENT_AGENCY', 'Education Ministry', 'verify@gov.in', SHA2('govverify',256));

SET @actor_admin_id = NULL;
SET @actor_student_id = NULL;
SET @request_id = NULL;
SET @change_remarks = 'Initial sample data insertion';
SET @audit_action_override = NULL;

INSERT INTO student_institution_credential (
    student_id,
    institution_id,
    department_id,
    personal_registration_number,
    cumulative_gpa,
    graduation_status
)
VALUES
(
    (SELECT id FROM student WHERE email='rahul.patil@student.com'),
    (SELECT id FROM institution WHERE name='Vishwakarma Institute of Technology'),
    (SELECT id FROM department WHERE name='Computer Engineering'),
    'PRN001',
    8.72,
    'PURSUING'
),
(
    (SELECT id FROM student WHERE email='sneha.joshi@student.com'),
    (SELECT id FROM institution WHERE name='Vishwakarma Institute of Technology'),
    (SELECT id FROM department WHERE name='Information Technology'),
    'PRN002',
    9.10,
    'PURSUING'
),
(
    (SELECT id FROM student WHERE email='aditya.d@student.com'),
    (SELECT id FROM institution WHERE name='Pune University'),
    (SELECT id FROM department WHERE name='Computer Engineering'),
    'PRN003',
    8.50,
    'GRADUATED'
);

INSERT INTO student_personal_credential (
    student_id,
    father_name,
    mother_name,
    tenth_grade_marks,
    twelfth_grade_marks,
    city,
    state,
    permanent_address
)
VALUES
(
    (SELECT id FROM student WHERE email='rahul.patil@student.com'),
    'Sunil Patil',
    'Anita Patil',
    88.50,
    91.30,
    'Pune',
    'Maharashtra',
    'Karve Nagar'
),
(
    (SELECT id FROM student WHERE email='sneha.joshi@student.com'),
    'Mahesh Joshi',
    'Lata Joshi',
    92.10,
    94.00,
    'Mumbai',
    'Maharashtra',
    'Borivali'
),
(
    (SELECT id FROM student WHERE email='aditya.d@student.com'),
    'Suresh Deshmukh',
    'Meena Deshmukh',
    86.00,
    89.20,
    'Nagpur',
    'Maharashtra',
    'Dharampeth'
);

-- Build Merkle leaves + roots after credential inserts
CALL sp_refresh_all_merkle();

INSERT INTO credential_change_request (
    admin_id,
    student_id,
    credential_type,
    credential_id_institution,
    reason,
    requested_changes,
    status
)
VALUES
(
    (SELECT id FROM admin WHERE email='amit.admin@system.com'),
    (SELECT id FROM student WHERE email='rahul.patil@student.com'),
    'INSTITUTIONAL',
    (SELECT id FROM student_institution_credential WHERE personal_registration_number='PRN001'),
    'GPA correction request',
    JSON_OBJECT('cumulative_gpa', 8.82),
    'PENDING'
);

INSERT INTO credential_change_approval (
    request_id,
    student_id,
    admin_id,
    approval_hash,
    remarks
)
VALUES
(
    (SELECT id FROM credential_change_request LIMIT 1),
    (SELECT id FROM student WHERE email='rahul.patil@student.com'),
    (SELECT id FROM admin WHERE email='amit.admin@system.com'),
    SHA2('rahul_approved_request_1',256),
    'Student approved admin change request'
);

UPDATE credential_change_request
SET status = 'ACCEPTED',
    reviewed_at = CURRENT_TIMESTAMP
WHERE id = (SELECT id FROM (SELECT id FROM credential_change_request LIMIT 1) AS t);

SET @actor_admin_id = (SELECT id FROM admin WHERE email='amit.admin@system.com');
SET @actor_student_id = (SELECT id FROM student WHERE email='rahul.patil@student.com');
SET @request_id = (SELECT id FROM credential_change_request LIMIT 1);
SET @change_remarks = 'Approved GPA update by admin after student approval';
SET @audit_action_override = 'UPDATED';

UPDATE student_institution_credential
SET cumulative_gpa = 8.82
WHERE personal_registration_number = 'PRN001';

SET @actor_admin_id = NULL;
SET @actor_student_id = NULL;
SET @request_id = NULL;
SET @change_remarks = NULL;
SET @audit_action_override = NULL;

CALL sp_refresh_all_merkle();

INSERT INTO verification_requests (
    verifier_id,
    student_id,
    credential_type,
    credential_id_institution,
    request_status,
    purpose,
    requested_fields,
    consent_status,
    consent_expires_at,
    request_hash
)
VALUES
(
    (SELECT id FROM verifier WHERE name='TCS HR'),
    (SELECT id FROM student WHERE email='rahul.patil@student.com'),
    'INSTITUTIONAL',
    (SELECT id FROM student_institution_credential WHERE personal_registration_number='PRN001'),
    'CONSENT_GRANTED',
    'Job background verification',
    JSON_ARRAY('cumulative_gpa', 'graduation_status', 'institution_id'),
    'GRANTED',
    DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 7 DAY),
    SHA2('verification_request_rahul_tcs',256)
);

INSERT INTO verification_logs (
    request_id,
    verifier_id,
    student_id,
    credential_id_institution,
    verification_status,
    verified_claim,
    merkle_root_hash,
    verification_hash,
    proof_payload,
    remarks
)
VALUES
(
    (SELECT id FROM verification_requests LIMIT 1),
    (SELECT id FROM verifier WHERE name='TCS HR'),
    (SELECT id FROM student WHERE email='rahul.patil@student.com'),
    (SELECT id FROM student_institution_credential WHERE personal_registration_number='PRN001'),
    'VERIFIED',
    'Cumulative GPA verified as greater than 8.5',
    (
        SELECT root_hash
        FROM merkle_tree_root_history
        WHERE student_id = (SELECT id FROM student WHERE email='rahul.patil@student.com')
          AND is_current = TRUE
        LIMIT 1
    ),
    SHA2('verification_log_rahul_tcs',256),
    JSON_OBJECT(
        'claim', 'GPA > 8.5',
        'proof_type', 'Merkle root reference',
        'verifier_note', 'Matched approved institutional credential'
    ),
    'Credential verified successfully'
);

INSERT INTO credential_transfer_log (
    student_id,
    credential_type,
    credential_id_institution,
    source_institution_id,
    destination_institution_id,
    transfer_status,
    transfer_hash,
    remarks
)
VALUES
(
    (SELECT id FROM student WHERE email='rahul.patil@student.com'),
    'INSTITUTIONAL',
    (SELECT id FROM student_institution_credential WHERE personal_registration_number='PRN001'),
    (SELECT id FROM institution WHERE name='Vishwakarma Institute of Technology'),
    (SELECT id FROM institution WHERE name='Pune University'),
    'INITIATED',
    SHA2('transfer_rahul_prn001',256),
    'Sample institution transfer log'
);
