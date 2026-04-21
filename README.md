# Dynamic Credential Verifiability & Fraud-Resistant Academic Records System

## Overview
This project is a DBMS-based academic credential management system designed to provide tamper-evident storage, auditability, controlled credential modification, verification workflows, and Merkle-based integrity tracking without using blockchain.

The system is built around structured relational design, credential hashing, event logs, approval workflows, and field-level Merkle leaves for fraud resistance and verification support.

## Main Features
- Student and alumni credential storage
- Separation of personal and institutional credentials
- Admin-request and student-approval workflow for credential changes
- Credential tracking and tamper logs
- Verification request and verification log workflows
- Institutional credential transfer tracking
- Field-level Merkle leaf generation
- Merkle root history for integrity monitoring
- Stored procedures, triggers, and functions for DB-side logic

## Repository Structure
```text
dbms-merkle-credential-system/
│
├── README.md
└── database/
    ├── DATABASE_SCHEMA.md
    ├── schema_only.sql
    └── sample_data.sql