# =============================================================================
# DEPENDENCIES
# Shared FastAPI dependencies for all routes
# =============================================================================
#
# Two auth modes:
# 1. OBSERVER AUTH: Supabase JWT verification for parent/teacher app
# 2. LEARNER CODE: No auth, code-based access for child app (write-only)
#
# =============================================================================

from uuid import UUID
from typing import Annotated, Optional
from collections import defaultdict
from datetime import datetime, timedelta
from fastapi import Depends, HTTPException, status, Header
from pydantic import BaseModel
import jwt

from .config import get_settings_dev
from .db.supabase import get_supabase, get_supabase_admin


# =============================================================================
# RATE LIMITING (In-memory, simple implementation)
# =============================================================================

class RateLimiter:
    """Simple in-memory rate limiter for learner code access."""
    
    def __init__(self, max_requests: int = 10, window_seconds: int = 60):
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self.requests: dict[str, list[datetime]] = defaultdict(list)
    
    def is_allowed(self, key: str) -> bool:
        """Check if request is allowed under rate limit."""
        now = datetime.utcnow()
        window_start = now - timedelta(seconds=self.window_seconds)
        
        # Clean old requests
        self.requests[key] = [
            t for t in self.requests[key] 
            if t > window_start
        ]
        
        if len(self.requests[key]) >= self.max_requests:
            return False
        
        self.requests[key].append(now)
        return True


# Global rate limiter for learner code access
learner_code_limiter = RateLimiter(max_requests=10, window_seconds=60)


# =============================================================================
# OBSERVER CONTEXT (Parent/Teacher App)
# =============================================================================

class Observer(BaseModel):
    """Current authenticated observer context."""
    observer_id: UUID
    role: str  # "parent" or "teacher"


async def get_current_observer(
    authorization: Annotated[str | None, Header()] = None
) -> Observer:
    """
    Get the current authenticated observer from JWT.
    
    Flow:
    1. Extract JWT from Authorization: Bearer <token>
    2. Verify using Supabase JWT secret
    3. Get auth.users.id from token
    4. Map → observers.observer_id
    5. If observer row missing → auto-insert with default role
    6. Return Observer(observer_id, role)
    
    Raises:
        401 if token invalid or missing
    """
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authorization header missing",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    if not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authorization header format. Use: Bearer <token>",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    token = authorization[7:]
    
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token missing",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    settings = get_settings_dev()
    if not settings:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Server configuration error"
        )
    
    try:
        unverified_payload = jwt.decode(
            token,
            options={"verify_signature": False}
        )
        
        user_id = unverified_payload.get("sub")
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token: missing user ID",
                headers={"WWW-Authenticate": "Bearer"},
            )
        
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token expired",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except jwt.InvalidTokenError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid token: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    supabase = get_supabase()
    if not supabase:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Database connection error"
        )
    
    try:
        user_response = supabase.auth.get_user(token)
        
        if not user_response or not user_response.user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired token",
                headers={"WWW-Authenticate": "Bearer"},
            )
        
        user = user_response.user
        observer_id = UUID(user.id)
        
    except Exception as e:
        if "401" in str(e) or "Invalid" in str(e) or "expired" in str(e).lower():
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired token",
                headers={"WWW-Authenticate": "Bearer"},
            )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Authentication error: {str(e)}"
        )
    
    try:
        observer_result = supabase.table("observers").select("*").eq(
            "observer_id", str(observer_id)
        ).execute()
        
        if observer_result.data and len(observer_result.data) > 0:
            observer_data = observer_result.data[0]
            return Observer(
                observer_id=UUID(observer_data["observer_id"]),
                role=observer_data["role"]
            )
        
        supabase_admin = get_supabase_admin()
        if not supabase_admin:
            return Observer(
                observer_id=observer_id,
                role="parent"
            )
        
        new_observer = {
            "observer_id": str(observer_id),
            "role": "parent"
        }
        
        insert_result = supabase_admin.table("observers").insert(new_observer).execute()
        
        if insert_result.data and len(insert_result.data) > 0:
            return Observer(
                observer_id=observer_id,
                role="parent"
            )
        
        return Observer(
            observer_id=observer_id,
            role="parent"
        )
        
    except Exception:
        return Observer(
            observer_id=observer_id,
            role="parent"
        )


# Type alias for cleaner route signatures
CurrentObserver = Annotated[Observer, Depends(get_current_observer)]


# =============================================================================
# LEARNER CODE CONTEXT (Child App)
# =============================================================================

class LearnerContext(BaseModel):
    """Learner context resolved from learner_code."""
    learner_id: UUID
    # NOTE: observer_id is NOT exposed to child app


async def get_learner_by_code(learner_code: str) -> LearnerContext:
    """
    Get learner context from learner_code.
    
    IMPORTANT:
    - No authentication required
    - Rate limited (10 requests per minute per code)
    - Grants WRITE-ONLY session access
    - Cannot read patterns, reports, or other data
    
    Args:
        learner_code: The 8-character access code
        
    Returns:
        LearnerContext with learner_id (internal use)
        
    Raises:
        429 if rate limited
        404 if code not found
    """
    # Rate limiting
    if not learner_code_limiter.is_allowed(learner_code):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many requests. Please wait before trying again."
        )
    
    supabase = get_supabase_admin() or get_supabase()
    
    if not supabase:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Service unavailable"
        )
    
    try:
        # Look up learner by code
        result = supabase.table("learners").select("learner_id").eq(
            "learner_code", learner_code.upper()
        ).execute()
        
        if not result.data or len(result.data) == 0:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Invalid code"
            )
        
        return LearnerContext(
            learner_id=UUID(result.data[0]["learner_id"])
        )
        
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Service error"
        )


# =============================================================================
# OPTIONAL AUTH (for public endpoints that benefit from auth context)
# =============================================================================

async def get_optional_observer(
    authorization: Annotated[str | None, Header()] = None
) -> Optional[Observer]:
    """
    Get observer if authenticated, None otherwise.
    Use for endpoints that work with or without auth.
    """
    if not authorization:
        return None
    
    try:
        return await get_current_observer(authorization)
    except HTTPException:
        return None


OptionalObserver = Annotated[Optional[Observer], Depends(get_optional_observer)]
