# Database models - Finalized Schema
# Aligned with privacy-safe learning pattern system
# 
# Design Principles (Non-Negotiable):
# 1. No child identity stored
# 2. No raw gameplay data persisted long-term
# 3. Adults own access and history
# 4. Only derived, non-diagnostic summaries stored
# 5. Everything stored must be defensible to judges

from datetime import datetime
from typing import Optional, Literal
from pydantic import BaseModel, Field
from uuid import UUID


# =============================================================================
# Table 3.1: observers (Adult Accounts)
# Managed by Supabase Auth - NO child data here
# =============================================================================

class Observer(BaseModel):
    """
    Adult account (parent or teacher).
    Managed by Supabase Auth.
    
    NOTE: No child data stored in this table.
    """
    observer_id: UUID  # From Supabase Auth
    role: Literal["parent", "teacher"]
    created_at: datetime
    
    class Config:
        from_attributes = True


class ObserverCreate(BaseModel):
    """Schema for creating observer profile after Supabase Auth signup."""
    role: Literal["parent", "teacher"]


# =============================================================================
# Table 3.2: learners (Alias-Based, Non-Identifying)
# Rules:
# - Alias chosen by adult
# - No age, gender, grade, or name
# - One observer owns their learners
# =============================================================================

class Learner(BaseModel):
    """
    Alias-based learner reference.
    
    PRIVACY: Contains NO identifying information.
    - No age
    - No gender  
    - No grade
    - No real name
    
    Only an adult-defined alias (e.g., "Learner A").
    """
    learner_id: UUID  # Generated
    observer_id: UUID  # FK → observers
    alias: str  # e.g., "Learner A"
    created_at: datetime
    
    class Config:
        from_attributes = True


class LearnerCreate(BaseModel):
    """Schema for creating a new learner alias."""
    alias: str = Field(..., min_length=1, max_length=50)


class LearnerUpdate(BaseModel):
    """Schema for updating a learner alias."""
    alias: Optional[str] = Field(None, min_length=1, max_length=50)


# =============================================================================
# Table 3.3: sessions
# Represents one completed game interaction
# Rules:
# - No raw events stored
# - One session → many pattern snapshots
# =============================================================================

class Session(BaseModel):
    """
    Completed game interaction session.
    
    NOTE: No raw events are stored - only metadata.
    Raw gameplay data exists only in memory during the session.
    """
    session_id: UUID  # Generated
    learner_id: UUID  # FK → learners
    game_set: str  # e.g., "focus.tap + pattern-shift"
    created_at: datetime  # Session completion time
    
    class Config:
        from_attributes = True


class SessionCreate(BaseModel):
    """Schema for creating a session record (on completion)."""
    learner_id: UUID
    game_set: str


# =============================================================================
# Table 3.4: pattern_snapshots (Core Intelligence Storage)
# This is the most important table
# Rules:
# - No scores
# - No diagnoses
# - This is the only long-term behavioral record
# =============================================================================

class PatternSnapshot(BaseModel):
    """
    Core intelligence storage - the most important table.
    
    Stores non-clinical pattern observations from sessions.
    This is the ONLY long-term behavioral record.
    
    CRITICAL: 
    - No scores stored
    - No diagnoses stored
    - Non-clinical language only
    """
    snapshot_id: UUID  # Generated
    session_id: UUID  # FK → sessions
    learner_id: UUID  # FK → learners
    pattern_name: str  # Non-clinical name
    confidence: Literal["low", "moderate", "high"]
    learning_impact: str  # Plain language description
    support_focus: str  # Strategy focus area
    created_at: datetime
    
    class Config:
        from_attributes = True


class PatternSnapshotCreate(BaseModel):
    """Schema for creating a pattern snapshot."""
    session_id: UUID
    learner_id: UUID
    pattern_name: str
    confidence: Literal["low", "moderate", "high"]
    learning_impact: str
    support_focus: str


# =============================================================================
# Table 3.5: trend_summaries (Derived, Optional Cache)
# Rules:
# - Can be regenerated anytime
# - May be cached for performance
# - No raw data dependency
# =============================================================================

class TrendSummary(BaseModel):
    """
    Derived trend summary - optional cache.
    
    Computed deterministically from pattern_snapshots.
    Can be regenerated anytime from stored patterns.
    
    Trend computation (no ML required):
    - frequency
    - confidence stability
    - direction of change
    """
    trend_id: UUID  # Generated
    learner_id: UUID  # FK → learners
    pattern_name: str  # Same as snapshot
    trend_type: Literal["stable", "fluctuating", "improving"]
    session_count: int  # Number of sessions analyzed
    generated_at: datetime
    
    class Config:
        from_attributes = True


class TrendSummaryCreate(BaseModel):
    """Schema for creating/updating a trend summary."""
    learner_id: UUID
    pattern_name: str
    trend_type: Literal["stable", "fluctuating", "improving"]
    session_count: int


# =============================================================================
# What Is Explicitly NOT Stored
# =============================================================================
# | Data                      | Reason              |
# |---------------------------|---------------------|
# | Raw taps / timestamps     | Surveillance risk   |
# | Reaction time arrays      | Over-interpretation |
# | Child name / age          | Identity risk       |
# | Diagnoses                 | Medical liability   |
# | Cross-learner comparisons | Bias risk           |
# =============================================================================

# =============================================================================
# Data Retention Policy
# =============================================================================
# | Data             | Retention           |
# |------------------|---------------------|
# | Raw events       | In-memory only      |
# | Sessions         | Persistent (metadata)|
# | Pattern snapshots| Persistent          |
# | Trend summaries  | Regenerable         |
# =============================================================================
