# =============================================================================
# LEARNER CODE GENERATOR
# Generates unique, non-identifying access codes for learners
# =============================================================================
#
# Rules:
# - 8 characters (uppercase letters + digits, no confusing chars)
# - No semantic meaning
# - No encoding of identity
# - Unique across all learners
# =============================================================================

import secrets
import string

# Character set: uppercase letters + digits, excluding confusing chars (0/O, 1/I/L)
LEARNER_CODE_CHARS = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
LEARNER_CODE_LENGTH = 8


def generate_learner_code() -> str:
    """
    Generate a random 8-character alphanumeric code.
    
    Uses cryptographically secure random generator.
    Characters: A-Z (no O, I, L) + 2-9 (no 0, 1)
    
    Returns:
        8-character uppercase alphanumeric code
    """
    return ''.join(
        secrets.choice(LEARNER_CODE_CHARS) 
        for _ in range(LEARNER_CODE_LENGTH)
    )


def is_valid_learner_code(code: str) -> bool:
    """
    Validate a learner code format.
    
    Args:
        code: The code to validate
        
    Returns:
        True if code is valid format (8 chars, valid characters)
    """
    if not code or len(code) != LEARNER_CODE_LENGTH:
        return False
    return all(c in LEARNER_CODE_CHARS for c in code.upper())
