# LLM service for pattern explanation
# Uses Gemini API to generate human-readable explanations
# CRITICAL: LLM only sees patterns, NEVER raw gameplay data
# All outputs are filtered for non-diagnostic language

from typing import Dict, List, Any, Optional
import json

from ..config import get_settings
from ..schemas.pattern import DetectedPattern, PatternSnapshot
from ..schemas.report import (
    PatternExplanation,
    ReportSection,
    AudienceType,
)
from ..utils.safety_filters import sanitize_llm_response, validate_output_safety


class LLMService:
    """
    Gemini API integration for pattern explanation.
    
    CRITICAL SAFETY RULES:
    1. LLM ONLY receives pattern summaries, NEVER raw gameplay events
    2. All prompts enforce non-diagnostic language
    3. All outputs are filtered through safety_filters
    4. Explanations are descriptive, not prescriptive
    """
    
    def __init__(self):
        """Initialize the LLM service."""
        self.settings = get_settings()
        self._client = None
        
        # System prompt enforcing non-diagnostic language
        self.system_prompt = """
You are an educational assistant helping parents and teachers understand 
children's learning patterns. You explain patterns in positive, growth-oriented 
language.

CRITICAL RULES:
- NEVER use diagnostic language (disorder, disability, diagnosis, etc.)
- NEVER suggest the child has any condition or impairment
- NEVER recommend clinical assessment or intervention
- ALWAYS use positive, strength-based framing
- ALWAYS focus on observable patterns, not underlying causes
- Describe what the child IS doing, not what they "can't" do
- Suggest fun activities, NOT treatments or therapies

Example good language:
- "Shows developing skills in..." (not "struggles with")
- "Is building capacity for..." (not "has difficulty with")
- "Benefits from additional practice in..." (not "weak at")
"""
    
    def _get_client(self):
        """Get or create Gemini client."""
        if self._client is None:
            # TODO: Initialize Google Generative AI client
            # import google.generativeai as genai
            # genai.configure(api_key=self.settings.gemini_api_key)
            # self._client = genai.GenerativeModel('gemini-pro')
            pass
        return self._client
    
    async def explain_patterns(
        self,
        patterns: List[DetectedPattern],
        audience: AudienceType = AudienceType.PARENT
    ) -> List[PatternExplanation]:
        """
        Generate explanations for detected patterns.
        
        Args:
            patterns: Patterns to explain (NOT raw events)
            audience: Target audience for the explanation
            
        Returns:
            List of pattern explanations
        """
        # TODO: Implement pattern explanation
        # 1. Format patterns for LLM (sanitized summary only)
        # 2. Adjust prompt for audience
        # 3. Call Gemini API
        # 4. Parse and validate response
        # 5. Apply safety filters
        # 6. Return explanations
        
        explanations = []
        
        for pattern in patterns:
            explanation = await self._explain_single_pattern(pattern, audience)
            explanations.append(explanation)
        
        return explanations
    
    async def _explain_single_pattern(
        self,
        pattern: DetectedPattern,
        audience: AudienceType
    ) -> PatternExplanation:
        """Generate explanation for a single pattern."""
        # TODO: Implement single pattern explanation
        
        # For now, return placeholder
        return PatternExplanation(
            pattern_category=pattern.category,
            pattern_type=pattern.pattern_type,
            explanation=f"Observed pattern in {pattern.category.value} area.",
            observations=pattern.indicators,
            suggestions=[]
        )
    
    async def generate_report_sections(
        self,
        snapshot: PatternSnapshot,
        audience: AudienceType
    ) -> List[ReportSection]:
        """
        Generate report sections from a pattern snapshot.
        
        Args:
            snapshot: Pattern snapshot (NOT raw events)
            audience: Target audience
            
        Returns:
            List of report sections with LLM-generated content
        """
        # TODO: Implement report section generation
        # 1. Group patterns by category
        # 2. Generate section for each category
        # 3. Add summary section
        # 4. Apply safety filters to all content
        
        sections = []
        
        # Placeholder sections
        sections.append(ReportSection(
            title="Overview",
            content="Session pattern analysis summary.",
            patterns_covered=[]
        ))
        
        return sections
    
    async def generate_summary(
        self,
        snapshot: PatternSnapshot,
        audience: AudienceType
    ) -> str:
        """Generate a brief summary of the session patterns."""
        # TODO: Implement summary generation
        
        pattern_count = len(snapshot.patterns)
        return f"This session revealed {pattern_count} learning pattern(s)."
    
    def _format_patterns_for_llm(
        self,
        patterns: List[DetectedPattern]
    ) -> str:
        """
        Format patterns for LLM consumption.
        
        IMPORTANT: Only includes pattern summaries, never raw data.
        """
        formatted = []
        
        for p in patterns:
            formatted.append({
                "category": p.category.value,
                "type": p.pattern_type,
                "confidence": p.confidence.value,
                "indicators": p.indicators,
            })
        
        return json.dumps(formatted, indent=2)
    
    def _validate_and_sanitize(self, llm_output: str) -> str:
        """Validate and sanitize LLM output."""
        # Check for safety violations
        is_safe, violations = validate_output_safety(llm_output)
        
        if not is_safe:
            # Log violations for review
            # TODO: Implement proper logging
            print(f"Safety violations detected: {violations}")
        
        # Apply sanitization
        return sanitize_llm_response(llm_output)


# Singleton instance
_llm_service: LLMService | None = None


def get_llm_service() -> LLMService:
    """Get or create LLM service instance."""
    global _llm_service
    if _llm_service is None:
        _llm_service = LLMService()
    return _llm_service


# TODO: Add response caching to reduce API calls
# TODO: Implement rate limiting
# TODO: Add fallback for API failures
