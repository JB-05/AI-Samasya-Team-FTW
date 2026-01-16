# Services module
# Business logic for the learning pattern analysis system

from .event_store import event_store, EventStore, SessionData
from .feature_engine import extract_focus_tap_features, FocusTapFeatures
from .pattern_engine import infer_pattern, PatternResult

__all__ = [
    "event_store",
    "EventStore", 
    "SessionData",
    "extract_focus_tap_features",
    "FocusTapFeatures",
    "infer_pattern",
    "PatternResult"
]
