# Trend aggregation service
# Aggregates patterns across sessions for longitudinal analysis
# Calculates progress trends over time
# Only works with persisted pattern snapshots, never raw events

from typing import Dict, List, Any, Optional
from datetime import datetime, date, timedelta
from uuid import UUID, uuid4
from collections import defaultdict

from ..db.supabase import get_supabase_admin


class TrendEngine:
    """
    Longitudinal trend aggregation engine.
    
    Aggregates pattern data across multiple sessions to
    identify learning trends over time.
    
    Key principles:
    - Works only with persisted pattern snapshots
    - Never accesses raw gameplay events
    - Provides trend direction without diagnostic labels
    - Requires minimum 3 sessions
    - Deterministic computation (no ML)
    """
    
    MIN_SESSIONS_FOR_TRENDS = 3
    
    def compute_trends_for_learner(self, learner_id: UUID) -> List[Dict]:
        """
        Compute trends for a learner based on pattern snapshots.
        
        Rules:
        - Minimum 3 sessions required
        - Group patterns by pattern_name
        - Determine trend_type: 'stable', 'fluctuating', or 'improving'
        
        Returns:
            List of trend summaries with pattern_name and trend_type
        """
        supabase = get_supabase_admin()
        if not supabase:
            return []
        
        # Get all pattern snapshots for this learner, ordered by date
        result = supabase.table("pattern_snapshots").select(
            "snapshot_id, session_id, pattern_name, created_at"
        ).eq("learner_id", str(learner_id)).order(
            "created_at", desc=False
        ).execute()
        
        if not result.data:
            return []
        
        # Count unique sessions
        unique_sessions = set(s["session_id"] for s in result.data)
        if len(unique_sessions) < self.MIN_SESSIONS_FOR_TRENDS:
            return []  # Insufficient data
        
        # Group snapshots by pattern_name
        patterns_by_name: Dict[str, List[Dict]] = defaultdict(list)
        for snapshot in result.data:
            pattern_name = snapshot["pattern_name"]
            patterns_by_name[pattern_name].append(snapshot)
        
        trends = []
        
        # Compute trend for each pattern
        for pattern_name, snapshots in patterns_by_name.items():
            trend_type = self._determine_trend_type(snapshots, unique_sessions)
            
            # Upsert trend into database
            trend_data = {
                "learner_id": str(learner_id),
                "pattern_name": pattern_name,
                "trend_type": trend_type,
                "session_count": len(set(s["session_id"] for s in snapshots)),
            }
            
            # Use upsert to handle UNIQUE constraint
            upsert_result = supabase.table("trend_summaries").upsert(
                trend_data,
                on_conflict="learner_id,pattern_name"
            ).execute()
            
            if upsert_result.data:
                trends.append({
                    "pattern_name": pattern_name,
                    "trend_type": trend_type,
                })
        
        return trends
    
    def _determine_trend_type(
        self,
        snapshots: List[Dict],
        all_sessions: set
    ) -> str:
        """
        Determine trend type based on pattern consistency.
        
        Logic:
        - stable: Pattern appears in >70% of recent sessions consistently
        - fluctuating: Pattern appears in 30-70% of sessions or varies
        - improving: Pattern appeared frequently early, less recently
        """
        if len(snapshots) < 2:
            return "fluctuating"
        
        # Sort snapshots by date
        sorted_snapshots = sorted(
            snapshots,
            key=lambda s: s["created_at"]
        )
        
        # Split into early and recent halves
        mid_point = len(sorted_snapshots) // 2
        early = sorted_snapshots[:mid_point]
        recent = sorted_snapshots[mid_point:]
        
        # Count unique sessions per period
        early_sessions = set(s["session_id"] for s in early)
        recent_sessions = set(s["session_id"] for s in recent)
        
        # Total unique sessions for this pattern
        pattern_sessions = set(s["session_id"] for s in snapshots)
        pattern_frequency = len(pattern_sessions) / len(all_sessions) if all_sessions else 0
        
        # Determine trend
        if pattern_frequency > 0.7:
            # Pattern appears consistently → stable
            return "stable"
        elif len(recent_sessions) < len(early_sessions) * 0.7:
            # Pattern appearing less recently → improving (less of a "problem")
            return "improving"
        else:
            # Pattern varies → fluctuating
            return "fluctuating"


# Singleton instance
_trend_engine: Optional[TrendEngine] = None


def get_trend_engine() -> TrendEngine:
    """Get or create trend engine instance."""
    global _trend_engine
    if _trend_engine is None:
        _trend_engine = TrendEngine()
    return _trend_engine
