# Global disclaimer constants
# Non-diagnostic language enforcement
# These MUST be included in all user-facing outputs

from typing import Dict, List


# =============================================================================
# CORE DISCLAIMERS (Must appear in reports)
# =============================================================================

REPORT_DISCLAIMER = """
**Important Notice:**
This report describes observed learning patterns and is NOT a diagnostic assessment. 
It does not identify, diagnose, or suggest any medical, psychological, or developmental 
condition. The observations are based on limited gameplay data and should be used only 
as a starting point for understanding a child's learning style.

Always consult qualified professionals for any concerns about a child's development.
"""

PATTERN_DISCLAIMER = """
These patterns reflect observations from gameplay activities only. They do not 
indicate any diagnosis, disorder, or clinical condition. Every child learns differently.
"""

TREND_DISCLAIMER = """
Trends show changes in observed patterns over time. They do not predict outcomes 
or indicate the presence or absence of any condition.
"""


# =============================================================================
# FOOTER DISCLAIMERS (For all pages/screens)
# =============================================================================

FOOTER_DISCLAIMER_SHORT = (
    "This tool provides observational insights only, not diagnostic assessments."
)

FOOTER_DISCLAIMER_FULL = (
    "AI Samasya provides observational learning pattern insights based on gameplay "
    "activities. It is NOT a diagnostic tool and does not identify, assess, or "
    "diagnose any medical, psychological, or developmental conditions. "
    "Consult qualified professionals for any concerns."
)


# =============================================================================
# LLM PROMPT CONSTRAINTS (Sent to Gemini)
# =============================================================================

LLM_SYSTEM_CONSTRAINTS = """
You are describing learning patterns observed during gameplay activities.

CRITICAL RULES - NEVER VIOLATE:
1. NEVER use diagnostic language (disorder, disability, diagnosis, syndrome, etc.)
2. NEVER suggest the child has any condition or impairment
3. NEVER recommend clinical assessment, therapy, or medical intervention
4. NEVER compare to "normal" children or developmental milestones
5. NEVER make predictions about future outcomes or abilities
6. ALWAYS use positive, strength-based, growth-oriented language
7. ALWAYS describe what the child IS doing, not what they "can't" do
8. ALWAYS frame challenges as "developing areas" or "growth opportunities"

APPROVED LANGUAGE:
- "Shows developing skills in..."
- "Is building capacity for..."
- "Benefits from additional practice with..."
- "Demonstrates strength in..."
- "May enjoy activities that..."

PROHIBITED LANGUAGE:
- Any medical/clinical terms
- "Struggles with", "has difficulty", "cannot", "fails to"
- "Weak", "poor", "deficient", "impaired", "delayed"
- Comparisons to other children or norms
- References to specific conditions (ADHD, autism, dyslexia, etc.)
"""


# =============================================================================
# PROHIBITED TERMS (For safety filtering)
# =============================================================================

PROHIBITED_DIAGNOSTIC_TERMS: List[str] = [
    # Diagnostic terms
    "diagnosis", "diagnose", "diagnosed", "diagnostic",
    "disorder", "syndrome", "condition",
    "disability", "disabled", "impairment", "impaired",
    
    # Specific conditions (NEVER mention)
    "adhd", "attention deficit", "hyperactivity",
    "autism", "autistic", "asd", "spectrum",
    "dyslexia", "dyslexic", "dysgraphia", "dyscalculia",
    "learning disability", "learning disorder",
    "developmental delay", "delayed development",
    "special needs", "special education",
    
    # Clinical/Medical terms
    "clinical", "medical", "psychiatric", "psychological",
    "treatment", "therapy", "intervention", "medication",
    "symptom", "symptoms", "pathology", "pathological",
    "abnormal", "atypical", "deviant",
    
    # Deficit language
    "deficit", "deficiency", "deficient",
    "impairment", "impaired",
    "dysfunction", "dysfunctional",
    
    # Comparative/normative terms
    "normal", "abnormal", "typical", "atypical",
    "behind", "delayed", "slow", "retarded",
]

SAFE_LANGUAGE_REPLACEMENTS: Dict[str, str] = {
    "struggles with": "is developing skills in",
    "has difficulty": "is building capacity for",
    "cannot": "is learning to",
    "fails to": "is working toward",
    "poor performance": "emerging abilities",
    "weakness": "growth opportunity",
    "weak in": "developing in",
    "deficit": "developing area",
    "lacks": "is building",
    "unable to": "learning to",
    "problem with": "focus area for growth in",
}


# =============================================================================
# VALIDATION HELPERS
# =============================================================================

def contains_prohibited_language(text: str) -> tuple[bool, List[str]]:
    """
    Check if text contains any prohibited diagnostic language.
    
    Returns:
        Tuple of (has_violations, list_of_found_terms)
    """
    text_lower = text.lower()
    found_terms = []
    
    for term in PROHIBITED_DIAGNOSTIC_TERMS:
        if term in text_lower:
            found_terms.append(term)
    
    return len(found_terms) > 0, found_terms


def get_disclaimer_for_context(context: str) -> str:
    """
    Get appropriate disclaimer for a given context.
    
    Args:
        context: One of 'report', 'pattern', 'trend', 'footer', 'footer_short'
    
    Returns:
        Appropriate disclaimer text
    """
    disclaimers = {
        'report': REPORT_DISCLAIMER,
        'pattern': PATTERN_DISCLAIMER,
        'trend': TREND_DISCLAIMER,
        'footer': FOOTER_DISCLAIMER_FULL,
        'footer_short': FOOTER_DISCLAIMER_SHORT,
    }
    return disclaimers.get(context, FOOTER_DISCLAIMER_SHORT)
