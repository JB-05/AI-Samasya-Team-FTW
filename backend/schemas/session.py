# Session schemas for the minimal intelligence loop
# Separate schemas for Observer (parent/teacher) and Child app
from pydantic import BaseModel, Field
from typing import Optional, List
from uuid import UUID
from datetime import datetime


# =============================================================================
# OBSERVER (Parent/Teacher App) Session Schemas
# Requires authentication
# =============================================================================

class SessionStart(BaseModel):
    """Request to start a new game session (Observer app)."""
    learner_id: UUID
    game_type: str = "focus_tap"


class SessionStartResponse(BaseModel):
    """Response after starting a session (Observer app)."""
    session_id: UUID


class TapEvent(BaseModel):
    """A single tap event during gameplay."""
    timestamp_ms: int          # Client timestamp in milliseconds
    target_appeared_ms: int    # When target appeared
    was_hit: bool              # Did user tap the target?
    
    @property
    def reaction_time_ms(self) -> Optional[int]:
        """Calculate reaction time if hit."""
        if self.was_hit:
            return self.timestamp_ms - self.target_appeared_ms
        return None


class EventLog(BaseModel):
    """Log a batch of events (or single event)."""
    events: List[TapEvent]


class SessionCompleteResponse(BaseModel):
    """Response after completing a session.
    
    SIMPLIFIED: Returns only status, no metrics or patterns.
    Child app should not receive analysis results.
    """
    status: str = "ok"


# =============================================================================
# CHILD APP Session Schemas
# NO authentication - uses learner_code only
# =============================================================================

class ChildSessionStart(BaseModel):
    """
    Request to start a session from child app.
    
    IMPORTANT:
    - Uses learner_code, NOT learner_id
    - learner_code grants WRITE-ONLY access
    - No authentication required
    """
    learner_code: str = Field(
        ...,
        min_length=8,
        max_length=10,
        description="Unique learner access code"
    )
    game_type: str = "focus_tap"


class ChildSessionStartResponse(BaseModel):
    """
    Response after starting a session from child app.
    
    MINIMAL: Returns only session_id.
    Does NOT expose learner_id to child app.
    """
    session_id: UUID


class ChildSessionCompleteResponse(BaseModel):
    """
    Response after completing a session from child app.
    
    MINIMAL: Returns only status.
    No metrics, patterns, or analysis returned to child.
    """
    status: str = "ok"


# =============================================================================
# Internal/Status Schemas (Observer only)
# =============================================================================

class SessionStatus(BaseModel):
    """Current session status (Observer app only)."""
    session_id: UUID
    learner_id: UUID
    game_type: str
    event_count: int
    started_at: datetime
    is_complete: bool
