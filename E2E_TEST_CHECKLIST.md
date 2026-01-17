# End-to-End Testing Checklist — NeuroPlay / AI Samasya

**Status:** Manual Verification Required  
**Date:** 2025-01-17  
**Purpose:** System-level verification for privacy, safety, AI governance, and demo readiness

---

## Pre-Testing Setup

### Prerequisites

- [ ] Backend server running (`uvicorn backend.main:app --reload`)
- [ ] Supabase connection configured (`.env` file with `SUPABASE_URL`, `SUPABASE_ANON_KEY`)
- [ ] Gemini API key configured (optional, for AI report generation)
- [ ] Flutter app built and ready to run

### Test Accounts

- [ ] User A account created in Supabase (parent/teacher)
- [ ] User B account created in Supabase (parent/teacher)
- [ ] Both users have valid JWT tokens

---

## PHASE 1 — CONFIGURATION & BOOT

### Test 1.1: Fail-Fast Configuration

**Steps:**

1. Remove or invalidate `SUPABASE_URL` from `.env`
2. Attempt to start backend: `uvicorn backend.main:app --reload`
3. **Expected:** Application exits immediately with configuration error

**PASS ✅ if:**
- App refuses to start when config invalid
- Clear error message displayed

**FAIL ❌ if:**
- App starts with invalid config
- Error message not displayed

**Reset:** Restore valid `SUPABASE_URL` and restart

---

### Test 1.2: Health Check Endpoint

**Steps:**

1. With valid config, start backend
2. Call `GET http://127.0.0.1:8000/health`
3. Call `GET http://127.0.0.1:8000/health/config`

**PASS ✅ if:**
- `/health` returns status 200 with `status: "healthy"`
- `/health/config` returns `status: "ok"` when config valid

**FAIL ❌ if:**
- Endpoints not accessible
- Status indicates degraded state when config is valid

---

## PHASE 2 — AUTH & DATA ISOLATION

### Test 2.1: Observer Isolation

**Steps:**

1. Login as User A via Flutter app (or Supabase Auth)
2. Create learner "A1" → capture `learner_id`
3. Login as User B (different account)
4. Create learner "B1" → capture `learner_id`
5. As User A, call `GET /api/learners` (with User A JWT token)
6. As User B, call `GET /api/learners` (with User B JWT token)

**PASS ✅ if:**
- User A sees only learner A1
- User B sees only learner B1
- No cross-user data visible

**FAIL ❌ if:**
- User A can see learner B1
- User B can see learner A1
- Any data leakage between observers

**File to verify:** RLS policies in `backend/db/migrations/000_complete_schema.sql`

---

### Test 2.2: Unauthenticated Access

**Steps:**

1. Call `GET /api/learners` without `Authorization` header

**PASS ✅ if:**
- Returns 401 Unauthorized
- Error message indicates authentication required

**FAIL ❌ if:**
- Returns data without auth
- Returns 200 with empty list (should be 401)

---

## PHASE 3 — LEARNER CODE VALIDATION

### Test 3.1: Learner Code Resolution

**Steps:**

1. As User A, create learner → capture `learner_code` (displayed once)
2. Test valid code: `POST /api/sessions/child/start` with `learner_code`
3. Test invalid code: `POST /api/sessions/child/start` with `learner_code: "INVALID12"`

**PASS ✅ if:**
- Valid code → Returns session_id (200 or 201)
- Invalid code → Returns 404 Not Found

**FAIL ❌ if:**
- Invalid code accepted
- Valid code rejected

---

### Test 3.2: Rate Limiting

**Steps:**

1. Use valid `learner_code`
2. Call `POST /api/sessions/child/start` 12 times in quick succession (same code)

**PASS ✅ if:**
- First 10 requests succeed (or return expected error like 404 if learner doesn't exist)
- 11th+ request returns 429 Too Many Requests

**FAIL ❌ if:**
- No rate limiting enforced
- All requests succeed

**File to verify:** `backend/dependencies.py` (RateLimiter class)

---

### Test 3.3: Write-Only Access

**Steps:**

1. With valid `learner_code`, attempt:
   - `GET /api/learners` (should fail - no auth)
   - `GET /api/reports/learner/{id}` (should fail - no auth)
   - `POST /api/sessions/child/start` (should succeed)

**PASS ✅ if:**
- Write endpoints accessible with learner_code
- Read endpoints require authentication (401)

**FAIL ❌ if:**
- Learner code grants read access to reports/learners

---

## PHASE 4 — SESSION & PATTERN PIPELINE

### Test 4.1: Session Lifecycle

**Steps:**

1. Start session: `POST /api/sessions/child/start` with `learner_code` → capture `session_id`
2. Send mock events: `POST /api/sessions/child/{session_id}/events` with tap events
3. Complete session: `POST /api/sessions/child/{session_id}/complete`

**Verify:**

- [ ] Session row created in `sessions` table
- [ ] Pattern snapshot(s) created in `pattern_snapshots` table
- [ ] Raw events NOT persisted in database (check for `events` table - should not exist)
- [ ] In-memory event store cleared after completion

**PASS ✅ if:**
- No raw event data persisted
- Only pattern snapshots (language-only) saved

**FAIL ❌ if:**
- Raw events stored in database
- Metrics persisted alongside patterns

**File to verify:** `backend/services/event_store.py` (in-memory only)

---

### Test 4.2: Pattern Inference Rules

**Simulate different event patterns:**

#### Case A: High Variability

Send events with varying reaction times.

**Expected Pattern:** "Variable focus rhythm"

**Verify:**
- [ ] `pattern_name` = "Variable focus rhythm"
- [ ] `learning_impact` contains NO numbers
- [ ] `support_focus` contains NO diagnostic terms
- [ ] `explanation` contains NO numeric values

#### Case B: High Miss Rate

Send events with many misses.

**Expected Pattern:** "Building target tracking"

**Verify:**
- [ ] `pattern_name` = "Building target tracking"
- [ ] All text fields are language-only (no metrics)

#### Case C: Consistent Events

Send events with consistent timing.

**Expected Pattern:** "Steady focus"

**Verify:**
- [ ] Pattern inferred correctly
- [ ] No numeric values in any text field

**PASS ✅ if:**
- Correct pattern_name inferred for each case
- All text fields are metric-free
- No diagnostic terms in output

**FAIL ❌ if:**
- Numbers appear in `learning_impact`, `support_focus`, or `explanation`
- Diagnostic terms appear

**File to verify:** `backend/services/pattern_engine.py`

---

## PHASE 5 — AI REPORT GENERATION (CRITICAL)

### Test 5.1: Generator Input Safety

**Steps:**

1. Ensure learner has pattern snapshots
2. Trigger report generation: `POST /api/reports/generate`
   ```json
   {
     "learner_id": "...",
     "scope": "learner",
     "audience": "parent"
   }
   ```
3. **Check Gemini input payload** (add logging in `report_generator.py` or use debugger)

**PASS ✅ if input includes ONLY:**
- `pattern_name`
- `learning_impact`
- `support_focus`
- `trend_type` (optional)

**FAIL ❌ if input includes:**
- Metrics (mean_reaction_time_ms, miss_rate, etc.)
- Numbers or percentages
- Confidence values
- Game names or activity references
- Raw event data

**File to verify:** `backend/services/report_generator.py::_build_safe_input()`

---

### Test 5.2: Validator Enforcement

#### Case A: Clean Language Report

**Steps:**

1. Generate report with clean, safe language
2. Check `validation_status` in database

**PASS ✅ if:**
- `validation_status` = `'approved'`
- Report content unchanged

#### Case B: Report with Numbers (Injected Test)

**Steps:**

1. Manually insert report with numeric value: "The learner scored 85%"
2. Run validator on this report
3. Check `validation_status`

**PASS ✅ if:**
- `validation_status` = `'rewritten'`
- Rewritten content removes numbers
- Final report is numeric-free

#### Case C: Report with Diagnostic Term (Injected Test)

**Steps:**

1. Manually insert report with "diagnosis" or "ADHD"
2. Run validator on this report
3. Check `validation_status`

**PASS ✅ if:**
- `validation_status` = `'rejected'`
- Fallback template report used
- Unsafe content never returned to client

**File to verify:** `backend/services/report_validator.py`

---

### Test 5.3: Report Content Safety

**Steps:**

1. Generate report via API
2. Retrieve report: `GET /api/reports/ai/{report_id}`

**Verify:**
- [ ] No numbers, percentages, or timings
- [ ] No game or activity references
- [ ] No diagnostic terms (use forbidden_terms.txt as reference)
- [ ] Disclaimer present: "Observational insights only. This is not a diagnostic assessment."
- [ ] Calm, supportive tone

**PASS ✅ if:**
- All safety checks pass
- Report is readable and appropriate

**FAIL ❌ if:**
- Any prohibited content appears
- Disclaimer missing

---

## PHASE 6 — TREND COMPUTATION

### Test 6.1: Trend Threshold

**Steps:**

1. Create learner with <3 sessions
2. Call `GET /api/trends/learner/{learner_id}`
3. **Expected:** Returns empty list or error indicating insufficient data

4. Create 3+ sessions for same learner
5. Complete all sessions (trigger pattern snapshots)
6. Call `GET /api/trends/learner/{learner_id}` again

**PASS ✅ if:**
- With <3 sessions: handled gracefully (empty or error)
- With ≥3 sessions: returns trends
- `trend_type` ∈ `{'stable', 'fluctuating', 'improving'}`
- Response contains NO numeric values

**FAIL ❌ if:**
- Trends returned with <3 sessions
- `trend_type` values outside expected set
- Numbers or percentages in response

**File to verify:** `backend/services/trend_engine.py`, `backend/routes/trends.py`

---

## PHASE 7 — FRONTEND UX SAFETY

### Test 7.1: Report Screen

**Steps:**

1. Open Flutter app
2. Login as User A
3. Navigate to learner → View report
4. **Verify UI:**
   - [ ] Skeleton loading shown while fetching
   - [ ] Clear visual hierarchy (patterns → impacts → support)
   - [ ] Disclaimer visible at bottom
   - [ ] NO scores, percentages, or charts
   - [ ] NO progress bars or metrics

**PASS ✅ if:**
- UI is language-only, no metrics displayed

**FAIL ❌ if:**
- Any numeric analytics visible
- Charts or graphs present

**File to verify:** `lib/screens/report_screen.dart`, `lib/screens/learner_context_screen.dart`

---

### Test 7.2: Home Screen

**Steps:**

1. Open Flutter app
2. Verify home screen displays:
   - [ ] List of learners (aliases only)
   - [ ] "Add learner" button
   - [ ] NO pattern counts
   - [ ] NO statistics or metrics

**PASS ✅ if:**
- Clean, minimal UI without analytics

**FAIL ❌ if:**
- Analytics or metrics displayed

---

## PHASE 8 — DEMO RELIABILITY

### Test 8.1: Cold Start Flow

**Simulate judge demo:**

1. **Login**
   - Open app → Login screen
   - Enter credentials → Home screen loads

2. **Add Learner**
   - Tap "Add learner"
   - Enter alias → Learner created
   - **Capture `learner_code`** (displayed once)

3. **View Learner Context**
   - Tap learner from list
   - See learner name and code
   - **Note:** Report may be empty if no sessions

4. **Generate Report** (if patterns exist)
   - If report not cached, it may generate
   - Verify report displays with disclaimer

5. **Navigate**
   - Home → Profile → About
   - No crashes or navigation errors

**PASS ✅ if:**
- No crashes during flow
- All screens load correctly
- AI failures (if any) fall back safely (use template report)

**FAIL ❌ if:**
- App crashes at any point
- Navigation errors
- Unhandled exceptions visible

---

### Test 8.2: Error Handling

**Steps:**

1. Disable backend (stop server)
2. Attempt to fetch learners in app

**PASS ✅ if:**
- Error message shown (not crash)
- App remains stable
- User can retry or navigate away

**FAIL ❌ if:**
- App crashes on network error
- Unhandled exception displayed

---

## SUCCESS CRITERIA SUMMARY

**All tests must pass for demo readiness:**

- ✅ No raw data persisted
- ✅ No numeric analytics exposed
- ✅ AI outputs always validated
- ✅ Privacy guarantees hold (RLS enforced)
- ✅ App is demo-stable (no crashes)
- ✅ Safety filters active and effective
- ✅ Trend computation works correctly
- ✅ Frontend is metric-free

---

## TEST RESULTS

**Date:** _____________  
**Tester:** _____________  

| Phase | Test | Status | Notes |
|-------|------|--------|-------|
| 1 | Fail-Fast Config | ⬜ | |
| 1 | Health Check | ⬜ | |
| 2 | Observer Isolation | ⬜ | |
| 2 | Unauthenticated Access | ⬜ | |
| 3 | Learner Code Resolution | ⬜ | |
| 3 | Rate Limiting | ⬜ | |
| 3 | Write-Only Access | ⬜ | |
| 4 | Session Lifecycle | ⬜ | |
| 4 | Pattern Inference | ⬜ | |
| 5 | Generator Input Safety | ⬜ | |
| 5 | Validator Enforcement | ⬜ | |
| 5 | Report Content Safety | ⬜ | |
| 6 | Trend Threshold | ⬜ | |
| 7 | Report Screen UX | ⬜ | |
| 7 | Home Screen UX | ⬜ | |
| 8 | Cold Start Flow | ⬜ | |
| 8 | Error Handling | ⬜ | |

**Overall Status:** ⬜ Ready for Demo / ⬜ Needs Fixes

---

## Notes

- Tests marked ⬜ should be checked and marked ✅ (pass) or ❌ (fail)
- Any failures should be logged with file + function name
- System is ready for demo only if all tests pass

---

**End of Checklist**
