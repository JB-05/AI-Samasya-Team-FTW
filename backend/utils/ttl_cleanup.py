# TTL (Time-To-Live) cleanup utilities
# Manages transient session data cleanup
# Ensures raw gameplay events are purged after session ends
# Implements data retention policies for privacy compliance

from datetime import datetime, timedelta
from typing import Dict, Any
import asyncio

from ..config import get_settings

# In-memory storage for transient session data
# This data is NEVER persisted to database
_transient_sessions: Dict[str, Dict[str, Any]] = {}
_session_timestamps: Dict[str, datetime] = {}


def store_transient_data(session_id: str, data: Dict[str, Any]) -> None:
    """
    Store transient session data in memory.
    This data will be automatically cleaned up after TTL expires.
    
    Args:
        session_id: Unique session identifier
        data: Transient gameplay data (NEVER persisted)
    """
    _transient_sessions[session_id] = data
    _session_timestamps[session_id] = datetime.utcnow()


def get_transient_data(session_id: str) -> Dict[str, Any] | None:
    """
    Retrieve transient session data.
    
    Args:
        session_id: Unique session identifier
        
    Returns:
        Session data if exists and not expired, None otherwise
    """
    if session_id not in _transient_sessions:
        return None
    
    # Check if session has expired
    settings = get_settings()
    timestamp = _session_timestamps.get(session_id)
    if timestamp:
        ttl = timedelta(hours=settings.session_ttl_hours)
        if datetime.utcnow() - timestamp > ttl:
            # Session expired, clean up
            cleanup_session(session_id)
            return None
    
    return _transient_sessions.get(session_id)


def cleanup_session(session_id: str) -> None:
    """
    Immediately clean up a session's transient data.
    Called when session completes or expires.
    
    Args:
        session_id: Session to clean up
    """
    _transient_sessions.pop(session_id, None)
    _session_timestamps.pop(session_id, None)


def cleanup_expired_sessions() -> int:
    """
    Clean up all expired sessions.
    Should be called periodically.
    
    Returns:
        Number of sessions cleaned up
    """
    settings = get_settings()
    ttl = timedelta(hours=settings.session_ttl_hours)
    now = datetime.utcnow()
    
    expired_sessions = [
        sid for sid, timestamp in _session_timestamps.items()
        if now - timestamp > ttl
    ]
    
    for session_id in expired_sessions:
        cleanup_session(session_id)
    
    return len(expired_sessions)


async def start_cleanup_scheduler(interval_minutes: int = 15) -> None:
    """
    Start background task to periodically clean up expired sessions.
    
    Args:
        interval_minutes: How often to run cleanup
    """
    while True:
        await asyncio.sleep(interval_minutes * 60)
        cleaned = cleanup_expired_sessions()
        if cleaned > 0:
            # TODO: Add proper logging
            print(f"Cleaned up {cleaned} expired sessions")


# TODO: Implement graceful shutdown handling
# TODO: Add metrics for cleanup operations
# TODO: Implement session data export before cleanup (patterns only)
