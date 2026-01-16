# =============================================================================
# REPORT GENERATOR SERVICE
# Phase 3.1: Gemini-based report generation
# Converts pattern snapshots + trend summaries into narrative reports
# =============================================================================
#
# CRITICAL SAFETY CONSTRAINTS:
# - Gemini receives ONLY: pattern_name, learning_impact, support_focus, trend_type
# - NEVER sends: raw gameplay data, metrics, numbers, game names, confidence
# - Output is filtered for forbidden terms
# - Reports saved with validation_status='pending'
#
# =============================================================================

import os
from pathlib import Path
from typing import List, Dict, Optional
from uuid import UUID, uuid4
import google.generativeai as genai

from ..config import get_settings_dev
from ..db.supabase import get_supabase_admin
from ..utils.safety_filters import validate_output_safety


class ReportGenerator:
    """
    Gemini-based report generator.
    
    Converts pattern snapshots and trend summaries into
    human-readable, non-diagnostic narrative reports.
    """
    
    def __init__(self):
        """Initialize the report generator."""
        self.settings = get_settings_dev()
        self._client = None
        self._system_prompt = None
        
        # Load static system prompt
        self._load_system_prompt()
        
        # Initialize Gemini client if key is available
        if self.settings and self.settings.gemini_key:
            genai.configure(api_key=self.settings.gemini_key)
            self._client = genai.GenerativeModel(
                'gemini-1.5-flash',  # Use flash model for faster responses
                generation_config={
                    'temperature': 0.25,  # Low temperature for consistent, calm output
                    'max_output_tokens': 600,
                }
            )
    
    def _load_system_prompt(self) -> None:
        """Load static system prompt from file."""
        try:
            # Get path relative to this file
            current_dir = Path(__file__).parent
            prompt_file = current_dir / 'prompts' / 'gemini_report_generator.txt'
            
            if prompt_file.exists():
                with open(prompt_file, 'r', encoding='utf-8') as f:
                    self._system_prompt = f.read().strip()
            else:
                # Fallback if file not found
                self._system_prompt = self._get_fallback_prompt()
        except Exception as e:
            print(f"[WARNING] Could not load system prompt: {e}")
            self._system_prompt = self._get_fallback_prompt()
    
    def _get_fallback_prompt(self) -> str:
        """Fallback prompt if file cannot be loaded."""
        return """You are an educational reporting assistant.
Write calm, supportive, non-diagnostic summaries of learning patterns.
DO NOT use diagnostic language, numbers, or medical terms.
End with: "Observational insights only. This is not a diagnostic assessment."
"""
    
    def generate_report(
        self,
        learner_id: UUID,
        scope: str,  # 'session' or 'learner'
        session_id: Optional[UUID] = None,
        audience: str = 'parent'  # 'parent' or 'teacher'
    ) -> Dict:
        """
        Generate a narrative report using Gemini.
        
        Args:
            learner_id: UUID of the learner
            scope: 'session' or 'learner'
            session_id: UUID of session (required if scope='session')
            audience: 'parent' or 'teacher'
            
        Returns:
            Dict with report_id and status
        """
        if not self._client:
            raise ValueError("Gemini API key not configured. Cannot generate reports.")
        
        if scope == 'session' and not session_id:
            raise ValueError("session_id required when scope='session'")
        
        # Fetch pattern snapshots
        patterns = self._fetch_patterns(learner_id, session_id)
        if not patterns:
            raise ValueError("No patterns found for this learner/session.")
        
        # Fetch trend summaries (optional)
        trends = self._fetch_trends(learner_id)
        
        # Build safe input for Gemini (NO metrics, NO raw data)
        safe_input = self._build_safe_input(patterns, trends, audience)
        
        # Generate report via Gemini
        try:
            report_content = self._call_gemini(safe_input)
        except Exception as e:
            print(f"[ERROR] Gemini generation failed: {e}")
            raise ValueError(f"Failed to generate report: {str(e)}")
        
        # Validate output safety
        is_safe, violations = validate_output_safety(report_content)
        validation_status = 'pending' if is_safe else 'rejected'
        
        if not is_safe:
            print(f"[WARNING] Report contains prohibited terms: {violations}")
            # Still save as rejected for review
        
        # Ensure disclaimer is present
        disclaimer = "Observational insights only. This is not a diagnostic assessment."
        if disclaimer.lower() not in report_content.lower():
            report_content = f"{report_content}\n\n{disclaimer}"
        
        # Save report to database
        report_id = self._save_report(
            learner_id=learner_id,
            scope=scope,
            session_id=session_id,
            audience=audience,
            content=report_content,
            validation_status=validation_status
        )
        
        # Phase 3.2: Validate report immediately after generation
        if is_safe:  # Only validate if basic safety check passed
            try:
                from .report_validator import get_report_validator
                validator = get_report_validator()
                validation_result = validator.validate_report(report_id)
                
                # Update status based on validator result
                final_status = validation_result.get('status', 'pending')
                if final_status == 'rejected':
                    validation_status = 'rejected'
                elif final_status == 'approved':
                    validation_status = 'approved'
                elif final_status == 'rewritten':
                    validation_status = 'rewritten'
                
                # Update report with final validation status
                self._update_validation_status(report_id, validation_status)
                
            except Exception as e:
                print(f"[WARNING] Report validation failed: {e}")
                # Continue with pending status if validation fails
        
        return {
            "report_id": str(report_id),
            "status": "generated_pending_validation" if is_safe else "generated_rejected"
        }
    
    def _fetch_patterns(
        self,
        learner_id: UUID,
        session_id: Optional[UUID] = None
    ) -> List[Dict]:
        """Fetch pattern snapshots from database."""
        supabase = get_supabase_admin()
        if not supabase:
            return []
        
        query = supabase.table("pattern_snapshots").select(
            "pattern_name, learning_impact, support_focus"
        ).eq("learner_id", str(learner_id))
        
        if session_id:
            query = query.eq("session_id", str(session_id))
        
        result = query.execute()
        return result.data or []
    
    def _fetch_trends(self, learner_id: UUID) -> List[Dict]:
        """Fetch trend summaries from database."""
        supabase = get_supabase_admin()
        if not supabase:
            return []
        
        result = supabase.table("trend_summaries").select(
            "pattern_name, trend_type"
        ).eq("learner_id", str(learner_id)).execute()
        
        return result.data or []
    
    def _build_safe_input(
        self,
        patterns: List[Dict],
        trends: List[Dict],
        audience: str
    ) -> str:
        """
        Build safe input string for Gemini.
        
        CRITICAL: Only includes language fields, NO metrics or raw data.
        """
        lines = [f"Audience: {audience}\n"]
        
        lines.append("Observed learning patterns:")
        for pattern in patterns:
            lines.append(f"- Pattern: {pattern.get('pattern_name', 'Pattern')}")
            lines.append(f"  Learning impact: {pattern.get('learning_impact', '')}")
            lines.append(f"  Support focus: {pattern.get('support_focus', '')}")
            lines.append("")  # Empty line between patterns
        
        if trends:
            lines.append("Trend observations:")
            for trend in trends:
                pattern_name = trend.get('pattern_name', 'Pattern')
                trend_type = trend.get('trend_type', 'stable')
                lines.append(f"- {pattern_name}: {trend_type}")
            lines.append("")
        
        lines.append("Please generate a single, cohesive narrative report.")
        
        return "\n".join(lines)
    
    def _call_gemini(self, user_prompt: str) -> str:
        """
        Call Gemini API to generate report.
        
        Args:
            user_prompt: User prompt with patterns and trends
            
        Returns:
            Generated report content
        """
        if not self._client:
            raise ValueError("Gemini client not initialized")
        
        # Combine system prompt and user prompt
        full_prompt = f"{self._system_prompt}\n\n{user_prompt}"
        
        response = self._client.generate_content(full_prompt)
        
        if not response.text:
            raise ValueError("Gemini returned empty response")
        
        return response.text.strip()
    
    def _save_report(
        self,
        learner_id: UUID,
        scope: str,
        session_id: Optional[UUID],
        audience: str,
        content: str,
        validation_status: str
    ) -> UUID:
        """Save generated report to database."""
        supabase = get_supabase_admin()
        if not supabase:
            raise ValueError("Database connection unavailable")
        
        report_id = uuid4()
        
        report_data = {
            "report_id": str(report_id),
            "learner_id": str(learner_id),
            "report_scope": scope,
            "source_session_id": str(session_id) if session_id else None,
            "audience": audience,
            "content": content,
            "generation_method": "ai",
            "validation_status": validation_status,
        }
        
        result = supabase.table("reports").insert(report_data).execute()
        
        if not result.data:
            raise ValueError("Failed to save report to database")
        
        return report_id
    
    def _update_validation_status(self, report_id: UUID, validation_status: str) -> None:
        """Update report validation status."""
        supabase = get_supabase_admin()
        if not supabase:
            return
        
        supabase.table("reports").update({
            "validation_status": validation_status
        }).eq("report_id", str(report_id)).execute()


# Singleton instance
_report_generator: Optional[ReportGenerator] = None


def get_report_generator() -> ReportGenerator:
    """Get or create report generator instance."""
    global _report_generator
    if _report_generator is None:
        _report_generator = ReportGenerator()
    return _report_generator
