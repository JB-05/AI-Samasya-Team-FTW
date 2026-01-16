# =============================================================================
# FEATURE ENGINE
# Deterministic feature extraction from gameplay events
# =============================================================================
#
# Metrics (minimal set):
# 1. Mean reaction time (ms)
# 2. Reaction time variability (standard deviation)
# 3. Miss rate (percentage of missed targets)
#
# =============================================================================

from typing import List, Optional
from dataclasses import dataclass
import statistics


@dataclass
class FocusTapFeatures:
    """Extracted features from Focus Tap game."""
    
    # Core metrics
    mean_reaction_time_ms: float
    reaction_time_std_ms: float  # Variability
    miss_rate: float             # 0.0 to 1.0
    
    # Metadata
    total_events: int
    hit_count: int
    miss_count: int
    
    @property
    def has_high_variability(self) -> bool:
        """Check if RT variability is notably high."""
        # High variability = std > 40% of mean
        if self.mean_reaction_time_ms == 0:
            return False
        return self.reaction_time_std_ms / self.mean_reaction_time_ms > 0.4
    
    @property
    def has_high_miss_rate(self) -> bool:
        """Check if miss rate is notably high."""
        return self.miss_rate > 0.3  # More than 30% misses


def extract_focus_tap_features(events: List[dict]) -> Optional[FocusTapFeatures]:
    """
    Extract features from Focus Tap game events.
    
    Args:
        events: List of tap events with keys:
            - timestamp_ms: When user tapped
            - target_appeared_ms: When target appeared
            - was_hit: Whether user hit the target
    
    Returns:
        FocusTapFeatures or None if insufficient data
    """
    if not events or len(events) < 3:
        # Need at least 3 events for meaningful statistics
        return None
    
    # Separate hits and misses
    reaction_times = []
    hit_count = 0
    miss_count = 0
    
    for event in events:
        was_hit = event.get("was_hit", False)
        
        if was_hit:
            hit_count += 1
            # Calculate reaction time
            timestamp = event.get("timestamp_ms", 0)
            appeared = event.get("target_appeared_ms", 0)
            rt = timestamp - appeared
            if rt > 0:  # Valid reaction time
                reaction_times.append(rt)
        else:
            miss_count += 1
    
    total_events = hit_count + miss_count
    
    # Calculate metrics
    if reaction_times:
        mean_rt = statistics.mean(reaction_times)
        # Standard deviation (variability)
        if len(reaction_times) >= 2:
            std_rt = statistics.stdev(reaction_times)
        else:
            std_rt = 0.0
    else:
        mean_rt = 0.0
        std_rt = 0.0
    
    miss_rate = miss_count / total_events if total_events > 0 else 0.0
    
    return FocusTapFeatures(
        mean_reaction_time_ms=round(mean_rt, 2),
        reaction_time_std_ms=round(std_rt, 2),
        miss_rate=round(miss_rate, 3),
        total_events=total_events,
        hit_count=hit_count,
        miss_count=miss_count
    )
