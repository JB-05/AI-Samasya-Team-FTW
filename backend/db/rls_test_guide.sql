-- =============================================================================
-- RLS ISOLATION TEST GUIDE
-- Run these queries in Supabase SQL Editor to verify privacy guardrails
-- =============================================================================
-- 
-- EXIT CRITERIA: 
-- "The database itself enforces privacy, even if the API is buggy."
--
-- =============================================================================


-- =============================================================================
-- STEP 1: Verify RLS is ENABLED on all tables
-- =============================================================================

SELECT 
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('observers', 'learners', 'sessions', 'pattern_snapshots', 'trend_summaries');

-- ✅ EXPECTED: All 5 tables should show rls_enabled = true
-- ❌ FAIL IF: Any table shows rls_enabled = false


-- =============================================================================
-- STEP 2: Verify RLS POLICIES exist
-- =============================================================================

SELECT 
    tablename,
    policyname,
    cmd as operation
FROM pg_policies 
WHERE schemaname = 'public'
ORDER BY tablename, cmd;

-- ✅ EXPECTED: Each table has SELECT, INSERT, UPDATE, DELETE policies
-- ❌ FAIL IF: Any table is missing policies


-- =============================================================================
-- STEP 3: MANUAL CROSS-USER ISOLATION TEST
-- =============================================================================

-- 3a. Create two test users in Supabase Auth Dashboard
--     User A: test_observer_a@test.local
--     User B: test_observer_b@test.local

-- 3b. Login as User A and run:
INSERT INTO observers (observer_id, role) 
VALUES (auth.uid(), 'parent');

INSERT INTO learners (observer_id, alias) 
VALUES (auth.uid(), 'Test Learner A');

SELECT * FROM learners;  -- Should see ONLY "Test Learner A"

-- 3c. Login as User B and run:
INSERT INTO observers (observer_id, role) 
VALUES (auth.uid(), 'teacher');

INSERT INTO learners (observer_id, alias) 
VALUES (auth.uid(), 'Test Learner B');

SELECT * FROM learners;  -- Should see ONLY "Test Learner B"

-- 3d. As User B, try to access User A's data:
-- First, get User A's learner_id from admin panel, then:
-- SELECT * FROM learners WHERE learner_id = '<user_a_learner_id>';
-- ✅ EXPECTED: Returns 0 rows (blocked by RLS)
-- ❌ FAIL IF: Returns any data


-- =============================================================================
-- STEP 4: Verify CASCADE deletion
-- =============================================================================

-- As User A, delete their learner:
-- DELETE FROM learners WHERE alias = 'Test Learner A';

-- Verify all related data is also deleted:
-- SELECT * FROM sessions WHERE learner_id = '<deleted_learner_id>';
-- SELECT * FROM pattern_snapshots WHERE learner_id = '<deleted_learner_id>';
-- SELECT * FROM trend_summaries WHERE learner_id = '<deleted_learner_id>';

-- ✅ EXPECTED: All queries return 0 rows


-- =============================================================================
-- STEP 5: Verify SERVICE ROLE bypasses RLS (for admin only)
-- =============================================================================

-- Using service role key (NOT anon key), you should see all data:
-- This is expected - service role is for server-side admin operations only
-- NEVER expose service role key to clients


-- =============================================================================
-- CLEANUP: Remove test data
-- =============================================================================

-- As each user, delete their test data:
-- DELETE FROM learners WHERE alias LIKE 'Test Learner%';
-- DELETE FROM observers WHERE observer_id = auth.uid();


-- =============================================================================
-- SUMMARY CHECKLIST
-- =============================================================================
-- 
-- [ ] All 5 tables have RLS enabled
-- [ ] Each table has appropriate policies
-- [ ] User A cannot see User B's learners
-- [ ] User B cannot see User A's learners
-- [ ] Cross-access queries return 0 rows
-- [ ] Cascade deletion works correctly
-- 
-- If ALL boxes checked: Database enforces privacy by design ✅
-- =============================================================================
