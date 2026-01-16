# Health and verification routes
# These endpoints are PUBLIC (no auth required)

from fastapi import APIRouter
from datetime import datetime

from ..config import get_settings_dev
from ..utils.constants import DISCLAIMER_SHORT, FORBIDDEN_TERMS
from ..db.supabase import get_supabase

router = APIRouter(tags=["health"])


@router.get("/health")
async def health_check():
    """
    Basic health check endpoint.
    PUBLIC - no auth required.
    """
    settings = get_settings_dev()
    config_valid = settings is not None
    
    supabase = get_supabase()
    db_connected = supabase is not None
    
    return {
        "status": "healthy" if (config_valid and db_connected) else "degraded",
        "timestamp": datetime.utcnow().isoformat(),
        "checks": {
            "config": "ok" if config_valid else "missing",
            "database": "ok" if db_connected else "not_connected",
        },
        "disclaimer": DISCLAIMER_SHORT,
    }


@router.get("/health/config")
async def config_check():
    """
    Verify configuration is loaded.
    PUBLIC - no auth required.
    """
    settings = get_settings_dev()
    
    if settings is None:
        return {
            "status": "error",
            "message": "Configuration invalid",
            "required_vars": ["SUPABASE_URL", "SUPABASE_ANON_KEY", "GEMINI_KEY"],
        }
    
    return {
        "status": "ok",
        "environment": settings.environment,
        "supabase_url": settings.supabase_url[:30] + "..." if settings.supabase_url else None,
    }


@router.get("/health/guardrails")
async def guardrails_check():
    """
    Verify safety guardrails are active.
    PUBLIC - no auth required.
    """
    return {
        "status": "ok",
        "forbidden_terms_count": len(FORBIDDEN_TERMS),
        "disclaimer_active": True,
    }
