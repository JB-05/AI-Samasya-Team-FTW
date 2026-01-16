# Authentication routes for adult observers only
# Real Supabase Auth integration

from fastapi import APIRouter, HTTPException, status

from ..dependencies import CurrentObserver

router = APIRouter(prefix="/auth", tags=["authentication"])


@router.get("/me")
async def get_me(observer: CurrentObserver):
    """
    Get the current authenticated observer.
    
    Returns:
        observer_id and role
    
    This is the gold endpoint for demos - proves auth works.
    """
    return {
        "observer_id": str(observer.observer_id),
        "role": observer.role
    }


@router.get("/status")
async def auth_status(observer: CurrentObserver):
    """
    Check authentication status.
    
    Returns detailed auth info for debugging.
    """
    return {
        "authenticated": True,
        "observer_id": str(observer.observer_id),
        "role": observer.role,
        "message": "Token valid"
    }


@router.get("/debug")
async def debug_learners(observer: CurrentObserver):
    """Debug endpoint to check learner query."""
    from ..db.supabase import get_supabase_admin
    
    admin = get_supabase_admin()
    if not admin:
        return {"error": "No admin client"}
    
    obs_id = str(observer.observer_id)
    
    # Get all learners (no filter)
    all_learners = admin.table("learners").select("observer_id, alias").execute()
    
    # Get learners for this observer
    my_learners = admin.table("learners").select("*").eq("observer_id", obs_id).execute()
    
    return {
        "your_observer_id": obs_id,
        "all_learners_in_db": all_learners.data,
        "your_learners": my_learners.data,
        "match_count": len(my_learners.data) if my_learners.data else 0
    }
