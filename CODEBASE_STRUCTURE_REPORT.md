# Codebase Structure Report — NeuroPlay / AI Samasya

**Generated:** 2025-01-17  
**Project Type:** Learning Pattern Analysis System (Teacher/Parent App + Child App Backend)  
**Tech Stack:** FastAPI (Python) + Flutter (Dart)

---

## Executive Summary

This is a **privacy-safe learning pattern analysis system** that allows adults (parents/teachers) to observe children's learning patterns through gameplay sessions. The system enforces strict non-diagnostic language, uses transient raw event storage, and persists only pattern summaries and trend analyses.

**Architecture:**
- **Backend:** FastAPI with Supabase (PostgreSQL) for data storage
- **Frontend:** Flutter cross-platform mobile/web app
- **AI:** Google Gemini API for report generation and validation
- **Authentication:** Supabase JWT for adults, learner codes for children

---

## 1. Backend Structure (`/backend`)

### 1.1 Core Configuration (`/backend`)

#### `main.py` (136 lines)
**Purpose:** FastAPI application entry point and router configuration  
**Key Functions:**
- Defines FastAPI app with lifespan management
- Configures CORS middleware for Flutter app
- Registers all route routers (`/api/auth`, `/api/learners`, `/api/sessions`, `/api/reports`, `/api/trends`)
- Manages background cleanup scheduler for TTL sessions
- Root endpoint with API metadata

**Dependencies:** All route modules, health router, TTL cleanup utility

---

#### `config.py` (117 lines)
**Purpose:** Environment variable management with fail-fast validation  
**Key Functions:**
- `Settings` class (Pydantic): Loads env vars (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GEMINI_KEY`, etc.)
- `validate_config_or_exit()`: Exits immediately if required config missing
- `get_settings()`: Cached settings instance with fail-fast
- `get_settings_dev()`: Non-fail-fast version for development
- Validates Supabase URL format and key lengths

**Environment Variables:**
- Required: `SUPABASE_URL`, `SUPABASE_ANON_KEY`
- Optional: `SUPABASE_SERVICE_KEY`, `GEMINI_KEY`
- Config: `session_ttl_hours`, `debug`, `environment`

---

#### `dependencies.py`
**Purpose:** FastAPI dependency injection for authentication and context  
**Key Functions:**
- `get_current_observer()`: Extracts Supabase JWT from `Authorization: Bearer` header, verifies with Supabase, maps `auth.users.id` → `observers.observer_id`, auto-creates observer row if missing, raises 401 for invalid tokens
- `get_learner_by_code()`: Resolves `learner_id` from `learner_code` for child app (unauthenticated, rate-limited: 10 requests/60 seconds), used ONLY by child session routes
- `CurrentObserver`, `LearnerContext`: Type aliases for route injection
- Rate limiting for learner code lookups (in-memory)

**Security:** JWT verification, RLS enforcement, rate limiting

---

### 1.2 Database Layer (`/backend/db`)

#### `supabase.py` (50 lines)
**Purpose:** Supabase client initialization and management  
**Key Functions:**
- `get_supabase()`: Returns Supabase client with `anon` key (subject to RLS)
- `get_supabase_admin()`: Returns Supabase client with `service_role` key (bypasses RLS for backend operations)
- Singleton pattern for client instances

**Usage:** All database operations use these clients

---

#### `models.py` (216 lines)
**Purpose:** Pydantic models for database table representations  
**Key Models:**
- `Observer`: Parent/teacher user (maps from Supabase `auth.users`)
- `Learner`: Child alias with `learner_code` for child app access
- `Session`: Learning activity session record
- `PatternSnapshot`: Persisted pattern observation (no metrics, language-only)
- `TrendSummary`: Longitudinal trend aggregation
- `Report`: AI-generated narrative reports

**Note:** These models define data structures but don't handle DB operations directly

---

#### `/backend/db/migrations/`
**Purpose:** SQL migration files for database schema  
**Files:**
- `000_complete_schema.sql` (346 lines): **Complete consolidated schema** (all tables, RLS policies, indexes)
  - `observers`, `learners` (with `learner_code`), `sessions`, `pattern_snapshots`, `trend_summaries`, `reports`
- `001_initial_schema.sql` (240 lines): Original initial schema
- `002_learner_access_code.sql` (47 lines): Adds `learner_code` column and generation function
- `003_reports.sql`: Adds `reports` table for AI-generated reports

**RLS Policies:** All tables have row-level security enforcing observer ownership

---

### 1.3 Routes (`/backend/routes`)

#### `auth.py`
**Purpose:** Authentication endpoints for teacher/parent app  
**Key Endpoints:**
- `GET /api/auth/me`: Returns current observer's ID and role

**Authentication:** JWT via `CurrentObserver` dependency

---

#### `learners.py`
**Purpose:** Learner alias CRUD operations  
**Key Endpoints:**
- `GET /api/learners`: List all learners for current observer (returns `learner_id`, `alias`, `created_at` only)
- `POST /api/learners`: Create learner (generates unique `learner_code`, returns ONCE)
- `GET /api/learners/{learner_id}`: Get learner details (includes `learner_code` for detail view)
- `PATCH /api/learners/{learner_id}`: Update learner alias
- `DELETE /api/learners/{learner_id}`: Delete learner

**Security:** All operations use `service_role` key for writes, verify observer ownership

---

#### `sessions.py`
**Purpose:** Session management for learning activities  
**Key Endpoints:**
- `POST /api/sessions/start`: Start session (parent/teacher app, authenticated)
- `POST /api/sessions/{id}/events`: Log gameplay events (in-memory store)
- `POST /api/sessions/{id}/complete`: Complete session (triggers pattern extraction, clears events)
- `POST /api/sessions/child/start`: Start session with `learner_code` (child app, unauthenticated)
- `POST /api/sessions/child/{id}/events`: Log events (child app)
- `POST /api/sessions/child/{id}/complete`: Complete session (child app)

**Data Flow:** Raw events → in-memory store → feature extraction → pattern inference → pattern snapshot → clear events

---

#### `reports.py` (249 lines)
**Purpose:** Pattern report retrieval (language-only, non-diagnostic)  
**Key Endpoints:**
- `GET /api/reports/session/{session_id}`: Get session-level patterns
- `GET /api/reports/learner/{learner_id}`: Get all patterns for learner
- `GET /api/reports/ai/{report_id}`: Get AI-generated narrative report

**Response:** Only pattern names, learning impacts, support focuses, disclaimers (no metrics, no confidence values)

---

#### `reports_generate.py` (136 lines)
**Purpose:** AI report generation via Gemini  
**Key Endpoints:**
- `POST /api/reports/generate`: Generate narrative report (checks cache first, calls `report_generator`, validates via `report_validator`)

**Request:** `learner_id`, `scope` (session/learner), `session_id` (optional), `audience` (parent/teacher)  
**Response:** `report_id`, `status` (generated_pending_validation/cached_approved)

---

#### `trends.py` (78 lines)
**Purpose:** Longitudinal trend summaries  
**Key Endpoints:**
- `GET /api/trends/learner/{learner_id}`: Compute and return trends (requires min 3 sessions)

**Logic:** Calls `trend_engine.compute_trends_for_learner()` to aggregate pattern snapshots, returns `pattern_name` and `trend_type` (stable/fluctuating/improving) only

---

#### `health.py`
**Purpose:** Health check and configuration status  
**Endpoints:**
- `GET /health`: Basic health check
- `GET /health/config`: Configuration validation status

---

### 1.4 Schemas (`/backend/schemas`)

**Purpose:** Pydantic request/response models for API validation  
**Files:**
- `learner.py`: `LearnerCreate`, `LearnerRead`, `LearnerUpdate`, `LearnerCreateResponse`
- `session.py`: `SessionStart`, `TapEvent`, `EventLog`, `ChildSessionStart`, response models
- `pattern.py`: `PatternSnapshot`, `DetectedPattern`, pattern categories
- `report.py`: `PatternSummary`, `SessionReport`, `LearnerReport`
- `trend.py`: `TrendItem`, `TrendDirection`, trend models

**Validation:** All API inputs/outputs validated via Pydantic

---

### 1.5 Services (`/backend/services`)

#### `event_store.py`
**Purpose:** In-memory transient storage for raw gameplay events  
**Key Functions:**
- `add_event()`: Store event in memory (per session)
- `get_events()`: Retrieve events for session
- `clear_session()`: Remove all events for session (after pattern extraction)

**Storage:** `SessionData` dataclass with `session_id`, `learner_id`, `events` list, `is_complete` flag

**Lifecycle:** Events stored only during session, cleared after pattern extraction

---

#### `feature_engine.py`
**Purpose:** Extract quantitative metrics from raw events  
**Key Functions:**
- `extract_focus_tap_features()`: Computes mean reaction time, reaction time variability, miss rate from tap events

**Note:** Metrics used for pattern inference but never persisted or returned to clients

---

#### `pattern_engine.py` (105 lines)
**Purpose:** Rule-based pattern inference (NO ML)  
**Key Functions:**
- `infer_pattern()`: Simple `IF-THEN` rules to detect patterns
  - High variability → "Variable focus rhythm"
  - High miss rate → "Building target tracking"
  - Default → "Steady focus"
- Returns `PatternResult` with `pattern_name`, `learning_impact`, `support_focus` (language-only, no metrics in explanations)

**Rules:** Deterministic, explainable, non-diagnostic

---

#### `report_generator.py` (282 lines)
**Purpose:** Gemini-based AI report generation (Phase 3.1)  
**Key Functions:**
- `generate_report()`: Fetches pattern snapshots + trends, builds safe input (NO metrics), calls Gemini with system prompt, validates output, saves to `reports` table
- `_fetch_patterns()`: Gets pattern snapshots from DB (language fields only)
- `_fetch_trends()`: Gets trend summaries (optional)
- `_build_safe_input()`: Constructs user prompt with patterns/trends (no raw data, no metrics)
- `_call_gemini()`: Calls Gemini API (temperature 0.25, max 600 tokens)
- `_save_report()`: Inserts report with `generation_method='ai'`, `validation_status='pending'`

**Safety:** Only sends `pattern_name`, `learning_impact`, `support_focus`, `trend_type` to Gemini

---

#### `report_validator.py` (330 lines)
**Purpose:** Gemini-based report validation with RAG (Phase 3.2)  
**Key Functions:**
- `validate_report()`: Loads report content, loads RAG corpus files, calls Gemini validator, parses `STATUS: APPROVED/REWRITTEN/REJECTED`, updates DB
- `_load_rag_corpus()`: Loads static files (`forbidden_terms.txt`, `allowed_phrasing.txt`, `structure_rules.txt`, `example_safe_reports.md`)
- `_call_validator()`: Calls Gemini (temperature 0.1) with system prompt + RAG context
- `_parse_validator_response()`: Extracts status and rewritten content
- `_generate_fallback_report()`: Returns safe template if rejected

**RAG Corpus:** Static file-based (not vector DB) for language constraints and examples

---

#### `trend_engine.py` (122 lines)
**Purpose:** Deterministic trend computation from pattern snapshots  
**Key Functions:**
- `compute_trends_for_learner()`: Groups patterns by `pattern_name`, requires min 3 sessions, determines `trend_type` (stable/fluctuating/improving), upserts to `trend_summaries` table
- `_determine_trend_type()`: Logic:
  - `stable`: Pattern appears in >70% of sessions consistently
  - `fluctuating`: Pattern varies (30-70% or mixed)
  - `improving`: Pattern appeared more early, less recently

**Deterministic:** No ML, explainable rules

---

#### `llm_service.py` (206 lines)
**Purpose:** Legacy LLM service (may be deprecated in favor of report_generator)  
**Note:** Contains pattern explanation logic but may not be actively used

---

#### `/backend/services/prompts/`
**Static Prompt Files:**
- `gemini_report_generator.txt`: System prompt for report generation (non-diagnostic rules)
- `gemini_report_validator.txt`: System prompt for validation (governance layer)

---

#### `/backend/services/rag_corpus/`
**Static RAG Corpus Files:**
- `forbidden_terms.txt`: List of prohibited diagnostic/medical terms
- `allowed_phrasing.txt`: Approved alternative phrases
- `structure_rules.txt`: Report structure and language rules
- `example_safe_reports.md`: Example safe reports as precedent anchors

---

### 1.6 Utilities (`/backend/utils`)

#### `constants.py`
**Purpose:** Global constants (disclaimers, forbidden terms, TTL values)  
**Key Constants:**
- `DISCLAIMER_SHORT`: Standard disclaimer text
- `SESSION_TTL_HOURS`: Time-to-live for sessions

---

#### `safety_filters.py` (103 lines)
**Purpose:** Language filtering for non-diagnostic compliance  
**Key Functions:**
- `filter_diagnostic_language()`: Replaces prohibited terms with safe alternatives
- `validate_output_safety()`: Checks for forbidden terms, returns violations list
- `sanitize_llm_response()`: Applies filtering to LLM outputs

**Prohibited Terms:** diagnosis, disorder, disability, ADHD, autism, clinical, etc.

---

#### `code_generator.py`
**Purpose:** Learner access code generation  
**Key Functions:**
- `generate_learner_code()`: Generates 8-character alphanumeric code (excludes ambiguous chars: 0/O, 1/I/L)
- `is_valid_learner_code()`: Validates code format

---

#### `ttl_cleanup.py`
**Purpose:** Background scheduler to clean up expired sessions  
**Key Functions:**
- `start_cleanup_scheduler()`: Async task that periodically removes sessions older than TTL

---

#### `disclaimers.py`
**Purpose:** Disclaimer text constants and validation rules

---

## 2. Frontend Structure (`/lib`)

### 2.1 Entry Point (`lib/main.dart`)
**Purpose:** Flutter app initialization  
**Key Functions:**
- Initializes Supabase client with URL and anon key
- Defines `NeuroPlayApp` widget with theme configuration
- Routing: Login screen → HomeShell (if authenticated)

**Constants:** `supabaseUrl`, `supabaseAnonKey`, `backendUrl` (http://127.0.0.1:8000)

---

### 2.2 Models (`/lib/models`)

#### `user.dart`
**Purpose:** User/observer data model

#### `activity.dart`
**Purpose:** Activity/session data model

#### `insight.dart`
**Purpose:** Pattern/insight data model

---

### 2.3 Screens (`/lib/screens`)

#### `login_screen.dart` / `signup_screen.dart` / `auth_screen.dart`
**Purpose:** Authentication UI (Supabase email/password)

#### `home_shell.dart`
**Purpose:** Bottom navigation bar container  
**Tabs:** Home, Trends, About, Profile

#### `home_screen.dart`
**Purpose:** Learner list with "Add learner" functionality  
**Features:**
- Static caching for instant display
- Shows learner aliases
- `_LearnerCodeDialog` displays `learner_code` once on creation
- Navigates to `LearnerContextScreen` on learner tap

#### `learner_context_screen.dart`
**Purpose:** Learner detail view  
**Features:**
- Displays learner name and `learner_code` badge
- Fetches and displays learner report (patterns)
- Shows report sections: Observed patterns, What this may affect, Support suggestions

#### `report_screen.dart` (410 lines)
**Purpose:** Learning summary report display  
**Features:**
- Fetches session report from API
- Displays patterns with learning impacts and support suggestions
- Shows disclaimer and metadata
- Handles loading/error states with skeletons

#### `trends_screen.dart` (198 lines)
**Purpose:** Longitudinal trends display  
**Features:**
- Fetches trends from API (`/api/trends/learner/{learner_id}`)
- Displays pattern names with trend summaries (canonical language templates)
- Shows empty state if insufficient data (< 3 sessions)

#### `profile_screen.dart`
**Purpose:** User profile and settings  
**Features:**
- Shows account email, role
- Sign out button (destructive styling)

#### `how_it_works_screen.dart`
**Purpose:** "About NeuroPlay" information screen  
**Content:** Tool description, privacy, what is observed

#### `dashboard_screen.dart`, `learners_screen.dart`, `insights_screen.dart`, `activity_screen.dart`, `focus_tap_game_screen.dart`
**Purpose:** Legacy/unused screens (may be deprecated)

---

### 2.4 Services (`/lib/services`)

#### `supabase_service.dart`
**Purpose:** Supabase client wrapper (if needed)

#### `gemini_service.dart`
**Purpose:** Placeholder for Gemini integration (unused, backend handles Gemini)

---

### 2.5 Theme (`/lib/theme`)

#### `design_tokens.dart`
**Purpose:** Design system constants  
**Defines:**
- `AppColors`: Primary (#2F3E46), Secondary (#52796F), Background (#F8F9FA), Text colors, Destructive (#B85C5C)
- `AppTypography`: Font sizes, weights, line heights
- `AppSpacing`: Padding/margin constants
- `AppRadius`: Border radius values

#### `animation_tokens.dart`
**Purpose:** Animation timing constants  
**Defines:**
- `kFadeDuration`: 180ms (fade transitions)
- `kCrossFadeDuration`: 220ms (cross-fade)
- `kSkeletonPulseDuration`: 1200ms (skeleton loading)

---

### 2.6 Widgets (`/lib/widgets`)

#### `skeleton.dart`
**Purpose:** Loading skeleton widgets (shimmer effect for reports)

#### `activity_card.dart`, `insight_card.dart`
**Purpose:** Legacy card widgets (may be unused)

---

### 2.7 Utils (`/lib/utils`)

#### `constants.dart`
**Purpose:** Flutter app constants (disclaimers, text)

#### `helpers.dart`
**Purpose:** Helper functions (navigation, formatting)

---

## 3. Configuration Files

### Root Level

#### `requirements.txt`
**Dependencies:** fastapi, uvicorn, pydantic, supabase, google-generativeai, httpx, python-dotenv, PyJWT

#### `pubspec.yaml`
**Dependencies:** Flutter packages (supabase_flutter, http, etc.)

#### `backend/env.example`
**Template:** Environment variable examples for backend

#### `README.md`
**Project documentation**

#### `001_initial_schema.sql`
**Legacy:** Original schema file (superseded by `000_complete_schema.sql`)

---

## 4. Architecture Patterns

### 4.1 Security
- **RLS (Row Level Security):** All database tables enforce observer ownership via Supabase policies
- **JWT Authentication:** Parent/teacher app uses Supabase JWT
- **Learner Codes:** Child app uses non-identifying 8-character codes (rate-limited)
- **Service Role Key:** Backend writes use `service_role` key to bypass RLS when appropriate

### 4.2 Data Privacy
- **Transient Events:** Raw gameplay events stored only in memory, cleared after pattern extraction
- **Pattern Snapshots:** Only language fields persisted (no metrics, no raw data)
- **Non-Diagnostic Language:** All outputs filtered for prohibited terms
- **No Child Identity:** Children never authenticated, only `learner_code` used

### 4.3 AI Safety
- **Two-Layer Validation:** Generator (Phase 3.1) → Validator (Phase 3.2) with RAG corpus
- **RAG Corpus:** Static files enforce language constraints
- **Fallback Templates:** Rejected reports replaced with safe templates
- **No Metric Exposure:** Gemini never receives raw gameplay data or metrics

### 4.4 Deterministic Logic
- **Pattern Inference:** Rule-based `IF-THEN` (no ML)
- **Trend Computation:** Deterministic aggregation (no ML, explainable)
- **No Confidence Values:** Confidence removed from client-facing APIs

---

## 5. Data Flow

### 5.1 Session Flow
```
1. Child app: POST /api/sessions/child/start (learner_code)
   → Returns session_id

2. Child app: POST /api/sessions/child/{id}/events (events)
   → Events stored in memory (event_store)

3. Child app: POST /api/sessions/child/{id}/complete
   → Feature extraction → Pattern inference → Pattern snapshot saved → Events cleared

4. Parent app: GET /api/reports/learner/{learner_id}
   → Returns pattern summaries (language-only)
```

### 5.2 AI Report Generation Flow
```
1. POST /api/reports/generate
   → Check cache → Generate (Gemini) → Validate (Gemini + RAG) → Save to reports table

2. GET /api/reports/ai/{report_id}
   → Returns narrative report content and validation_status
```

### 5.3 Trend Computation Flow
```
1. GET /api/trends/learner/{learner_id}
   → trend_engine.compute_trends_for_learner()
   → Aggregates pattern_snapshots (min 3 sessions)
   → Determines trend_type (stable/fluctuating/improving)
   → Upserts to trend_summaries table
   → Returns pattern_name + trend_type
```

---

## 6. Key Design Decisions

1. **Two Access Modes:** Authenticated adults (JWT) vs. unauthenticated children (learner_code)
2. **Transient Raw Data:** Events never persisted, only pattern summaries
3. **Language-Only Outputs:** No metrics, scores, or confidence values in client APIs
4. **Static RAG Corpus:** File-based constraints (not vector DB) for auditability
5. **Phase-Gated Features:** Trends require min 3 sessions
6. **Fail-Fast Config:** Backend exits if required env vars missing
7. **Singleton Services:** Trend engine, report generator, validator use singleton pattern

---

## 7. Technology Stack Summary

**Backend:**
- FastAPI (Python web framework)
- Supabase (PostgreSQL + Auth + RLS)
- Google Gemini API (AI report generation/validation)
- Pydantic (data validation)

**Frontend:**
- Flutter (Dart, cross-platform)
- Supabase Flutter SDK (authentication)
- HTTP package (API calls)

**Database:**
- PostgreSQL (via Supabase)
- Row Level Security (RLS) for multi-tenancy

---

## 8. File Count Summary

**Backend:**
- Routes: 7 files
- Services: 8 Python files + 2 prompt files + 4 RAG corpus files
- Schemas: 5 files
- DB: 4 migration files + models + supabase client
- Utils: 6 files
- Config: 3 files

**Frontend:**
- Screens: 15 Dart files
- Models: 3 files
- Services: 2 files
- Theme: 2 files
- Widgets: 3 files
- Utils: 2 files

**Total:** ~80 source files (excluding generated files, tests, build artifacts)

---

## 9. Testing

**Backend Tests:**
- `backend/tests/test_rls_isolation.py`: Row-level security isolation tests

**Frontend Tests:**
- `test/widget_test.dart`: Widget tests (placeholder)

---

## 10. Known Limitations / TODOs

1. **Legacy Files:** Some screens (`dashboard_screen.dart`, `insights_screen.dart`) may be unused
2. **LLM Service:** `llm_service.py` may be deprecated in favor of `report_generator.py`
3. **Incremental Trends:** `trend_engine.update_trends_for_session()` not implemented
4. **Trend History:** `/api/trends/learner/{learner_id}/history` returns "not_available"
5. **Child App:** Frontend child app not yet implemented (only backend routes exist)

---

**End of Report**
