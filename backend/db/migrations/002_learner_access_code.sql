-- =============================================================================
-- Migration 002: Learner Access Code
-- =============================================================================
-- Enables child app session ingestion without authentication
-- This migration is ADDITIVE ONLY
-- =============================================================================

-- 1. Add learner_code column (nullable first)
ALTER TABLE learners
ADD COLUMN IF NOT EXISTS learner_code TEXT;

-- 2. Function to generate random, non-identifying codes
-- Uses uppercase letters + digits, excludes ambiguous characters
CREATE OR REPLACE FUNCTION generate_learner_code()
RETURNS TEXT AS $$
DECLARE
    chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    result TEXT := '';
    i INTEGER;
BEGIN
    FOR i IN 1..8 LOOP
        result := result || substr(
            chars,
            floor(random() * length(chars) + 1)::int,
            1
        );
    END LOOP;
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- 3. Backfill existing learners
UPDATE learners
SET learner_code = generate_learner_code()
WHERE learner_code IS NULL;

-- 4. Enforce NOT NULL + uniqueness
ALTER TABLE learners
ALTER COLUMN learner_code SET NOT NULL;

ALTER TABLE learners
ADD CONSTRAINT learners_learner_code_unique UNIQUE (learner_code);

-- 5. Index for fast validation lookups
CREATE INDEX IF NOT EXISTS idx_learners_learner_code
ON learners (learner_code);
