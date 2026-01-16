# =============================================================================
# TRENDS API (Phase-Gated)
# Longitudinal trend summaries - NOT YET AVAILABLE
# =============================================================================
#
# All routes return: {"status": "not_available"}
#
# Trends will aggregate pattern data across multiple sessions
# when implemented in a future phase.
#
# =============================================================================

from fastapi import APIRouter, HTTPException, status
from uuid import UUID
from typing import Optional, List
from datetime import date
from pydantic import BaseModel

from ..dependencies import CurrentObserver
from ..db.supabase import get_supabase_admin
from ..services.trend_engine import get_trend_engine

router = APIRouter(prefix="/trends", tags=["trends"])


# =============================================================================
# RESPONSE SCHEMAS
# =============================================================================

class TrendItem(BaseModel):
    """Single trend item - language only, no numbers."""
    pattern_name: str
    trend_type: str  # 'stable', 'fluctuating', or 'improving'


class LearnerTrendsResponse(BaseModel):
    """Trend response for a learner."""
    learner_id: UUID
    trends: List[TrendItem]
    message: Optional[str] = None


@router.get("/learner/{learner_id}", response_model=LearnerTrendsResponse)
async def get_learner_trends(
    learner_id: UUID,
    observer: CurrentObserver
):
    """
    Get trend summary for a learner.
    
    Computes trends deterministically from pattern_snapshots.
    Requires minimum 3 sessions.
    
    Returns:
        pattern_name and trend_type for each pattern
        No numbers, no charts, no metrics
    """
    supabase = get_supabase_admin()
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
    
    # Compute trends
    try:
        trend_engine = get_trend_engine()
        trends = trend_engine.compute_trends_for_learner(learner_id)
        
        if not trends:
            return LearnerTrendsResponse(
                learner_id=learner_id,
                trends=[],
                message="Insufficient data. Trends require at least 3 sessions."
            )
        
        trend_items = [
            TrendItem(pattern_name=t["pattern_name"], trend_type=t["trend_type"])
            for t in trends
        ]
        
        return LearnerTrendsResponse(
            learner_id=learner_id,
            trends=trend_items
        )
        
    except Exception as e:
        print(f"[ERROR] Trend computation failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to compute trends"
        )


@router.get("/learner/{learner_id}/history")
async def get_trend_history(
    learner_id: UUID,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    observer: CurrentObserver = None
):
    """
    Get historical trend data for a learner.
    
    PHASE-GATED: Returns {"status": "not_available"}
    """
    return PHASE_GATED_RESPONSE


@router.get("/learner/{learner_id}/patterns/{pattern_name}")
async def get_pattern_trends(
    learner_id: UUID,
    pattern_name: str,
    observer: CurrentObserver = None
):
    """
    Get trend data for a specific pattern type.
    
    PHASE-GATED: Returns {"status": "not_available"}
    """
    return PHASE_GATED_RESPONSE


@router.get("/overview")
async def get_observer_overview(observer: CurrentObserver):
    """
    Get trend overview for all learners.
    
    PHASE-GATED: Returns {"status": "not_available"}
    """
    return PHASE_GATED_RESPONSE
