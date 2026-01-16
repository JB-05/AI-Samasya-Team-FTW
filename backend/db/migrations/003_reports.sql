-- =============================================================================
-- Migration 003: Reports (Derived, Language-Only Artifacts)
-- =============================================================================
-- Stores validated AI / template-generated reports
-- ADDITIVE ONLY — does not affect core intelligence tables
-- =============================================================================

CREATE TABLE IF NOT EXISTS reports (
    report_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    learner_id UUID NOT NULL
        REFERENCES learners(learner_id)
        ON DELETE CASCADE,

    -- Scope of report
    report_scope TEXT NOT NULL CHECK (
        report_scope IN ('session', 'learner')
    ),

    -- Present only if session-level report
    source_session_id UUID NULL
        REFERENCES sessions(session_id)
        ON DELETE CASCADE,

    -- Target audience controls tone
    audience TEXT NOT NULL CHECK (
        audience IN ('parent', 'teacher')
    ),

    -- Final, user-visible content ONLY
    content TEXT NOT NULL,

    -- Transparency & governance
    generation_method TEXT NOT NULL CHECK (
        generation_method IN ('template', 'ai')
    ),

    validation_status TEXT NOT NULL CHECK (
        validation_status IN ('approved', 'rewritten', 'rejected')
    ),

    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Enable RLS
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

-- Observers can read reports of their learners
CREATE POLICY "Observers can view own learner reports"
ON reports
FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM learners
        WHERE learners.learner_id = reports.learner_id
        AND learners.observer_id = auth.uid()
    )
);

-- Backend (service role) manages inserts/updates
-- No client-side insert/update/delete access

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_reports_learner_id
ON reports (learner_id);

CREATE INDEX IF NOT EXISTS idx_reports_created_at
ON reports (created_at);
