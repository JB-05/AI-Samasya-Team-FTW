# =============================================================================
# SESSION ROUTES
# Two modes:
# 1. Observer (Parent/Teacher) - authenticated, full access
# 2. Child App - learner_code only, write-only access
# =============================================================================

from uuid import UUID, uuid4
from fastapi import APIRouter, HTTPException, status

from ..dependencies import CurrentObserver, get_learner_by_code
from ..db.supabase import get_supabase, get_supabase_admin
from ..schemas.session import (
    SessionStart,
    SessionStartResponse,
    EventLog,
    SessionCompleteResponse,
    SessionStatus,
    ChildSessionStart,
    ChildSessionStartResponse,
    ChildSessionCompleteResponse
)
from ..services.event_store import event_store
from ..services.feature_engine import extract_focus_tap_features
from ..services.pattern_engine import infer_pattern

router = APIRouter(prefix="/sessions", tags=["sessions"])


# =============================================================================
# CHILD APP ROUTES (No authentication, learner_code only)
# =============================================================================

@router.post("/child/start", response_model=ChildSessionStartResponse)
async def child_start_session(request: ChildSessionStart):
    """
    Start a new game session from child app.
    
    NO AUTHENTICATION REQUIRED.
    Uses learner_code for write-only access.
    Rate limited: 10 requests per minute per code.
    
    Input:
        {"learner_code": "ABC12345", "game_type": "focus_tap"}
    
    Output:
        {"session_id": "uuid"}
    
    Does NOT expose learner_id to child app.
    """
    # Get learner context from code (rate limited)
    learner_context = await get_learner_by_code(request.learner_code)
    
    supabase = get_supabase_admin() or get_supabase()
    if not supabase:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Service unavailable"
        )
    
    # Create session in database
    session_id = uuid4()
    
    session_data = {
        "session_id": str(session_id),
        "learner_id": str(learner_context.learner_id),
        "game_set": request.game_type
    }
    
    result = supabase.table("sessions").insert(session_data).execute()
    
    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to start session"
        )
    
    # Create in-memory event store (observer_id not needed for child app)
    event_store.create_session(
        session_id=session_id,
        learner_id=learner_context.learner_id,
        observer_id=None,  # Child app doesn't have observer context
        game_type=request.game_type
    )
    
    return ChildSessionStartResponse(session_id=session_id)


@router.post("/child/{session_id}/events")
async def child_log_events(session_id: UUID, request: EventLog):
    """
    Log gameplay events from child app.
    
    NO AUTHENTICATION REQUIRED.
    Events are stored IN MEMORY ONLY.
    They are NEVER persisted to the database.
    
    Returns only: {"status": "ok"}
    """
    session = event_store.get_session(session_id)
    
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session not found"
        )
    
    if session.is_complete:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Session already completed"
        )
    
    # Add events to in-memory store
    events_data = [e.model_dump() for e in request.events]
    event_store.add_events(session_id, events_data)
    
    return {"status": "ok"}


@router.post("/child/{session_id}/complete", response_model=ChildSessionCompleteResponse)
async def child_complete_session(session_id: UUID):
    """
    Complete a session from child app.
    
    NO AUTHENTICATION REQUIRED.
    
    Flow:
    1. Get events from memory
    2. Extract features
    3. Infer pattern
    4. Save pattern snapshot to database
    5. CLEAR events from memory (privacy)
    6. Return ONLY: {"status": "ok"}
    
    No metrics, patterns, or analysis returned to child.
    """
    session = event_store.get_session(session_id)
    
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session not found"
        )
    
    if session.is_complete:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Session already completed"
        )
    
    # Mark session as complete and get data
    session_data = event_store.complete_session(session_id)
    total_events = len(session_data.events)
    
    # Extract features and infer pattern (if enough events)
    if total_events >= 3:
        features = extract_focus_tap_features(session_data.events)
        
        if features:
            pattern = infer_pattern(features)
            
            if pattern:
                # Save pattern snapshot to database
                supabase = get_supabase_admin() or get_supabase()
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
    
    # CRITICAL: Clear raw events from memory
    event_store.clear_session(session_id)
    
    # Return ONLY status - no metrics or patterns to child
    return ChildSessionCompleteResponse(status="ok")


# =============================================================================
# OBSERVER (Parent/Teacher) ROUTES - Authenticated
# =============================================================================

@router.post("/start", response_model=SessionStartResponse)
async def start_session(request: SessionStart, observer: CurrentObserver):
    """
    Start a new game session (Observer/Parent app).
    
    REQUIRES: Valid authentication token
    
    Input:
        {"learner_id": "uuid", "game_type": "focus_tap"}
    
    Output:
        {"session_id": "uuid"}
    """
    supabase = get_supabase_admin() or get_supabase()
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
            detail="Learner not found"
        )
    
    # Create session in database
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
    
    return SessionStartResponse(session_id=session_id)


@router.post("/{session_id}/events")
async def log_events(session_id: UUID, request: EventLog, observer: CurrentObserver):
    """
    Log gameplay events (Observer/Parent app).
    
    REQUIRES: Valid authentication token
    
    Events are stored IN MEMORY ONLY.
    Returns only: {"status": "ok"}
    """
    session = event_store.get_session(session_id)
    
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session not found or expired"
        )
    
    # Verify observer owns this session (if observer_id is set)
    if session.observer_id and session.observer_id != observer.observer_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not your session"
        )
    
    if session.is_complete:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Session already completed"
        )
    
    events_data = [e.model_dump() for e in request.events]
    event_store.add_events(session_id, events_data)
    
    return {"status": "ok"}


@router.post("/{session_id}/complete", response_model=SessionCompleteResponse)
async def complete_session(session_id: UUID, observer: CurrentObserver):
    """
    Complete a session (Observer/Parent app).
    
    REQUIRES: Valid authentication token
    
    Flow:
    1. Get events from memory
    2. Extract features
    3. Infer pattern
    4. Save pattern snapshot to database
    5. CLEAR events from memory (privacy)
    6. Return: {"status": "ok"}
    
    SIMPLIFIED: Returns only status, no metrics or patterns.
    Observer views patterns via /reports endpoint.
    """
    session = event_store.get_session(session_id)
    
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session not found or expired"
        )
    
    if session.observer_id and session.observer_id != observer.observer_id:
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
    
    # Extract features and infer pattern
    if total_events >= 3:
        features = extract_focus_tap_features(session_data.events)
        
        if features:
            pattern = infer_pattern(features)
            
            if pattern:
                supabase = get_supabase_admin() or get_supabase()
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
    
    # CRITICAL: Clear raw events from memory
    event_store.clear_session(session_id)
    
    # Return only status
    return SessionCompleteResponse(status="ok")


@router.get("/{session_id}/status", response_model=SessionStatus)
async def get_session_status(session_id: UUID, observer: CurrentObserver):
    """
    Get current session status (Observer only).
    
    REQUIRES: Valid authentication token
    """
    session = event_store.get_session(session_id)
    
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session not found or expired"
        )
    
    if session.observer_id and session.observer_id != observer.observer_id:
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
