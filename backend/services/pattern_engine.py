# =============================================================================
# PATTERN ENGINE
# Rule-based pattern inference from extracted features
# =============================================================================
#
# CRITICAL: This is NOT a diagnostic tool.
# Patterns are observational descriptions, not medical labels.
#
# Rule (minimal):
# IF RT variability is high → "Attention variability" pattern
#
# =============================================================================

from typing import Optional
from dataclasses import dataclass

from .feature_engine import FocusTapFeatures


@dataclass
class PatternResult:
    """A detected learning pattern."""
    pattern_name: str
    confidence: str  # "low", "moderate", "high"
    learning_impact: str
    support_focus: str
    explanation: str


def infer_pattern(features: FocusTapFeatures) -> Optional[PatternResult]:
    """
    Infer a learning pattern from extracted features.
    
    IMPORTANT: These are observational patterns, NOT diagnoses.
    The language is intentionally neutral and supportive.
    
    Args:
        features: Extracted gameplay features
    
    Returns:
        PatternResult or None if no clear pattern
    """
    
    # ==========================================================================
    # Rule 1: High reaction time variability
    # ==========================================================================
    if features.has_high_variability:
        return PatternResult(
            pattern_name="Variable focus rhythm",
            confidence="moderate" if features.total_events >= 10 else "low",
            learning_impact=(
                "Learner shows varying response speeds, which may reflect "
                "natural fluctuations in attention during tasks."
            ),
            support_focus=(
                "Consider shorter activity bursts with brief breaks. "
                "Consistent routines may help maintain engagement."
            ),
            explanation=(
                f"Reaction times varied notably (average {features.mean_reaction_time_ms:.0f}ms, "
                f"variability {features.reaction_time_std_ms:.0f}ms). "
                "This is a common pattern that many learners show."
            )
        )
    
    # ==========================================================================
    # Rule 2: High miss rate (secondary pattern)
    # ==========================================================================
    if features.has_high_miss_rate:
        return PatternResult(
            pattern_name="Building target tracking",
            confidence="moderate" if features.total_events >= 10 else "low",
            learning_impact=(
                "Learner is developing skills in tracking and responding "
                "to visual targets."
            ),
            support_focus=(
                "Practice with slower-paced activities may build confidence. "
                "Celebrate successful responses."
            ),
            explanation=(
                f"Missed {features.miss_rate*100:.0f}% of targets. "
                "This suggests the learner is still building visual tracking skills."
            )
        )
    
    # ==========================================================================
    # Default: Steady focus (no concerning patterns)
    # ==========================================================================
    return PatternResult(
        pattern_name="Steady focus",
        confidence="moderate",
        learning_impact=(
            "Learner demonstrated consistent response patterns during "
            "the activity."
        ),
        support_focus=(
            "Continue with current activities. The learner shows "
            "age-appropriate engagement."
        ),
        explanation=(
            f"Responses were consistent (average {features.mean_reaction_time_ms:.0f}ms) "
            f"with {features.hit_count} successful responses out of {features.total_events} attempts."
        )
    )
