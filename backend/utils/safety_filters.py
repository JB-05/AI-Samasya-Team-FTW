# Safety filters for ensuring non-diagnostic language
# Enforces privacy constraints on all outputs
# Filters LLM responses to remove diagnostic terminology
# Ensures child-safe, non-labeling language in all reports

from typing import List

# Diagnostic terms that should NEVER appear in outputs
PROHIBITED_TERMS = [
    "diagnosis", "diagnose", "diagnosed",
    "disorder", "disability", "disabled",
    "adhd", "autism", "dyslexia", "dysgraphia",
    "learning disability", "special needs",
    "deficient", "deficiency", "impaired", "impairment",
    "abnormal", "atypical",
    "treatment", "therapy", "intervention",
    "clinical", "medical", "psychiatric",
    "symptom", "syndrome",
]

# Safe alternative phrases
SAFE_ALTERNATIVES = {
    "struggles with": "shows developing skills in",
    "has difficulty": "is building capacity for",
    "cannot": "is learning to",
    "fails to": "is working toward",
    "poor performance": "emerging abilities",
    "weakness": "growth opportunity",
    "deficit": "developing area",
}


def filter_diagnostic_language(text: str) -> str:
    """
    Filter out diagnostic language from text.
    Replaces prohibited terms with safe alternatives.
    
    Args:
        text: Input text to filter
        
    Returns:
        Filtered text with non-diagnostic language
    """
    filtered_text = text.lower()
    
    # Check for prohibited terms
    for term in PROHIBITED_TERMS:
        if term in filtered_text:
            # TODO: Implement proper replacement or flagging
            pass
    
    # Apply safe alternatives
    for problematic, safe in SAFE_ALTERNATIVES.items():
        filtered_text = filtered_text.replace(problematic, safe)
    
    # TODO: Implement more sophisticated NLP-based filtering
    
    return text  # Return original for now until filtering is complete


def validate_output_safety(text: str) -> tuple[bool, List[str]]:
    """
    Validate that output text meets safety requirements.
    
    Args:
        text: Text to validate
        
    Returns:
        Tuple of (is_safe, list of violations found)
    """
    violations = []
    text_lower = text.lower()
    
    for term in PROHIBITED_TERMS:
        if term in text_lower:
            violations.append(f"Prohibited term found: '{term}'")
    
    is_safe = len(violations) == 0
    return is_safe, violations


def sanitize_llm_response(response: str) -> str:
    """
    Sanitize LLM response to ensure compliance with safety requirements.
    
    Args:
        response: Raw LLM response
        
    Returns:
        Sanitized response safe for user consumption
    """
    # TODO: Implement comprehensive sanitization
    # 1. Filter diagnostic language
    # 2. Ensure positive, growth-oriented framing
    # 3. Remove any specific recommendations for intervention
    
    return filter_diagnostic_language(response)


# TODO: Add logging for safety violations
# TODO: Implement severity levels for violations
# TODO: Add admin alerts for repeated violations
