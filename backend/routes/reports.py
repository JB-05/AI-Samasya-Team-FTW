# =============================================================================
# REPORT ROUTES
# Retrieve pattern snapshots and generate reports
# =============================================================================

from uuid import UUID
from typing import List, Optional
from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel

from ..dependencies import CurrentObserver
from ..db.supabase import get_supabase
from ..utils.constants import DISCLAIMER_SHORT

router = APIRouter(prefix="/reports", tags=["reports"])


class PatternSnapshot(BaseModel):
    """A single pattern snapshot."""
    snapshot_id: UUID
    session_id: UUID
    pattern_name: str
    confidence: str
    learning_impact: str
    support_focus: str
    created_at: str


class SessionReport(BaseModel):
    """Report for a single session."""
    session_id: UUID
    learner_id: UUID
    game_type: str
    patterns: List[PatternSnapshot]
    disclaimer: str


class LearnerReport(BaseModel):
    """All patterns for a learner."""
    learner_id: UUID
    alias: str
    total_sessions: int
    patterns: List[PatternSnapshot]
    disclaimer: str


@router.get("/session/{session_id}", response_model=SessionReport)
async def get_session_report(
    session_id: UUID,
    observer: CurrentObserver
):
    """
    Get the pattern report for a specific session.
    
    Returns all detected patterns with explanations.
    """
    supabase = get_supabase()
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
    
    # Get pattern snapshots for this session
    patterns_result = supabase.table("pattern_snapshots").select("*").eq(
        "session_id", str(session_id)
    ).execute()
    
    patterns = [
        PatternSnapshot(
            snapshot_id=UUID(p["snapshot_id"]),
            session_id=UUID(p["session_id"]),
            pattern_name=p["pattern_name"],
            confidence=p["confidence"],
            learning_impact=p["learning_impact"],
            support_focus=p["support_focus"],
            created_at=p["created_at"]
        )
        for p in (patterns_result.data or [])
    ]
    
    return SessionReport(
        session_id=session_id,
        learner_id=UUID(learner_id),
        game_type=session["game_set"],
        patterns=patterns,
        disclaimer=DISCLAIMER_SHORT
    )


@router.get("/learner/{learner_id}", response_model=LearnerReport)
async def get_learner_report(
    learner_id: UUID,
    observer: CurrentObserver
):
    """
    Get all patterns for a learner across all sessions.
    """
    supabase = get_supabase()
    if not supabase:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Database connection error"
        )
    
    # Get learner and verify ownership
    learner_result = supabase.table("learners").select("*").eq(
        "learner_id", str(learner_id)
    ).eq(
        "observer_id", str(observer.observer_id)
    ).execute()
    
    if not learner_result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Learner not found or does not belong to you"
        )
    
    learner = learner_result.data[0]
    
    # Count sessions
    sessions_result = supabase.table("sessions").select(
        "session_id", count="exact"
    ).eq("learner_id", str(learner_id)).execute()
    
    total_sessions = sessions_result.count or 0
    
    # Get all pattern snapshots for this learner
    patterns_result = supabase.table("pattern_snapshots").select("*").eq(
        "learner_id", str(learner_id)
    ).order("created_at", desc=True).execute()
    
    patterns = [
        PatternSnapshot(
            snapshot_id=UUID(p["snapshot_id"]),
            session_id=UUID(p["session_id"]),
            pattern_name=p["pattern_name"],
            confidence=p["confidence"],
            learning_impact=p["learning_impact"],
            support_focus=p["support_focus"],
            created_at=p["created_at"]
        )
        for p in (patterns_result.data or [])
    ]
    
    return LearnerReport(
        learner_id=learner_id,
        alias=learner["alias"],
        total_sessions=total_sessions,
        patterns=patterns,
        disclaimer=DISCLAIMER_SHORT
    )
