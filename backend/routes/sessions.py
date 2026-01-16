# =============================================================================
# SESSION ROUTES
# Minimal intelligence loop: start → events → complete → pattern
# =============================================================================

from uuid import UUID, uuid4
from fastapi import APIRouter, HTTPException, status

from ..dependencies import CurrentObserver
from ..db.supabase import get_supabase
from ..schemas.session import (
    SessionStart,
    SessionStartResponse,
    EventLog,
    SessionCompleteResponse,
    SessionStatus
)
from ..services.event_store import event_store
from ..services.feature_engine import extract_focus_tap_features
from ..services.pattern_engine import infer_pattern

router = APIRouter(prefix="/sessions", tags=["sessions"])


@router.post("/start", response_model=SessionStartResponse)
async def start_session(
    request: SessionStart,
    observer: CurrentObserver
):
    """
    Start a new game session.
    
    1. Verify learner belongs to observer
    2. Create session in database (metadata only)
    3. Create in-memory event store
    4. Return session_id for event logging
    """
    supabase = get_supabase()
    if not supabase:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Database connection error"
        )
    
    # Verify learner belongs to this observer
    learner_check = supabase.table("learners").select("learner_id").eq(
        "learner_id", str(request.learner_id)
    ).eq(
        "observer_id", str(observer.observer_id)
    ).execute()
    
    if not learner_check.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Learner not found or does not belong to you"
        )
    
    # Create session in database (metadata only)
    session_id = uuid4()
    
    session_data = {
        "session_id": str(session_id),
        "learner_id": str(request.learner_id),
        "game_set": request.game_type
    }
    
    result = supabase.table("sessions").insert(session_data).execute()
    
    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create session"
        )
    
    # Create in-memory event store for this session
    event_store.create_session(
        session_id=session_id,
        learner_id=request.learner_id,
        observer_id=observer.observer_id,
        game_type=request.game_type
    )
    
    return SessionStartResponse(
        session_id=session_id,
        learner_id=request.learner_id,
        game_type=request.game_type,
        message="Session started. Send events to /sessions/{id}/events"
    )


@router.post("/{session_id}/events")
async def log_events(
    session_id: UUID,
    request: EventLog,
    observer: CurrentObserver
):
    """
    Log gameplay events (tap events).
    
    Events are stored IN MEMORY ONLY.
    They are NEVER persisted to the database.
    """
    session = event_store.get_session(session_id)
    
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session not found or expired"
        )
    
    # Verify observer owns this session
    if session.observer_id != observer.observer_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not your session"
        )
    
    if session.is_complete:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Session already completed"
        )
    
    # Add events to in-memory store
    events_data = [e.model_dump() for e in request.events]
    event_store.add_events(session_id, events_data)
    
    return {
        "status": "ok",
        "events_logged": len(request.events),
        "total_events": event_store.get_event_count(session_id)
    }


@router.post("/{session_id}/complete", response_model=SessionCompleteResponse)
async def complete_session(
    session_id: UUID,
    observer: CurrentObserver
):
    """
    Complete a session and extract patterns.
    
    Flow:
    1. Get events from memory
    2. Extract features
    3. Infer pattern
    4. Save pattern snapshot to database
    5. CLEAR events from memory (privacy)
    6. Return result
    """
    session = event_store.get_session(session_id)
    
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session not found or expired"
        )
    
    if session.observer_id != observer.observer_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not your session"
        )
    
    if session.is_complete:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Session already completed"
        )
    
    # Mark session as complete and get data
    session_data = event_store.complete_session(session_id)
    total_events = len(session_data.events)
    
    pattern_name = None
    
    # Extract features and infer pattern (if enough events)
    if total_events >= 3:
        features = extract_focus_tap_features(session_data.events)
        
        if features:
            pattern = infer_pattern(features)
            
            if pattern:
                pattern_name = pattern.pattern_name
                
                # Save pattern snapshot to database
                supabase = get_supabase()
                if supabase:
                    snapshot_data = {
                        "session_id": str(session_id),
                        "learner_id": str(session.learner_id),
                        "pattern_name": pattern.pattern_name,
                        "confidence": pattern.confidence,
                        "learning_impact": pattern.learning_impact,
                        "support_focus": pattern.support_focus
                    }
                    
                    supabase.table("pattern_snapshots").insert(snapshot_data).execute()
    
    # ==========================================================================
    # CRITICAL: Clear raw events from memory
    # This ensures no raw behavior data is retained
    # ==========================================================================
    event_store.clear_session(session_id)
    
    return SessionCompleteResponse(
        session_id=session_id,
        total_events=total_events,
        pattern_detected=pattern_name,
        message="Session completed. Raw events cleared."
    )


@router.get("/{session_id}/status", response_model=SessionStatus)
async def get_session_status(
    session_id: UUID,
    observer: CurrentObserver
):
    """Get current session status."""
    session = event_store.get_session(session_id)
    
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session not found or expired"
        )
    
    if session.observer_id != observer.observer_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not your session"
        )
    
    return SessionStatus(
        session_id=session.session_id,
        learner_id=session.learner_id,
        game_type=session.game_type,
        event_count=len(session.events),
        started_at=session.started_at,
        is_complete=session.is_complete
    )
