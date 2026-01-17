# =============================================================================
# REPORT ROUTES
# Retrieve pattern snapshots and generate reports
#
# UI-ALIGNED: Returns language-only outputs
# - Pattern titles (text)
# - Descriptions (text)
# - Support suggestions (text)
# - Disclaimer
#
# EXPLICITLY REMOVED:
# - Numeric confidence values
# - Raw metrics
# - Thresholds
# =============================================================================

from uuid import UUID
from typing import List
from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel

from ..dependencies import CurrentObserver
from ..db.supabase import get_supabase, get_supabase_admin
from ..utils.constants import DISCLAIMER_SHORT

router = APIRouter(prefix="/reports", tags=["reports"])


# =============================================================================
# RESPONSE SCHEMAS (Language-Only)
# =============================================================================

class PatternSummary(BaseModel):
    """
    A pattern summary - language only, no metrics.
    
    REMOVED from previous version:
    - confidence (numeric)
    - any numeric values
    """
    pattern_name: str
    learning_impact: str
    support_focus: str


class SessionReport(BaseModel):
    """
    Report for a single session.
    
    Returns:
    - Pattern titles
    - Descriptions (learning_impact)
    - Support suggestions (support_focus)
    - Disclaimer
    
    Does NOT return:
    - Numeric confidence values
    - Raw metrics
    - Thresholds
    - Game names
    """
    session_id: UUID
    patterns: List[PatternSummary]
    disclaimer: str


class LearnerReport(BaseModel):
    """
    All patterns for a learner.
    
    Simplified: No session counts or timestamps.
    """
    learner_id: UUID
    alias: str
    patterns: List[PatternSummary]
    disclaimer: str


# =============================================================================
# ROUTES
# =============================================================================

@router.get("/session/{session_id}", response_model=SessionReport)
async def get_session_report(session_id: UUID, observer: CurrentObserver):
    """
    Get the pattern report for a specific session.
    
    Returns language-only pattern summaries.
    No numeric confidence values or raw metrics.
    """
    supabase = get_supabase_admin() or get_supabase()
    if not supabase:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Database connection error"
        )
    
    # Get session and verify ownership
    session_result = supabase.table("sessions").select(
        "session_id, learner_id, game_set"
    ).eq("session_id", str(session_id)).execute()
    
    if not session_result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session not found"
        )
    
    session = session_result.data[0]
    learner_id = session["learner_id"]
    
    # Verify learner belongs to observer
    learner_check = supabase.table("learners").select("learner_id").eq(
        "learner_id", learner_id
    ).eq(
        "observer_id", str(observer.observer_id)
    ).execute()
    
    if not learner_check.data:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not your learner"
        )
    
    # Get pattern snapshots - select only language fields
    patterns_result = supabase.table("pattern_snapshots").select(
        "pattern_name, learning_impact, support_focus"
    ).eq("session_id", str(session_id)).execute()
    
    patterns = [
        PatternSummary(
            pattern_name=p["pattern_name"],
            learning_impact=p["learning_impact"],
            support_focus=p["support_focus"]
        )
        for p in (patterns_result.data or [])
    ]
    
    return SessionReport(
        session_id=session_id,
        patterns=patterns,
        disclaimer=DISCLAIMER_SHORT
    )


@router.get("/learner/{learner_id}", response_model=LearnerReport)
async def get_learner_report(learner_id: UUID, observer: CurrentObserver):
    """
    Get all patterns for a learner across all sessions.
    
    Returns language-only pattern summaries.
    No session counts, timestamps, or numeric values.
    """
    supabase = get_supabase_admin() or get_supabase()
    if not supabase:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Database connection error"
        )
    
    # Get learner and verify ownership
    learner_result = supabase.table("learners").select(
        "learner_id, alias"
    ).eq(
        "learner_id", str(learner_id)
    ).eq(
        "observer_id", str(observer.observer_id)
    ).execute()
    
    if not learner_result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Learner not found"
        )
    
    learner = learner_result.data[0]
    
    # Get all pattern snapshots - select only language fields
    patterns_result = supabase.table("pattern_snapshots").select(
        "pattern_name, learning_impact, support_focus"
    ).eq(
        "learner_id", str(learner_id)
    ).order("created_at", desc=True).execute()
    
    patterns = [
        PatternSummary(
            pattern_name=p["pattern_name"],
            learning_impact=p["learning_impact"],
            support_focus=p["support_focus"]
        )
        for p in (patterns_result.data or [])
    ]
    
    return LearnerReport(
        learner_id=learner_id,
        alias=learner["alias"],
        patterns=patterns,
        disclaimer=DISCLAIMER_SHORT
    )


@router.get("/ai/{report_id}")
async def get_ai_report(report_id: UUID, observer: CurrentObserver):
    """
    Get an AI-generated report from the reports table.
    
    Returns the narrative report content and validation status.
    """
    supabase = get_supabase_admin() or get_supabase()
    if not supabase:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Database connection error"
        )
    
    # Get report
    result = supabase.table("reports").select("*").eq(
        "report_id", str(report_id)
    ).execute()
    
    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Report not found"
        )
    
    report = result.data[0]
    
    # Verify learner belongs to observer
    learner_check = supabase.table("learners").select("learner_id").eq(
        "learner_id", report["learner_id"]
    ).eq(
        "observer_id", str(observer.observer_id)
    ).execute()
    
    if not learner_check.data:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Report not accessible"
        )
    
    return {
        "report_id": report["report_id"],
        "content": report["content"],
        "validation_status": report["validation_status"],
        "generation_method": report["generation_method"],
        "disclaimer": DISCLAIMER_SHORT
    }


@router.get("/learner/{learner_id}/latest")
async def get_latest_report_id(learner_id: UUID, observer: CurrentObserver):
    """
    Get the latest AI-generated report_id for a learner.
    
    Returns the most recent approved or rewritten report for the learner.
    Used to navigate to the AI-generated report view.
    """
    supabase = get_supabase_admin() or get_supabase()
    if not supabase:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Database connection error"
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
    
    # Get latest approved/rewritten report
    result = supabase.table("reports").select("report_id").eq(
        "learner_id", str(learner_id)
    ).in_(
        "validation_status", ["approved", "rewritten"]
    ).order("created_at", desc=True).limit(1).execute()
    
    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No report found for this learner"
        )
    
    return {
        "report_id": result.data[0]["report_id"]
    }
