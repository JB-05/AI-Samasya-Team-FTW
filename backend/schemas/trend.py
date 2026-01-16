# Pydantic schemas for trend data
# Defines models for longitudinal pattern aggregation
# Tracks learning progress over time
# Only stores aggregates, never raw session data

from datetime import datetime, date
from typing import Optional, Dict, Any, List
from pydantic import BaseModel, Field
from enum import Enum

from .pattern import PatternCategory


class TrendPeriod(str, Enum):
    """Time periods for trend aggregation."""
    WEEK = "week"
    MONTH = "month"
    QUARTER = "quarter"
    YEAR = "year"
    ALL_TIME = "all_time"


class TrendDirection(str, Enum):
    """Direction of trend movement."""
    IMPROVING = "improving"
    STABLE = "stable"
    DECLINING = "declining"
    INSUFFICIENT_DATA = "insufficient_data"


# ============== Trend Data Schemas ==============

class PatternTrend(BaseModel):
    """Trend data for a specific pattern category."""
    category: PatternCategory
    direction: TrendDirection
    change_percentage: Optional[float] = None
    current_average: float
    previous_average: Optional[float] = None
    session_count: int
    data_points: List[Dict[str, Any]] = Field(
        default_factory=list,
        description="Aggregated data points for visualization"
    )


class TrendSummary(BaseModel):
    """Summary of trends for a period."""
    id: str
    learner_id: str
    period: TrendPeriod
    period_start: date
    period_end: date
    
    # Aggregate statistics
    total_sessions: int
    total_time_minutes: Optional[int] = None
    
    # Pattern trends
    pattern_trends: List[PatternTrend] = Field(default_factory=list)
    
    # Overall assessment
    overall_direction: TrendDirection
    highlights: List[str] = Field(
        default_factory=list,
        description="Key observations for this period"
    )
    
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    
    class Config:
        from_attributes = True


class TrendResponse(BaseModel):
    """Response schema for trend queries."""
    learner_id: str
    learner_alias: str
    period: TrendPeriod
    summary: TrendSummary
    
    # Comparative data
    previous_period: Optional[TrendSummary] = None
    comparison_notes: List[str] = Field(default_factory=list)


class TrendHistoryResponse(BaseModel):
    """Historical trend data for visualization."""
    learner_id: str
    start_date: date
    end_date: date
    granularity: TrendPeriod
    
    # Time series data
    data_series: List[Dict[str, Any]] = Field(
        default_factory=list,
        description="Time series data for charts"
    )
    
    # Summary statistics
    total_sessions: int
    active_periods: int


class ObserverOverview(BaseModel):
    """Overview of all learners for an observer."""
    observer_id: str
    learner_summaries: List[Dict[str, Any]] = Field(
        default_factory=list,
        description="Summary for each learner"
    )
    total_learners: int
    total_sessions: int
    generated_at: datetime = Field(default_factory=datetime.utcnow)


# TODO: Add trend prediction schemas
# TODO: Implement anomaly detection schemas
# TODO: Add milestone/achievement tracking
