# Pydantic schemas for insight reports
# Defines models for LLM-generated explanations
# All content is filtered for non-diagnostic language
# Reports explain patterns, not raw gameplay

from datetime import datetime
from typing import Optional, Dict, Any, List
from pydantic import BaseModel, Field
from enum import Enum

from .pattern import PatternCategory, DetectedPattern


class ReportType(str, Enum):
    """Types of insight reports."""
    SESSION = "session"  # Single session report
    COMPARISON = "comparison"  # Multi-session comparison
    PROGRESS = "progress"  # Progress over time


class AudienceType(str, Enum):
    """Target audience for the report."""
    PARENT = "parent"
    TEACHER = "teacher"


# ============== Report Request Schemas ==============

class ReportRequest(BaseModel):
    """Schema for requesting a report generation."""
    audience: AudienceType = AudienceType.PARENT
    include_recommendations: bool = True
    language: str = "en"
    detail_level: str = Field(
        default="standard",
        pattern="^(brief|standard|detailed)$"
    )


# ============== Report Content Schemas ==============

class PatternExplanation(BaseModel):
    """
    LLM-generated explanation for a detected pattern.
    
    NOTE: The LLM explains patterns only - it never sees raw gameplay.
    All content is filtered for safe, non-diagnostic language.
    """
    pattern_category: PatternCategory
    pattern_type: str
    explanation: str = Field(
        ...,
        description="Human-friendly explanation of what this pattern means"
    )
    observations: List[str] = Field(
        default_factory=list,
        description="Observable behaviors associated with this pattern"
    )
    suggestions: List[str] = Field(
        default_factory=list,
        description="Activity suggestions (NOT interventions or treatments)"
    )


class ReportSection(BaseModel):
    """A section of the insight report."""
    title: str
    content: str
    patterns_covered: List[str] = Field(default_factory=list)


class ReportResponse(BaseModel):
    """Schema for complete insight report response."""
    id: str
    session_id: str
    learner_id: str
    report_type: ReportType
    audience: AudienceType
    
    # Report content
    title: str
    summary: str = Field(
        ...,
        description="Brief overview of the session patterns"
    )
    sections: List[ReportSection] = Field(default_factory=list)
    pattern_explanations: List[PatternExplanation] = Field(default_factory=list)
    
    # Metadata
    generated_at: datetime = Field(default_factory=datetime.utcnow)
    llm_model: Optional[str] = None
    safety_filtered: bool = True
    
    class Config:
        from_attributes = True


class ReportComparisonResponse(BaseModel):
    """Schema for comparing multiple session reports."""
    learner_id: str
    session_ids: List[str]
    comparison_summary: str
    pattern_changes: Dict[str, Any]
    generated_at: datetime = Field(default_factory=datetime.utcnow)


# TODO: Add report templates for different audiences
# TODO: Implement localization support
# TODO: Add export format schemas (PDF, etc.)
