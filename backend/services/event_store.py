# =============================================================================
# IN-MEMORY EVENT STORE
# Transient storage for gameplay events — NEVER persisted to database
# =============================================================================
#
# Privacy Design:
# - Events are held in memory only during active session
# - Cleared immediately after pattern extraction
# - No raw behavior data is ever written to disk
#
# =============================================================================

from typing import Dict, List, Optional
from uuid import UUID
from datetime import datetime
from dataclasses import dataclass, field


@dataclass
class SessionData:
    """In-memory session data."""
    session_id: UUID
    learner_id: UUID
    observer_id: UUID
    game_type: str
    events: List[dict] = field(default_factory=list)
    started_at: datetime = field(default_factory=datetime.utcnow)
    is_complete: bool = False


class EventStore:
    """
    Transient in-memory store for gameplay events.
    
    CRITICAL: This data is NEVER persisted.
    Events are extracted into patterns, then discarded.
    """
    
    def __init__(self):
        self._sessions: Dict[UUID, SessionData] = {}
    
    def create_session(
        self,
        session_id: UUID,
        learner_id: UUID,
        observer_id: UUID,
        game_type: str
    ) -> SessionData:
        """Create a new session in memory."""
        session = SessionData(
            session_id=session_id,
            learner_id=learner_id,
            observer_id=observer_id,
            game_type=game_type
        )
        self._sessions[session_id] = session
        return session
    
    def get_session(self, session_id: UUID) -> Optional[SessionData]:
        """Get session data if it exists."""
        return self._sessions.get(session_id)
    
    def add_events(self, session_id: UUID, events: List[dict]) -> bool:
        """Add events to a session."""
        session = self._sessions.get(session_id)
        if not session or session.is_complete:
            return False
        session.events.extend(events)
        return True
    
    def complete_session(self, session_id: UUID) -> Optional[SessionData]:
        """Mark session as complete and return data for processing."""
        session = self._sessions.get(session_id)
        if not session:
            return None
        session.is_complete = True
        return session
    
    def clear_session(self, session_id: UUID) -> None:
        """
        CRITICAL: Clear session data after pattern extraction.
        This ensures raw events are never retained.
        """
        if session_id in self._sessions:
            del self._sessions[session_id]
    
    def get_event_count(self, session_id: UUID) -> int:
        """Get number of events in a session."""
        session = self._sessions.get(session_id)
        return len(session.events) if session else 0


# Global singleton — events live here during gameplay
event_store = EventStore()
