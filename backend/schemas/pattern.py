# Pydantic schemas for pattern data
# Defines models for detected learning patterns
# Patterns are derived from gameplay features (not raw events)
# Only pattern summaries are persisted, not source data

from datetime import datetime
from typing import Optional, Dict, Any, List
from pydantic import BaseModel, Field
from enum import Enum


class PatternCategory(str, Enum):
    """Categories of learning patterns."""
    ATTENTION = "attention"
    MEMORY = "memory"
    PROCESSING_SPEED = "processing_speed"
    PROBLEM_SOLVING = "problem_solving"
    SEQUENCING = "sequencing"
    VISUAL_SPATIAL = "visual_spatial"
    PERSISTENCE = "persistence"


class ConfidenceLevel(str, Enum):
    """Confidence levels for pattern detection."""
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"


# ============== Pattern Schemas ==============

class PatternBase(BaseModel):
    """Base schema for pattern data."""
    category: PatternCategory
    pattern_type: str = Field(..., description="Specific pattern within category")
    confidence: ConfidenceLevel
    confidence_score: float = Field(..., ge=0.0, le=1.0)


class DetectedPattern(PatternBase):
    """Schema for a single detected pattern."""
    description: str = Field(
        ...,
        description="Human-readable description of the pattern"
    )
    indicators: List[str] = Field(
        default_factory=list,
        description="Observable indicators that led to this pattern"
    )
    supporting_metrics: Dict[str, float] = Field(
        default_factory=dict,
        description="Quantitative metrics supporting the pattern"
    )


class PatternSnapshot(BaseModel):
    """
    Schema for persisted pattern data from a session.
    
    NOTE: This is what gets stored in the database.
    Contains NO raw gameplay events - only derived patterns.
    """
    id: str
    session_id: str
    learner_id: str
    patterns: List[DetectedPattern]
    overall_confidence: float = Field(..., ge=0.0, le=1.0)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    
    class Config:
        from_attributes = True


class PatternSummary(BaseModel):
    """Lightweight pattern summary for listings."""
    id: str
    session_id: str
    pattern_count: int
    primary_category: PatternCategory
    overall_confidence: float
    created_at: datetime


# ============== Pattern Inference Schemas ==============

class PatternRule(BaseModel):
    """Schema for pattern inference rules."""
    rule_id: str
    category: PatternCategory
    conditions: Dict[str, Any]
    output_pattern: str
    confidence_modifier: float = 1.0


class InferenceResult(BaseModel):
    """Result of pattern inference on extracted features."""
    patterns: List[DetectedPattern]
    rules_applied: List[str]
    inference_time_ms: float
    warnings: List[str] = Field(default_factory=list)


# TODO: Define specific patterns for each category
# TODO: Implement pattern versioning for algorithm updates
# TODO: Add pattern comparison utilities
