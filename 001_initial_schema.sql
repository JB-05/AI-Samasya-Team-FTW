-- =============================================================================
-- Initial Schema Migration
-- Privacy-safe Learning Pattern System
-- =============================================================================
-- 
-- Judge-Facing One-Line Explanation:
-- "We store only anonymized learning pattern summaries linked to adult accounts;
--  raw behavior and child identity are never persisted."
--
-- This schema is:
-- - Minimal
-- - Privacy-preserving
-- - Trend-capable
-- - Hackathon-ready
--
-- ⚠️ No additional tables should be added unless legally or technically required.
-- =============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================================================
-- Table 3.1: observers (Adult Accounts)
-- Managed by Supabase Auth
-- NOTE: No child data stored here
-- =============================================================================

CREATE TABLE IF NOT EXISTS observers (
    observer_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('parent', 'teacher')),
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Enable Row Level Security
ALTER TABLE observers ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only read/update their own observer record
CREATE POLICY "Users can view own observer record" ON observers
    FOR SELECT USING (auth.uid() = observer_id);

CREATE POLICY "Users can update own observer record" ON observers
    FOR UPDATE USING (auth.uid() = observer_id);

CREATE POLICY "Users can insert own observer record" ON observers
    FOR INSERT WITH CHECK (auth.uid() = observer_id);


-- =============================================================================
-- Table 3.2: learners (Alias-Based, Non-Identifying)
-- Rules:
-- - Alias chosen by adult
-- - No age, gender, grade, or name
-- - One observer owns their learners
-- =============================================================================

CREATE TABLE IF NOT EXISTS learners (
    learner_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    observer_id UUID NOT NULL REFERENCES observers(observer_id) ON DELETE CASCADE,
    alias TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Enable Row Level Security
ALTER TABLE learners ENABLE ROW LEVEL SECURITY;

-- Policy: Observers can only access their own learners
CREATE POLICY "Observers can view own learners" ON learners
    FOR SELECT USING (auth.uid() = observer_id);

CREATE POLICY "Observers can insert own learners" ON learners
    FOR INSERT WITH CHECK (auth.uid() = observer_id);

CREATE POLICY "Observers can update own learners" ON learners
    FOR UPDATE USING (auth.uid() = observer_id);

CREATE POLICY "Observers can delete own learners" ON learners
    FOR DELETE USING (auth.uid() = observer_id);

-- Index for faster lookups
CREATE INDEX idx_learners_observer_id ON learners(observer_id);


-- =============================================================================
-- Table 3.3: sessions
-- Represents one completed game interaction
-- Rules:
-- - No raw events stored
-- - One session → many pattern snapshots
-- =============================================================================

CREATE TABLE IF NOT EXISTS sessions (
    session_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    learner_id UUID NOT NULL REFERENCES learners(learner_id) ON DELETE CASCADE,
    game_set TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Enable Row Level Security
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;

-- Policy: Observers can only access sessions of their learners
CREATE POLICY "Observers can view own learner sessions" ON sessions
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM learners 
            WHERE learners.learner_id = sessions.learner_id 
            AND learners.observer_id = auth.uid()
        )
    );

CREATE POLICY "Observers can insert own learner sessions" ON sessions
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM learners 
            WHERE learners.learner_id = sessions.learner_id 
            AND learners.observer_id = auth.uid()
        )
    );

-- Index for faster lookups
CREATE INDEX idx_sessions_learner_id ON sessions(learner_id);
CREATE INDEX idx_sessions_created_at ON sessions(created_at);


-- =============================================================================
-- Table 3.4: pattern_snapshots (Core Intelligence Storage)
-- This is the most important table
-- Rules:
-- - No scores
-- - No diagnoses
-- - This is the only long-term behavioral record
-- =============================================================================

CREATE TABLE IF NOT EXISTS pattern_snapshots (
    snapshot_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES sessions(session_id) ON DELETE CASCADE,
    learner_id UUID NOT NULL REFERENCES learners(learner_id) ON DELETE CASCADE,
    pattern_name TEXT NOT NULL,
    confidence TEXT NOT NULL CHECK (confidence IN ('low', 'moderate', 'high')),
    learning_impact TEXT NOT NULL,
    support_focus TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Enable Row Level Security
ALTER TABLE pattern_snapshots ENABLE ROW LEVEL SECURITY;

-- Policy: Observers can only access pattern snapshots of their learners
CREATE POLICY "Observers can view own learner patterns" ON pattern_snapshots
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM learners 
            WHERE learners.learner_id = pattern_snapshots.learner_id 
            AND learners.observer_id = auth.uid()
        )
    );

CREATE POLICY "Observers can insert own learner patterns" ON pattern_snapshots
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM learners 
            WHERE learners.learner_id = pattern_snapshots.learner_id 
            AND learners.observer_id = auth.uid()
        )
    );

-- Indexes for faster lookups
CREATE INDEX idx_pattern_snapshots_session_id ON pattern_snapshots(session_id);
CREATE INDEX idx_pattern_snapshots_learner_id ON pattern_snapshots(learner_id);
CREATE INDEX idx_pattern_snapshots_pattern_name ON pattern_snapshots(pattern_name);
CREATE INDEX idx_pattern_snapshots_created_at ON pattern_snapshots(created_at);


-- =============================================================================
-- Table 3.5: trend_summaries (Derived, Optional Cache)
-- Rules:
-- - Can be regenerated anytime
-- - May be cached for performance
-- - No raw data dependency
-- =============================================================================

CREATE TABLE IF NOT EXISTS trend_summaries (
    trend_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    learner_id UUID NOT NULL REFERENCES learners(learner_id) ON DELETE CASCADE,
    pattern_name TEXT NOT NULL,
    trend_type TEXT NOT NULL CHECK (trend_type IN ('stable', 'fluctuating', 'improving')),
    session_count INTEGER NOT NULL DEFAULT 0,
    generated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    
    -- Unique constraint: one trend per learner per pattern
    UNIQUE (learner_id, pattern_name)
);

-- Enable Row Level Security
ALTER TABLE trend_summaries ENABLE ROW LEVEL SECURITY;

-- Policy: Observers can only access trend summaries of their learners
CREATE POLICY "Observers can view own learner trends" ON trend_summaries
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM learners 
            WHERE learners.learner_id = trend_summaries.learner_id 
            AND learners.observer_id = auth.uid()
        )
    );

CREATE POLICY "Observers can manage own learner trends" ON trend_summaries
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM learners 
            WHERE learners.learner_id = trend_summaries.learner_id 
            AND learners.observer_id = auth.uid()
        )
    );

-- Index for faster lookups
CREATE INDEX idx_trend_summaries_learner_id ON trend_summaries(learner_id);
CREATE INDEX idx_trend_summaries_pattern_name ON trend_summaries(pattern_name);


-- =============================================================================
-- Cascade Delete Behavior
-- Deleting a learner deletes all linked data
-- Observer deletion cascades fully (handled by Supabase Auth FK)
-- =============================================================================

-- All tables have ON DELETE CASCADE configured above


-- =============================================================================
-- Data Retention Notes (Not enforced in schema, implemented in application)
-- =============================================================================
-- | Data             | Retention            |
-- |------------------|----------------------|
-- | Raw events       | In-memory only       |
-- | Sessions         | Persistent (metadata)|
-- | Pattern snapshots| Persistent           |
-- | Trend summaries  | Regenerable          |
-- =============================================================================
