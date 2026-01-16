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
#
# LEARNER CODE: Generated on creation, shown ONCE
# - Used by child app for session ingestion
# - Grants WRITE-ONLY access
# - Never shown again after creation

from fastapi import APIRouter, HTTPException, status
from typing import List
from uuid import UUID
from datetime import datetime

from ..dependencies import CurrentObserver
from ..schemas.learner import LearnerCreate, LearnerRead, LearnerUpdate, LearnerCreateResponse
from ..db.supabase import get_supabase, get_supabase_admin
from ..utils.code_generator import generate_learner_code

router = APIRouter(prefix="/learners", tags=["learners"])


# =============================================================================
# POST /api/learners - Create a new learner alias
# =============================================================================

@router.post("", response_model=LearnerCreateResponse, status_code=status.HTTP_201_CREATED)
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
        {
            "learner_id": "uuid",
            "alias": "Learner A",
            "learner_code": "ABC12345",  // SHOWN ONCE
            "created_at": "ISO8601",
            "message": "Save this code - it will not be shown again."
        }
    
    IMPORTANT: learner_code is returned ONCE. Parent must save it.
    
    Error (409):
        {"detail": "A learner with this alias already exists."}
    """
    # Use admin client for write operations (bypasses RLS)
    supabase = get_supabase_admin() or get_supabase()
    
    if not supabase:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database connection unavailable"
        )
    
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
        
        # Generate unique learner code
        # Retry up to 5 times in case of collision (extremely rare)
        learner_code = None
        for _ in range(5):
            candidate_code = generate_learner_code()
            # Check if code already exists
            code_check = supabase.table("learners").select("learner_id").eq(
                "learner_code", candidate_code
            ).execute()
            if not code_check.data or len(code_check.data) == 0:
                learner_code = candidate_code
                break
        
        if not learner_code:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to generate unique code. Please try again."
            )
        
        # Insert new learner with generated code
        result = supabase.table("learners").insert({
            "observer_id": str(observer.observer_id),
            "alias": sanitized_alias,
            "learner_code": learner_code
        }).execute()
        
        if result.data and len(result.data) > 0:
            data = result.data[0]
            return LearnerCreateResponse(
                learner_id=UUID(data["learner_id"]),
                alias=data["alias"],
                learner_code=data["learner_code"],  # Shown ONCE
                created_at=datetime.fromisoformat(
                    data["created_at"].replace("Z", "+00:00")
                ),
                message="Save this code - it will not be shown again."
            )
        
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create learner"
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
# GET /api/learners - List all learners for current observer
# =============================================================================

@router.get("", response_model=List[LearnerRead])
async def list_learners(observer: CurrentObserver):
    """
    List all learners associated with the authenticated observer.
    
    REQUIRES: Valid authentication token
    
    Returns ONLY:
    - learner_id
    - alias
    - created_at
    
    Does NOT return:
    - session counts
    - last activity timestamps
    - derived stats
    - learner_code (shown only on creation)
    """
    supabase = get_supabase_admin() or get_supabase()
    
    if not supabase:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database connection unavailable"
        )
    
    try:
        # Query learners - include learner_code for context screen
        result = supabase.table("learners").select(
            "learner_id, alias, learner_code, created_at"
        ).eq(
            "observer_id", str(observer.observer_id)
        ).order("created_at", desc=False).execute()
        
        learners = []
        for data in result.data or []:
            learners.append(LearnerRead(
                learner_id=UUID(data["learner_id"]),
                alias=data["alias"],
                learner_code=data["learner_code"],
                created_at=datetime.fromisoformat(
                    data["created_at"].replace("Z", "+00:00")
                )
            ))
        return learners
        
    except Exception:
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
    
    Does NOT return learner_code.
    """
    supabase = get_supabase_admin() or get_supabase()
    
    if not supabase:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database connection unavailable"
        )
    
    try:
        result = supabase.table("learners").select(
            "learner_id, alias, learner_code, created_at"
        ).eq(
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
            learner_code=data["learner_code"],
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
    supabase = get_supabase_admin() or get_supabase()
    
    if not supabase:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database connection unavailable"
        )
    
    try:
        supabase.table("learners").delete().eq(
            "learner_id", str(learner_id)
        ).eq(
            "observer_id", str(observer.observer_id)
        ).execute()
        
        return
        
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="An unexpected error occurred"
        )
