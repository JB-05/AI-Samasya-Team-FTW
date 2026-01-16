# Session schemas for the minimal intelligence loop
from pydantic import BaseModel
from typing import Optional, List
from uuid import UUID
from datetime import datetime


class SessionStart(BaseModel):
    """Request to start a new game session."""
    learner_id: UUID
    game_type: str = "focus_tap"  # Only one game for now


class SessionStartResponse(BaseModel):
    """Response after starting a session."""
    session_id: UUID
    learner_id: UUID
    game_type: str
    message: str


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


class SessionComplete(BaseModel):
    """Request to complete a session."""
    # No additional data needed - events already logged


class SessionCompleteResponse(BaseModel):
    """Response after completing a session."""
    session_id: UUID
    total_events: int
    pattern_detected: Optional[str]
    message: str


class SessionStatus(BaseModel):
    """Current session status."""
    session_id: UUID
    learner_id: UUID
    game_type: str
    event_count: int
    started_at: datetime
    is_complete: bool
