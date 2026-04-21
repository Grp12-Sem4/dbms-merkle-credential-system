-- =========================================
-- CONSENT SYSTEM SETUP
-- =========================================

USE credential_verifiability_system;

-- Drop if exists (so teammates can rerun safely)
DROP TABLE IF EXISTS verification_consent;

-- Create table
CREATE TABLE verification_consent (
    id INT AUTO_INCREMENT PRIMARY KEY,

    student_id CHAR(36) NOT NULL,
    verifier_id VARCHAR(50) NOT NULL,

    consent_granted BOOLEAN DEFAULT TRUE,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT fk_consent_student
        FOREIGN KEY (student_id)
        REFERENCES student(id)
        ON DELETE CASCADE,

    -- Avoid duplicate entries
    UNIQUE (student_id, verifier_id)
);

-- =========================================
-- SAMPLE DATA
-- =========================================

-- Grant consent
INSERT INTO verification_consent (student_id, verifier_id, consent_granted)
VALUES 
('1e8fed86-3da8-11f1-8674-00155d855c82', 'verifier_1', TRUE),

-- Denied consent example
('1e8fed86-3da8-11f1-8674-00155d855c82', 'verifier_2', FALSE);

-- =========================================
-- TEST QUERY
-- =========================================

SELECT * FROM verification_consent;