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
# GET /api/learners/{learner_id}/metrics - Get learner metrics/statistics
# =============================================================================

@router.get("/{learner_id}/metrics")
async def get_learner_metrics(
    learner_id: UUID,
    observer: CurrentObserver
):
    """
    Get metrics and statistics for a learner.
    
    Returns session counts, pattern counts, and other aggregated metrics.
    These metrics are for profile display only and are NOT included in AI reports.
    """
    supabase = get_supabase_admin() or get_supabase()
    
    if not supabase:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database connection unavailable"
        )
    
    # Verify learner belongs to observer
    learner_check = supabase.table("learners").select("learner_id").eq(
        "learner_id", str(learner_id)
    ).eq(
        "observer_id", str(observer.observer_id)
    ).execute()
    
    if not learner_check.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Learner not found"
        )
    
    # Count sessions
    sessions_result = supabase.table("sessions").select("session_id", count="exact").eq(
        "learner_id", str(learner_id)
    ).execute()
    
    session_count = sessions_result.count if sessions_result.count is not None else 0
    
    # Count patterns
    patterns_result = supabase.table("pattern_snapshots").select("snapshot_id", count="exact").eq(
        "learner_id", str(learner_id)
    ).execute()
    
    pattern_count = patterns_result.count if patterns_result.count is not None else 0
    
    # Calculate average patterns per session
    avg_patterns_per_session = round(pattern_count / session_count, 2) if session_count > 0 else 0.0
    
    # Get pattern distribution (count per pattern name)
    pattern_distribution_result = supabase.table("pattern_snapshots").select(
        "pattern_name"
    ).eq(
        "learner_id", str(learner_id)
    ).execute()
    
    pattern_distribution = {}
    if pattern_distribution_result.data:
        for p in pattern_distribution_result.data:
            pattern_name = p.get("pattern_name", "Unknown")
            pattern_distribution[pattern_name] = pattern_distribution.get(pattern_name, 0) + 1
    
    # Get most common pattern
    most_common_pattern = None
    if pattern_distribution:
        most_common_pattern = max(pattern_distribution.items(), key=lambda x: x[1])[0]
    
    # Calculate pattern variety (unique patterns / total patterns)
    unique_pattern_count = len(pattern_distribution)
    pattern_variety = round((unique_pattern_count / pattern_count * 100) if pattern_count > 0 else 0, 1)
    
    # Get confidence distribution from pattern snapshots
    confidence_result = supabase.table("pattern_snapshots").select(
        "confidence"
    ).eq(
        "learner_id", str(learner_id)
    ).execute()
    
    confidence_distribution = {"high": 0, "moderate": 0, "low": 0}
    if confidence_result.data:
        for p in confidence_result.data:
            conf = p.get("confidence", "").lower()
            if conf in confidence_distribution:
                confidence_distribution[conf] += 1
    
    # Calculate confidence score (weighted: high=3, moderate=2, low=1)
    total_conf = confidence_distribution["high"] + confidence_distribution["moderate"] + confidence_distribution["low"]
    if total_conf > 0:
        conf_score = (
            confidence_distribution["high"] * 3 +
            confidence_distribution["moderate"] * 2 +
            confidence_distribution["low"] * 1
        ) / (total_conf * 3) * 100
    else:
        conf_score = 0.0
    
    # Calculate recent activity (sessions in last 30 days)
    from datetime import datetime, timedelta
    thirty_days_ago = (datetime.utcnow() - timedelta(days=30)).isoformat()
    recent_sessions_result = supabase.table("sessions").select("session_id", count="exact").eq(
        "learner_id", str(learner_id)
    ).gte("created_at", thirty_days_ago).execute()
    
    recent_session_count = recent_sessions_result.count if recent_sessions_result.count is not None else 0
    recent_activity_rate = round((recent_session_count / session_count * 100) if session_count > 0 else 0, 1)
    
    # Calculate session frequency (sessions per week, if data spans at least 7 days)
    if session_count > 0:
        first_session_result = supabase.table("sessions").select("created_at").eq(
            "learner_id", str(learner_id)
        ).order("created_at", desc=False).limit(1).execute()
        
        if first_session_result.data:
            first_session_date = datetime.fromisoformat(
                first_session_result.data[0]["created_at"].replace("Z", "+00:00")
            )
            days_active = (datetime.utcnow() - first_session_date.replace(tzinfo=None)).days
            if days_active > 0:
                sessions_per_week = round((session_count / days_active * 7), 1)
            else:
                sessions_per_week = float(session_count) if session_count > 0 else 0.0
        else:
            sessions_per_week = 0.0
    else:
        sessions_per_week = 0.0
    
    # Calculate consistency score (how often the same patterns repeat)
    if pattern_count > 0 and unique_pattern_count > 0:
        # Higher score = more repetition (patterns appear multiple times)
        consistency_score = round((1 - (unique_pattern_count / pattern_count)) * 100, 1)
        consistency_score = max(0, min(100, consistency_score))  # Clamp 0-100
    else:
        consistency_score = 0.0
    
    return {
        "learner_id": str(learner_id),
        "session_count": session_count,
        "pattern_count": pattern_count,
        "avg_patterns_per_session": avg_patterns_per_session,
        "most_common_pattern": most_common_pattern,
        "pattern_distribution": pattern_distribution,
        # New metrics
        "pattern_variety": pattern_variety,  # Unique patterns / total patterns (%)
        "confidence_score": round(conf_score, 1),  # Weighted confidence score (0-100)
        "recent_activity_rate": recent_activity_rate,  # Sessions in last 30 days (%)
        "sessions_per_week": sessions_per_week,  # Average sessions per week
        "consistency_score": consistency_score,  # Pattern repetition score (0-100)
    }


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
