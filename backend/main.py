# =============================================================================
# FastAPI Application Entry Point
# Learning Pattern Analysis API (NeuroPlay Backend)
# =============================================================================
#
# Two access modes:
# 1. OBSERVER (Parent/Teacher): Supabase JWT authentication
# 2. CHILD APP: Learner code only (write-only, no auth)
#
# =============================================================================

from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import asyncio

from .config import get_settings_dev
from .routes import auth, learners, sessions, reports, trends, chat
from .routes.health import router as health_router
from .routes import reports_generate
from .utils.ttl_cleanup import start_cleanup_scheduler
from .utils.constants import DISCLAIMER_SHORT


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler."""
    settings = get_settings_dev()
    
    if settings:
        print(f" Starting NeuroPlay API")
        print(f"   Environment: {settings.environment}")
        print(f"   Supabase: {settings.supabase_url[:30]}...")
    else:
        print("⚠️  Starting in degraded mode - check .env file")
    
    print("🔐 Auth: Supabase JWT + Learner Code")
    
    cleanup_task = asyncio.create_task(start_cleanup_scheduler())
    
    yield
    
    cleanup_task.cancel()
    print("Shutting down...")


app = FastAPI(
    title="NeuroPlay API",
    redirect_slashes=False,
    description=f"""
Privacy-safe API for observing children's learning patterns.

## Authentication Modes

### 1. Observer (Parent/Teacher App)
Requires Supabase JWT token:
```
Authorization: Bearer <your-supabase-token>
```

### 2. Child App
Uses learner_code only - no authentication.
Write-only access for session data.

---

## Quick Start

### For Parent/Teacher App:
1. Login via Supabase Auth (frontend)
2. `GET /api/auth/me` - verify token
3. `GET /api/learners` - list learners
4. `POST /api/learners` - create learner (returns code ONCE)
5. `POST /api/sessions/start` - start session
6. `GET /api/reports/learner/{{id}}` - view patterns

### For Child App:
1. `POST /api/sessions/child/start` - start with learner_code
2. `POST /api/sessions/child/{{id}}/events` - log events
3. `POST /api/sessions/child/{{id}}/complete` - finish

---

## Public Endpoints (no auth)
- `GET /health` - Health check
- `POST /api/sessions/child/*` - Child app routes (learner_code required)

## Protected Endpoints (JWT required)
- `GET /api/auth/me` - Get current observer
- `GET/POST /api/learners` - Manage learners
- `POST /api/sessions/start|events|complete` - Observer sessions
- `GET /api/reports/*` - View pattern reports

## Phase-Gated (returns not_available)
- `GET /api/trends/*` - Longitudinal trends (future)

---

**Disclaimer**: {DISCLAIMER_SHORT}
    """,
    version="1.1.0",
    lifespan=lifespan,
)

# CORS - allow Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # TODO: Restrict in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Public routes (no auth)
app.include_router(health_router)

# Protected routes (auth required for most)
app.include_router(auth.router, prefix="/api")
app.include_router(learners.router, prefix="/api")
app.include_router(sessions.router, prefix="/api")
app.include_router(reports.router, prefix="/api")
app.include_router(reports_generate.router, prefix="/api")
app.include_router(trends.router, prefix="/api")
app.include_router(chat.router, prefix="/api")


@app.get("/")
async def root():
    """Root endpoint."""
    return {
        "name": "NeuroPlay API",
        "version": "1.1.0",
        "auth_modes": ["supabase_jwt", "learner_code"],
        "docs": "/docs",
        "health": "/health",
    }
