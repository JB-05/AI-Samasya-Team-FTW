# =============================================================================
# DEPENDENCIES
# Shared FastAPI dependencies for all routes
# =============================================================================
#
# REAL AUTH: Supabase JWT verification
#
# =============================================================================

from uuid import UUID
from typing import Annotated, Optional
from fastapi import Depends, HTTPException, status, Header
from pydantic import BaseModel
import jwt

from .config import get_settings_dev
from .db.supabase import get_supabase, get_supabase_admin


# =============================================================================
# OBSERVER CONTEXT
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
    # ==========================================================================
    # Step 1: Extract JWT from Authorization header
    # ==========================================================================
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
    
    token = authorization[7:]  # Remove "Bearer " prefix
    
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token missing",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # ==========================================================================
    # Step 2: Verify JWT with Supabase
    # ==========================================================================
    settings = get_settings_dev()
    if not settings:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Server configuration error"
        )
    
    try:
        # Supabase JWT uses HS256 with the JWT secret
        # The JWT secret is derived from the project's JWT secret in Supabase settings
        # For anon key verification, we decode without verification and use Supabase to validate
        
        # Decode without verification first to get the user ID
        # Then use Supabase client to verify the session is valid
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
    
    # ==========================================================================
    # Step 3: Verify session with Supabase and get/create observer
    # ==========================================================================
    supabase = get_supabase()
    if not supabase:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Database connection error"
        )
    
    try:
        # Verify the token is valid by getting the user
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
    
    # ==========================================================================
    # Step 4: Get or create observer record
    # ==========================================================================
    try:
        # Try to get existing observer
        observer_result = supabase.table("observers").select("*").eq(
            "observer_id", str(observer_id)
        ).execute()
        
        if observer_result.data and len(observer_result.data) > 0:
            # Observer exists
            observer_data = observer_result.data[0]
            return Observer(
                observer_id=UUID(observer_data["observer_id"]),
                role=observer_data["role"]
            )
        
        # ==========================================================================
        # Step 5: Auto-insert observer if missing (use admin client to bypass RLS)
        # ==========================================================================
        supabase_admin = get_supabase_admin()
        if not supabase_admin:
            # Fallback: return observer without DB record (will fail on FK constraints)
            return Observer(
                observer_id=observer_id,
                role="parent"
            )
        
        # Default role is "parent" - can be changed later
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
        
        # If insert failed but no error, return with default role
        return Observer(
            observer_id=observer_id,
            role="parent"
        )
        
    except Exception as e:
        # If we can't access the observers table, still return the observer
        # This handles cases where the table doesn't exist yet
        return Observer(
            observer_id=observer_id,
            role="parent"
        )


# Type alias for cleaner route signatures
CurrentObserver = Annotated[Observer, Depends(get_current_observer)]


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
