-- LexDraft AI — Canonical PostgreSQL 15+ Production Schema
-- Phase 2 Durability, Multi-Tenancy & Background Job Queue

-- 1. Tenants Table
CREATE TABLE IF NOT EXISTS tenants (
    id VARCHAR(64) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    subdomain VARCHAR(128) UNIQUE NOT NULL,
    tier VARCHAR(32) NOT NULL DEFAULT 'pro',
    max_storage_bytes BIGINT NOT NULL DEFAULT 10737418240, -- 10GB
    settings JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Users Table
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(64) PRIMARY KEY,
    tenant_id VARCHAR(64) NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    first_name VARCHAR(128) NOT NULL,
    last_name VARCHAR(128) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    salt VARCHAR(128) NOT NULL,
    role VARCHAR(32) NOT NULL DEFAULT 'user',
    failed_login_attempts INT NOT NULL DEFAULT 0,
    locked_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_users_tenant_id ON users(tenant_id);

-- 3. User Sessions Table (Hashed session tokens)
CREATE TABLE IF NOT EXISTS user_sessions (
    id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(64) UNIQUE NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_user_sessions_token_hash ON user_sessions(token_hash);
CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_expires_at ON user_sessions(expires_at);

-- 4. IP Login Rate Limiting Table
CREATE TABLE IF NOT EXISTS ip_login_attempts (
    ip VARCHAR(64) PRIMARY KEY,
    attempt_count INT NOT NULL DEFAULT 0,
    window_start TIMESTAMPTZ NOT NULL,
    locked_until TIMESTAMPTZ
);

-- 5. Cases Table (Multi-tenant scoped)
CREATE TABLE IF NOT EXISTS cases (
    id VARCHAR(64) PRIMARY KEY,
    tenant_id VARCHAR(64) NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    user_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    case_number VARCHAR(128),
    court_name VARCHAR(255),
    objective TEXT,
    parties_info JSONB,
    hearing_date DATE,
    tier VARCHAR(32) NOT NULL DEFAULT 'pro',
    max_storage_bytes BIGINT NOT NULL DEFAULT 4294967296, -- 4GB
    max_files INT NOT NULL DEFAULT 100,
    has_unread_changes BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_cases_tenant_id ON cases(tenant_id);
CREATE INDEX IF NOT EXISTS idx_cases_user_id ON cases(user_id);
CREATE INDEX IF NOT EXISTS idx_cases_created_at ON cases(created_at);

-- 6. Evidence Files Table (State-Machine Governed)
CREATE TABLE IF NOT EXISTS evidence_files (
    id VARCHAR(64) PRIMARY KEY,
    tenant_id VARCHAR(64) NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    case_id VARCHAR(64) NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
    filename VARCHAR(255) NOT NULL,
    original_name VARCHAR(255) NOT NULL,
    file_type VARCHAR(64) NOT NULL,
    file_size BIGINT NOT NULL,
    storage_key VARCHAR(512) NOT NULL,
    sha256_hash VARCHAR(64) NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'UPLOADING' 
        CHECK (status IN ('UPLOADING', 'UPLOADED', 'VERIFYING', 'VERIFIED', 'QUEUED', 'PROCESSING', 'Transcribing (ASR)', 'Complete', 'Failed')),
    progress INT NOT NULL DEFAULT 0,
    error_message TEXT,
    is_critical_evidence BOOLEAN NOT NULL DEFAULT FALSE,
    transcript TEXT,
    uploaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processed_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_evidence_files_case_id ON evidence_files(case_id);
CREATE INDEX IF NOT EXISTS idx_evidence_files_tenant_id ON evidence_files(tenant_id);
CREATE INDEX IF NOT EXISTS idx_evidence_files_sha256 ON evidence_files(sha256_hash);
CREATE INDEX IF NOT EXISTS idx_evidence_files_status ON evidence_files(status);

-- 7. File Chunks Table
CREATE TABLE IF NOT EXISTS file_chunks (
    id VARCHAR(64) PRIMARY KEY,
    file_id VARCHAR(64) NOT NULL REFERENCES evidence_files(id) ON DELETE CASCADE,
    chunk_index INT NOT NULL,
    segment_title VARCHAR(255),
    segment_start VARCHAR(32),
    segment_end VARCHAR(32),
    storage_key VARCHAR(512),
    status VARCHAR(32) DEFAULT 'Queued',
    transcript_text TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_file_chunks_file_id ON file_chunks(file_id);

-- 8. Extractions Table
CREATE TABLE IF NOT EXISTS extractions (
    id VARCHAR(64) PRIMARY KEY,
    file_id VARCHAR(64) NOT NULL REFERENCES evidence_files(id) ON DELETE CASCADE,
    case_id VARCHAR(64) NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
    file_summary TEXT,
    parties_json JSONB,
    jurisdiction_json JSONB,
    chronology_json JSONB,
    facts_json JSONB,
    cause_of_action_json JSONB,
    people_entities_json JSONB,
    ambiguities_json JSONB,
    raw_json JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_extractions_case_id ON extractions(case_id);
CREATE INDEX IF NOT EXISTS idx_extractions_file_id ON extractions(file_id);

-- 9. Master Summaries Table
CREATE TABLE IF NOT EXISTS master_summaries (
    id VARCHAR(64) PRIMARY KEY,
    case_id VARCHAR(64) NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
    version INT NOT NULL DEFAULT 1,
    parties_json JSONB,
    jurisdiction_json JSONB,
    chronology_json JSONB,
    facts_narrative TEXT,
    cause_of_action_text TEXT,
    limitation_json JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_master_summaries_case_id ON master_summaries(case_id);

-- 10. Diff Logs Table
CREATE TABLE IF NOT EXISTS diff_logs (
    id VARCHAR(64) PRIMARY KEY,
    case_id VARCHAR(64) NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
    file_id VARCHAR(64) REFERENCES evidence_files(id) ON DELETE SET NULL,
    summary_version INT NOT NULL,
    file_name VARCHAR(255),
    added_chronology_json JSONB,
    modified_facts TEXT,
    shift_in_cause_of_action TEXT,
    diff_summary TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_diff_logs_case_id ON diff_logs(case_id);

-- 11. Notifications Table
CREATE TABLE IF NOT EXISTS notifications (
    id VARCHAR(64) PRIMARY KEY,
    case_id VARCHAR(64) NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    type VARCHAR(32) NOT NULL DEFAULT 'info',
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_notifications_case_id ON notifications(case_id);

-- 12. Audit Logs Table (Append-Only Immutable Compliance Log)
CREATE TABLE IF NOT EXISTS audit_logs (
    id VARCHAR(64) PRIMARY KEY,
    tenant_id VARCHAR(64) NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    user_id VARCHAR(64) REFERENCES users(id) ON DELETE SET NULL,
    case_id VARCHAR(64) REFERENCES cases(id) ON DELETE SET NULL,
    file_id VARCHAR(64) REFERENCES evidence_files(id) ON DELETE SET NULL,
    action VARCHAR(64) NOT NULL,
    resource_type VARCHAR(64) NOT NULL,
    resource_id VARCHAR(64),
    ip_address VARCHAR(64),
    user_agent TEXT,
    metadata_json JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_audit_logs_tenant_id ON audit_logs(tenant_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_case_id ON audit_logs(case_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at);

-- Immutability enforcement: audit_logs is append-only
CREATE OR REPLACE FUNCTION prevent_audit_logs_tampering()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'IMMUTABILITY VIOLATION: Updates and deletions to audit_logs table are strictly prohibited.';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_audit_logs_no_update ON audit_logs;
CREATE TRIGGER trg_audit_logs_no_update
BEFORE UPDATE ON audit_logs
FOR EACH ROW EXECUTE FUNCTION prevent_audit_logs_tampering();

DROP TRIGGER IF EXISTS trg_audit_logs_no_delete ON audit_logs;
CREATE TRIGGER trg_audit_logs_no_delete
BEFORE DELETE ON audit_logs
FOR EACH ROW EXECUTE FUNCTION prevent_audit_logs_tampering();

-- 13. System Settings Table
CREATE TABLE IF NOT EXISTS system_settings (
    key VARCHAR(128) PRIMARY KEY,
    value TEXT NOT NULL
);

-- 14. Performance Metrics Table
CREATE TABLE IF NOT EXISTS performance_metrics (
    id VARCHAR(64) PRIMARY KEY,
    tenant_id VARCHAR(64) NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    file_id VARCHAR(64),
    operation VARCHAR(64) NOT NULL,
    tokens_used INT NOT NULL DEFAULT 0,
    tokens_saved INT NOT NULL DEFAULT 0,
    cost_saved_usd NUMERIC(10, 4) NOT NULL DEFAULT 0.0000,
    latency_ms INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_performance_metrics_tenant_id ON performance_metrics(tenant_id);

-- 15. Extraction Cache Table
CREATE TABLE IF NOT EXISTS extraction_cache (
    case_id VARCHAR(64) NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
    sha256 VARCHAR(64) NOT NULL,
    file_name VARCHAR(255),
    file_size BIGINT,
    extraction_json JSONB NOT NULL,
    tokens_saved INT DEFAULT 4500,
    latency_ms INT DEFAULT 12,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (case_id, sha256)
);

-- 16. Transactional Background Jobs Table
CREATE TABLE IF NOT EXISTS jobs (
    id VARCHAR(64) PRIMARY KEY,
    tenant_id VARCHAR(64) NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    job_type VARCHAR(64) NOT NULL,
    idempotency_key VARCHAR(128) UNIQUE NOT NULL,
    payload JSONB NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'pending' 
        CHECK (status IN ('pending', 'running', 'completed', 'failed', 'dead_letter')),
    priority INT NOT NULL DEFAULT 100,
    attempts INT NOT NULL DEFAULT 0,
    max_attempts INT NOT NULL DEFAULT 5,
    last_error TEXT,
    run_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    locked_at TIMESTAMPTZ,
    locked_by VARCHAR(128),
    lease_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_jobs_fetch ON jobs(status, run_at, priority) 
    WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_jobs_reap ON jobs(status, lease_until) 
    WHERE status = 'running';
CREATE INDEX IF NOT EXISTS idx_jobs_tenant_id ON jobs(tenant_id);
