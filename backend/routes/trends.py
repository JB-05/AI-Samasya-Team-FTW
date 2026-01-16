# Routes for longitudinal trend summaries
# Aggregates pattern data across multiple sessions
#
# NOTE: Trends are derived from pattern snapshots only
# Raw gameplay data is NEVER used for trends

from fastapi import APIRouter, HTTPException, status
from typing import List, Optional
from uuid import UUID
from datetime import date, datetime

from ..dependencies import CurrentObserver
from ..utils.constants import DISCLAIMER_SHORT

router = APIRouter(prefix="/trends", tags=["trends"])


@router.get("/learner/{learner_id}")
async def get_learner_trends(
    learner_id: UUID,
    period: str = "month",  # week, month, quarter, year
    observer: CurrentObserver = None
):
    """
    Get trend summary for a learner over a specified period.
    
    Aggregates pattern data across sessions to show
    learning trajectory over time.
    """
    # TODO: Implement with actual data
    return {
        "learner_id": str(learner_id),
        "period": period,
        "trends": [],
        "session_count": 0,
        "message": "Trend analysis coming in Phase 2",
        "disclaimer": DISCLAIMER_SHORT
    }


@router.get("/learner/{learner_id}/history")
async def get_trend_history(
    learner_id: UUID,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    observer: CurrentObserver = None
):
    """
    Get historical trend data for a learner.
    
    Returns trend snapshots over time to visualize progress.
    """
    return {
        "learner_id": str(learner_id),
        "start_date": str(start_date) if start_date else None,
        "end_date": str(end_date) if end_date else None,
        "history": [],
        "message": "Trend history coming in Phase 2",
        "disclaimer": DISCLAIMER_SHORT
    }


@router.get("/learner/{learner_id}/patterns/{pattern_name}")
async def get_pattern_trends(
    learner_id: UUID,
    pattern_name: str,
    observer: CurrentObserver = None
):
    """
    Get trend data for a specific pattern type.
    
    Shows how a particular pattern has evolved over time.
    """
    return {
        "learner_id": str(learner_id),
        "pattern_name": pattern_name,
        "trend_data": [],
        "message": "Pattern trends coming in Phase 2",
        "disclaimer": DISCLAIMER_SHORT
    }


@router.get("/overview")
async def get_observer_overview(observer: CurrentObserver):
    """
    Get trend overview for all learners under the observer.
    
    Provides a dashboard view of all learners' progress.
    """
    return {
        "observer_id": str(observer.observer_id),
        "learner_summaries": [],
        "total_learners": 0,
        "total_sessions": 0,
        "generated_at": datetime.utcnow().isoformat(),
        "message": "Observer overview coming in Phase 2",
        "disclaimer": DISCLAIMER_SHORT
    }
