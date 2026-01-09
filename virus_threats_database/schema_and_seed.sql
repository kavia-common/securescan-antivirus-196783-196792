-- Antivirus app schema + minimal seed data (idempotent)
-- This script is intended to be run repeatedly; it uses IF NOT EXISTS / ON CONFLICT to be safe.

-- Ensure we have UUID generation capability.
-- pgcrypto provides gen_random_uuid(); available on many Postgres builds.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =========================
-- Tables
-- =========================

CREATE TABLE IF NOT EXISTS threats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    signature TEXT NOT NULL UNIQUE,
    severity INT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS scan_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id TEXT NOT NULL,
    status TEXT NOT NULL,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT scan_jobs_status_check CHECK (status IN ('queued','running','completed','failed'))
);

CREATE TABLE IF NOT EXISTS scan_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES scan_jobs(id) ON DELETE CASCADE,
    summary TEXT,
    total_files INT NOT NULL DEFAULT 0,
    threats_found INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS detections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES scan_jobs(id) ON DELETE CASCADE,
    threat_id UUID NOT NULL REFERENCES threats(id),
    file_path TEXT NOT NULL,
    action TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT detections_action_check CHECK (action IN ('quarantine','delete','ignore'))
);

CREATE TABLE IF NOT EXISTS schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id TEXT NOT NULL,
    cron TEXT NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT true,
    last_run TIMESTAMPTZ,
    next_run TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS protection_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id TEXT NOT NULL,
    threat_id UUID REFERENCES threats(id),
    event TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =========================
-- Indexes
-- =========================

-- Unique index on threats(signature) is already enforced by UNIQUE constraint,
-- but we keep this explicit index creation to match requirements.
CREATE UNIQUE INDEX IF NOT EXISTS threats_signature_uidx ON threats(signature);

CREATE INDEX IF NOT EXISTS scan_jobs_status_idx ON scan_jobs(status);
CREATE INDEX IF NOT EXISTS detections_job_id_idx ON detections(job_id);
CREATE INDEX IF NOT EXISTS schedules_enabled_idx ON schedules(enabled);

-- =========================
-- Seed data (idempotent)
-- =========================

INSERT INTO threats (name, signature, severity)
VALUES ('EICAR Test String', 'EICAR-STANDARD-ANTIVIRUS-TEST-FILE', 1)
ON CONFLICT (signature) DO UPDATE SET
  name = EXCLUDED.name,
  severity = EXCLUDED.severity;

INSERT INTO threats (name, signature, severity)
VALUES ('Demo.Ransom', 'DEMO-RANSOM-SIGNATURE', 9)
ON CONFLICT (signature) DO UPDATE SET
  name = EXCLUDED.name,
  severity = EXCLUDED.severity;

INSERT INTO threats (name, signature, severity)
VALUES ('Demo.Trojan', 'DEMO-TROJAN-SIGNATURE', 6)
ON CONFLICT (signature) DO UPDATE SET
  name = EXCLUDED.name,
  severity = EXCLUDED.severity;
