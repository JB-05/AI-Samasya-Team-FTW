# =============================================================================
# GLOBAL CONSTANTS
# Non-diagnostic disclaimer and forbidden medical terms
# =============================================================================

# =============================================================================
# NON-DIAGNOSTIC DISCLAIMER (Must appear in all outputs)
# =============================================================================

DISCLAIMER = """
This tool provides observational insights only, NOT diagnostic assessments.
It does not identify, diagnose, or suggest any medical, psychological, or 
developmental condition. Consult qualified professionals for any concerns.
"""

DISCLAIMER_SHORT = (
    "Observational insights only. Not a diagnostic tool. "
    "Consult professionals for concerns."
)

DISCLAIMER_REPORT = """
**Important Notice:**
This report describes observed learning patterns from gameplay activities.
It is NOT a diagnostic assessment and does NOT indicate any medical,
psychological, or developmental condition.

• These observations are based on limited gameplay data
• Every child learns differently - patterns are descriptive only
• Always consult qualified professionals for any concerns
"""


# =============================================================================
# FORBIDDEN MEDICAL TERMS (Never use in any output)
# =============================================================================

FORBIDDEN_TERMS = frozenset([
    # Diagnostic terms
    "diagnosis", "diagnose", "diagnosed", "diagnostic",
    "disorder", "syndrome", "condition", "disease",
    "disability", "disabled", "impairment", "impaired",
    
    # Specific conditions - NEVER MENTION
    "adhd", "add", "attention deficit",
    "autism", "autistic", "asd", "asperger",
    "dyslexia", "dyslexic",
    "dysgraphia", "dyscalculia", "dyspraxia",
    "learning disability", "learning disorder",
    "intellectual disability",
    "developmental delay", "global delay",
    "special needs", "special education",
    "sensory processing",
    "executive function disorder",
    "oppositional defiant",
    "conduct disorder",
    
    # Clinical terms
    "clinical", "clinician",
    "medical", "psychiatric", "psychological",
    "treatment", "therapy", "intervention",
    "medication", "prescription",
    "symptom", "symptoms", "pathology",
    "assessment", "evaluation", "screening",
    
    # Deficit language
    "deficit", "deficiency", "deficient",
    "dysfunction", "dysfunctional",
    "abnormal", "abnormality",
    "atypical", "deviant",
    
    # Comparative/labeling
    "retarded", "retardation",
    "handicap", "handicapped",
    "slow learner", "behind",
    "low functioning", "high functioning",
])


# =============================================================================
# SAFE LANGUAGE ALTERNATIVES
# =============================================================================

SAFE_REPLACEMENTS = {
    "struggles with": "is developing skills in",
    "has difficulty": "is building capacity for",
    "cannot": "is learning to",
    "fails to": "is working toward",
    "unable to": "is practicing",
    "poor at": "growing in",
    "weak in": "developing in",
    "lacks": "is building",
    "deficit in": "focus area:",
    "problem with": "opportunity for growth in",
}


# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

def contains_forbidden_term(text: str) -> tuple[bool, list[str]]:
    """
    Check if text contains any forbidden medical terms.
    
    Returns:
        (has_violation, list_of_found_terms)
    """
    text_lower = text.lower()
    found = [term for term in FORBIDDEN_TERMS if term in text_lower]
    return len(found) > 0, found


def sanitize_text(text: str) -> str:
    """
    Replace problematic phrases with safe alternatives.
    Does NOT remove forbidden terms - that should block output.
    """
    result = text
    for bad, good in SAFE_REPLACEMENTS.items():
        result = result.replace(bad, good)
        result = result.replace(bad.capitalize(), good.capitalize())
    return result


def validate_output(text: str) -> tuple[bool, str]:
    """
    Validate that output text is safe for users.
    
    Returns:
        (is_safe, error_message_if_not_safe)
    """
    has_violation, found_terms = contains_forbidden_term(text)
    
    if has_violation:
        return False, f"Output contains forbidden terms: {', '.join(found_terms)}"
    
    return True, ""
