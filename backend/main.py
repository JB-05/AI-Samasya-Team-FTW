# FastAPI application entry point
# Learning Pattern Analysis API
# Real Supabase Auth integration

from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import asyncio

from .config import get_settings_dev
from .routes import auth, learners, sessions, reports, trends
from .routes.health import router as health_router
from .utils.ttl_cleanup import start_cleanup_scheduler
from .utils.constants import DISCLAIMER_SHORT


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler."""
    settings = get_settings_dev()
    
    if settings:
        print(f"✅ Starting {settings.app_name}")
        print(f"   Environment: {settings.environment}")
        print(f"   Supabase: {settings.supabase_url[:30]}...")
    else:
        print("⚠️  Starting in degraded mode - check .env file")
    
    print("🔐 Auth: Real Supabase JWT verification enabled")
    
    cleanup_task = asyncio.create_task(start_cleanup_scheduler())
    
    yield
    
    cleanup_task.cancel()
    print("Shutting down...")


app = FastAPI(
    title="Learning Pattern Analysis API",
    redirect_slashes=False,  # Don't redirect /path to /path/ or vice versa
    description=f"""
Privacy-safe API for analyzing children's learning patterns.

## Authentication
All protected endpoints require a valid Supabase JWT token.

```
Authorization: Bearer <your-supabase-token>
```

## Quick Start
1. Login via Supabase Auth (frontend)
2. Call `GET /api/auth/me` to verify token
3. Call `GET /api/learners` to list your learners

## Public Endpoints (no auth)
- `GET /health` - Health check
- `GET /health/config` - Config status

## Protected Endpoints (auth required)
- `GET /api/auth/me` - Get current observer
- `GET /api/learners` - List learners
- `POST /api/learners` - Create learner
- All `/api/sessions`, `/api/reports`, `/api/trends`

---

**Disclaimer**: {DISCLAIMER_SHORT}
    """,
    version="1.0.0",
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

# Protected routes (auth required)
app.include_router(auth.router, prefix="/api")
app.include_router(learners.router, prefix="/api")
app.include_router(sessions.router, prefix="/api")
app.include_router(reports.router, prefix="/api")
app.include_router(trends.router, prefix="/api")


@app.get("/")
async def root():
    """Root endpoint."""
    return {
        "name": "Learning Pattern Analysis API",
        "version": "1.0.0",
        "auth": "Supabase JWT",
        "docs": "/docs",
        "health": "/health",
    }
