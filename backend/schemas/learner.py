# Pydantic schemas for learner data
# Defines models for learner aliases only
# Contains NO fields for child identity or demographics

from datetime import datetime
from typing import Optional
from uuid import UUID
from pydantic import BaseModel, Field, field_validator


# ============== Learner Schemas ==============
# NOTE: Learners are alias-based references ONLY
# NO identifying information about children is stored


class LearnerCreate(BaseModel):
    """
    Schema for creating a new learner alias.
    
    PRIVACY: Only contains an adult-defined alias.
    No real names, demographics, or identifying data.
    
    Client NEVER sends observer_id - it comes from auth context.
    """
    alias: str = Field(
        ...,
        min_length=2,
        max_length=32,
        description="Adult-defined alias for the learner (e.g., 'Learner A')"
    )
    
    @field_validator('alias')
    @classmethod
    def sanitize_alias(cls, v: str) -> str:
        """Trim whitespace and validate non-empty."""
        sanitized = v.strip()
        if len(sanitized) < 2:
            raise ValueError('Alias must be at least 2 characters after trimming whitespace')
        if len(sanitized) > 32:
            raise ValueError('Alias must be at most 32 characters')
        return sanitized


class LearnerRead(BaseModel):
    """
    Schema for learner data in responses.
    
    UI-Aligned: Returns minimal fields needed for display.
    Includes learner_code for context screen display.
    Does NOT include:
    - session counts
    - last activity timestamps
    - derived stats
    """
    learner_id: UUID
    alias: str
    learner_code: str  # Included for context screen display
    created_at: datetime
    
    class Config:
        from_attributes = True


class LearnerCreateResponse(BaseModel):
    """
    Response after creating a new learner.
    
    IMPORTANT: learner_code is returned ONCE here.
    Parent/teacher must save it - it is not shown again.
    """
    learner_id: UUID
    alias: str
    learner_code: str  # Shown ONCE on creation
    created_at: datetime
    message: str = "Save this code - it will not be shown again."
    
    class Config:
        from_attributes = True


class LearnerUpdate(BaseModel):
    """Schema for updating a learner alias."""
    alias: Optional[str] = Field(
        None,
        min_length=2,
        max_length=32
    )
    
    @field_validator('alias')
    @classmethod
    def sanitize_alias(cls, v: Optional[str]) -> Optional[str]:
        """Trim whitespace and validate non-empty."""
        if v is None:
            return None
        sanitized = v.strip()
        if len(sanitized) < 2:
            raise ValueError('Alias must be at least 2 characters after trimming whitespace')
        if len(sanitized) > 32:
            raise ValueError('Alias must be at most 32 characters')
        return sanitized


# ============== Internal Models ==============
# Used internally, includes observer_id


class LearnerInternal(BaseModel):
    """
    Internal schema with full learner data.
    Used for database operations, NOT exposed to clients.
    """
    learner_id: UUID
    observer_id: UUID
    alias: str
    learner_code: str
    created_at: datetime
    
    class Config:
        from_attributes = True
