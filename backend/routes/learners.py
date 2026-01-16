# Routes for managing learners (alias-based references only)
# All operations REQUIRE authenticated observer context
#
# PRIVACY: Learners contain NO identifying information
# - Only adult-defined aliases (e.g., "Learner A")
# - No age, gender, grade, or real names
#
# OWNERSHIP: observer_id NEVER comes from client
# - Always injected from CurrentObserver (JWT auth)
# - RLS enforces isolation at database level

from fastapi import APIRouter, HTTPException, status
from typing import List
from uuid import UUID
from datetime import datetime

from ..dependencies import CurrentObserver
from ..schemas.learner import LearnerCreate, LearnerRead, LearnerUpdate
from ..db.supabase import get_supabase, get_supabase_admin

router = APIRouter(prefix="/learners", tags=["learners"])


# =============================================================================
# POST /api/learners - Create a new learner alias
# =============================================================================

@router.post("", response_model=LearnerRead, status_code=status.HTTP_201_CREATED)
async def create_learner(
    learner: LearnerCreate,
    observer: CurrentObserver  # REQUIRED - will 401 if not authenticated
):
    """
    Create a new learner alias for observation.
    
    REQUIRES: Valid authentication token
    
    Request Body:
        {"alias": "Learner A"}
    
    Success (201):
        {"learner_id": "uuid", "alias": "Learner A", "created_at": "ISO8601"}
    
    Error (409):
        {"detail": "A learner with this alias already exists."}
    
    NOTE: 
    - observer_id comes from auth context, NEVER from client
    - Alias is trimmed and validated
    - Duplicates are blocked within the same observer
    """
    print(f"[DEBUG] create_learner called: alias={learner.alias}, observer_id={observer.observer_id}")
    
    # Use admin client for write operations (bypasses RLS)
    # Backend is trusted - it already validates JWT
    supabase = get_supabase_admin() or get_supabase()
    
    if not supabase:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database connection unavailable"
        )
    
    # Alias is already sanitized by Pydantic validator
    sanitized_alias = learner.alias
    
    try:
        # Check for duplicate alias within this observer's learners
        existing = supabase.table("learners").select("learner_id").eq(
            "observer_id", str(observer.observer_id)
        ).eq(
            "alias", sanitized_alias
        ).execute()
        
        if existing.data and len(existing.data) > 0:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="A learner with this alias already exists."
            )
        
        # Insert new learner
        # observer_id comes from auth context, NOT from client
        result = supabase.table("learners").insert({
            "observer_id": str(observer.observer_id),
            "alias": sanitized_alias
        }).execute()
        
        if result.data and len(result.data) > 0:
            data = result.data[0]
            return LearnerRead(
                learner_id=UUID(data["learner_id"]),
                alias=data["alias"],
                created_at=datetime.fromisoformat(
                    data["created_at"].replace("Z", "+00:00")
                )
            )
        
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create learner"
        )
        
    except HTTPException:
        # Re-raise HTTP exceptions as-is
        raise
    except Exception as e:
        print(f"[DEBUG] create_learner ERROR: {type(e).__name__}: {e}")
        # Check for unique constraint violation (Supabase/PostgreSQL)
        error_str = str(e).lower()
        if "unique" in error_str or "duplicate" in error_str or "23505" in error_str:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="A learner with this alias already exists."
            )
        # Generic error - do NOT expose internal details
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="An unexpected error occurred"
        )


# =============================================================================
# GET /api/learners - List all learners for current observer
# =============================================================================

@router.get("", response_model=List[LearnerRead])
async def list_learners(observer: CurrentObserver):
    """
    List all learners associated with the authenticated observer.
    
    REQUIRES: Valid authentication token
    
    Uses admin client since we validate JWT ourselves.
    Filters by observer_id from auth context.
    """
    import sys
    print(f"[DEBUG] list_learners called: observer_id={observer.observer_id}", flush=True)
    sys.stdout.flush()
    
    # Use admin client to bypass RLS (we already validated JWT)
    supabase = get_supabase_admin()
    print(f"[DEBUG] Admin client: {supabase is not None}", flush=True)
    
    if not supabase:
        supabase = get_supabase()
        print(f"[DEBUG] Fallback to anon client", flush=True)
    
    if not supabase:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database connection unavailable"
        )
    
    try:
        obs_id_str = str(observer.observer_id)
        print(f"[DEBUG] Querying learners for observer_id: {obs_id_str}", flush=True)
        
        # Query learners for this observer
        result = supabase.table("learners").select("*").eq(
            "observer_id", obs_id_str
        ).order("created_at", desc=False).execute()
        
        print(f"[DEBUG] Query result count: {len(result.data) if result.data else 0}", flush=True)
        print(f"[DEBUG] Raw result: {result.data}", flush=True)
        
        learners = []
        for data in result.data or []:
            learners.append(LearnerRead(
                learner_id=UUID(data["learner_id"]),
                alias=data["alias"],
                created_at=datetime.fromisoformat(
                    data["created_at"].replace("Z", "+00:00")
                )
            ))
        print(f"[DEBUG] Returning {len(learners)} learners", flush=True)
        return learners
        
    except Exception as e:
        print(f"[DEBUG] ERROR: {e}", flush=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="An unexpected error occurred"
        )


# =============================================================================
# GET /api/learners/{learner_id} - Get a specific learner
# =============================================================================

@router.get("/{learner_id}", response_model=LearnerRead)
async def get_learner(
    learner_id: UUID,
    observer: CurrentObserver
):
    """
    Get a specific learner by ID.
    
    REQUIRES: Valid authentication token
    """
    supabase = get_supabase()
    
    if not supabase:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database connection unavailable"
        )
    
    try:
        result = supabase.table("learners").select("*").eq(
            "learner_id", str(learner_id)
        ).eq(
            "observer_id", str(observer.observer_id)  # Ownership via auth
        ).execute()
        
        if not result.data or len(result.data) == 0:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Learner not found"
            )
        
        data = result.data[0]
        return LearnerRead(
            learner_id=UUID(data["learner_id"]),
            alias=data["alias"],
            created_at=datetime.fromisoformat(
                data["created_at"].replace("Z", "+00:00")
            )
        )
        
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="An unexpected error occurred"
        )


# =============================================================================
# PATCH /api/learners/{learner_id} - Update a learner's alias
# =============================================================================

@router.patch("/{learner_id}", response_model=LearnerRead)
async def update_learner(
    learner_id: UUID,
    update: LearnerUpdate,
    observer: CurrentObserver
):
    """
    Update a learner's alias.
    
    REQUIRES: Valid authentication token
    
    Error (409) if new alias conflicts with existing learner.
    """
    if not update.alias:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No update data provided"
        )
    
    # Use admin client for write operations
    supabase = get_supabase_admin() or get_supabase()
    
    if not supabase:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database connection unavailable"
        )
    
    sanitized_alias = update.alias
    
    try:
        # Check for duplicate alias (excluding current learner)
        existing = supabase.table("learners").select("learner_id").eq(
            "observer_id", str(observer.observer_id)
        ).eq(
            "alias", sanitized_alias
        ).neq(
            "learner_id", str(learner_id)
        ).execute()
        
        if existing.data and len(existing.data) > 0:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="A learner with this alias already exists."
            )
        
        # Update
        result = supabase.table("learners").update({
            "alias": sanitized_alias
        }).eq(
            "learner_id", str(learner_id)
        ).eq(
            "observer_id", str(observer.observer_id)
        ).execute()
        
        if not result.data or len(result.data) == 0:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Learner not found"
            )
        
        data = result.data[0]
        return LearnerRead(
            learner_id=UUID(data["learner_id"]),
            alias=data["alias"],
            created_at=datetime.fromisoformat(
                data["created_at"].replace("Z", "+00:00")
            )
        )
        
    except HTTPException:
        raise
    except Exception as e:
        error_str = str(e).lower()
        if "unique" in error_str or "duplicate" in error_str or "23505" in error_str:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="A learner with this alias already exists."
            )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="An unexpected error occurred"
        )


# =============================================================================
# DELETE /api/learners/{learner_id} - Delete a learner
# =============================================================================

@router.delete("/{learner_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_learner(
    learner_id: UUID,
    observer: CurrentObserver
):
    """
    Delete a learner and all associated data.
    
    REQUIRES: Valid authentication token
    
    WARNING: This permanently removes all data for this learner.
    Cascade delete handles sessions, patterns, trends.
    """
    # Use admin client for write operations
    supabase = get_supabase_admin() or get_supabase()
    
    if not supabase:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database connection unavailable"
        )
    
    try:
        # Delete - ownership check via observer_id filter
        supabase.table("learners").delete().eq(
            "learner_id", str(learner_id)
        ).eq(
            "observer_id", str(observer.observer_id)
        ).execute()
        
        # Cascade delete handles sessions, patterns, trends
        return
        
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="An unexpected error occurred"
        )
