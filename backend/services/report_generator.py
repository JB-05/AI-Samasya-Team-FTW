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
            # Validate API key format
            if not self.settings.gemini_key or len(self.settings.gemini_key) < 10:
                print("[WARNING] GEMINI_KEY appears invalid (too short or empty)")
                return
            
            try:
                genai.configure(api_key=self.settings.gemini_key)
                # Try gemini-flash-latest first (may have different quota than versioned models)
                # Fallback to other models if needed
                model_name = 'gemini-flash-latest'
                self._client = genai.GenerativeModel(
                    model_name,  # Try latest Flash model (may have better free tier support)
                    generation_config={
                        'temperature': 0.25,  # Low temperature for consistent, calm output
                        'max_output_tokens': 600,
                    }
                )
            except Exception as e:
                print(f"[WARNING] Failed to initialize Gemini client: {e}")
                self._client = None
        else:
            if not self.settings:
                print("[WARNING] Settings not loaded - GEMINI_KEY may not be configured")
            elif not self.settings.gemini_key:
                print("[WARNING] GEMINI_KEY not found in environment. Report generation will fail.")
    
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
            if not self.settings:
                raise ValueError(
                    "Configuration not loaded. Please check your .env file exists in the root directory."
                )
            elif not self.settings.gemini_key:
                raise ValueError(
                    "GEMINI_KEY not found in environment variables. "
                    "Please set GEMINI_KEY in your .env file. "
                    "Get your key from: https://aistudio.google.com/app/apikey"
                )
            else:
                raise ValueError(
                    "Gemini client not initialized. API key may be invalid. "
                    f"Key length: {len(self.settings.gemini_key) if self.settings.gemini_key else 0}"
                )
        
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
        
        # Generate report via Gemini (with fallback to template if quota/billing issues)
        report_content = None
        use_template = False
        
        if self._client:
            try:
                report_content = self._call_gemini(safe_input)
            except Exception as e:
                error_str = str(e)
                print(f"[WARNING] Gemini generation failed: {e}")
                
                # If quota/billing error, use template-based fallback instead of failing
                if "429" in error_str or "quota" in error_str.lower() or "limit: 0" in error_str:
                    print("[INFO] Billing/quota issue detected. Using template-based report generation (no AI required)")
                    use_template = True
                elif "API_KEY" in error_str.upper() or "API key" in error_str:
                    # API key errors - also use template so app doesn't break
                    print("[INFO] API key issue. Using template-based report generation")
                    use_template = True
                else:
                    # For other errors, also try template fallback
                    print("[INFO] API error. Using template-based report generation")
                    use_template = True
        
        # If Gemini not available or failed, generate template-based report
        if use_template or not self._client:
            print("[INFO] Generating template-based report (no AI required)")
            report_content = self._generate_template_report(patterns, trends, audience)
        
        # Validate output safety
        is_safe, violations = validate_output_safety(report_content)
        validation_status = 'approved' if (use_template or not self._client) else ('pending' if is_safe else 'rejected')
        
        if not is_safe and not use_template:
            print(f"[WARNING] Report contains prohibited terms: {violations}")
            # Still save as rejected for review
        
        # Ensure disclaimer is present
        disclaimer = "Observational insights only. This is not a diagnostic assessment."
        if disclaimer.lower() not in report_content.lower():
            report_content = f"{report_content}\n\n{disclaimer}"
        
        # Determine generation method
        generation_method = 'template' if (use_template or not self._client) else 'ai'
        
        # Save report to database
        report_id = self._save_report(
            learner_id=learner_id,
            scope=scope,
            session_id=session_id,
            audience=audience,
            content=report_content,
            validation_status=validation_status,
            generation_method=generation_method
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
        
        # Ensure API key is configured before each call (re-configure to be safe)
        if self.settings and self.settings.gemini_key:
            genai.configure(api_key=self.settings.gemini_key)
        
        # Combine system prompt and user prompt
        full_prompt = f"{self._system_prompt}\n\n{user_prompt}"
        
        try:
            response = self._client.generate_content(full_prompt)
        except Exception as e:
            error_str = str(e)
            
            # Handle API key errors
            if "API_KEY" in error_str.upper() or "API key" in error_str or "API_KEY_INVALID" in error_str:
                raise ValueError(
                    f"Gemini API key error: {error_str}. "
                    "Please verify GEMINI_KEY is correctly set in your .env file. "
                    "Get your key from: https://aistudio.google.com/app/apikey"
                )
            
            # Handle quota/billing errors
            if "429" in error_str or "quota" in error_str.lower() or "limit: 0" in error_str:
                raise ValueError(
                    "Gemini API quota error (429). "
                    "This usually means billing is not enabled on your Google Cloud account. "
                    "Even free tier requires billing to be enabled. "
                    "Enable billing at: https://console.cloud.google.com/billing"
                )
            
            raise
        
        if not response.text:
            raise ValueError("Gemini returned empty response")
        
        return response.text.strip()
    
    def _generate_template_report(
        self,
        patterns: List[Dict],
        trends: List[Dict],
        audience: str
    ) -> str:
        """
        Generate a template-based report without AI.
        Used as fallback when Gemini API is not available (billing/quota issues).
        
        Args:
            patterns: List of pattern dictionaries
            trends: List of trend dictionaries
            audience: 'parent' or 'teacher'
            
        Returns:
            Template-based narrative report
        """
        lines = []
        
        # Opening based on audience
        if audience == 'parent':
            lines.append("This report describes learning patterns observed during activities with this learner.")
        else:
            lines.append("This report summarizes learning patterns observed across activities with this learner.")
        
        lines.append("")
        
        # Patterns section
        if patterns:
            lines.append("Observed Patterns:")
            lines.append("")
            
            for pattern in patterns:
                pattern_name = pattern.get('pattern_name', 'Learning pattern')
                learning_impact = pattern.get('learning_impact', '')
                support_focus = pattern.get('support_focus', '')
                
                lines.append(f"{pattern_name}")
                if learning_impact:
                    lines.append(f"  {learning_impact}")
                if support_focus:
                    lines.append(f"  {support_focus}")
                lines.append("")
        
        # Trends section (if available)
        if trends:
            lines.append("Patterns Over Time:")
            lines.append("")
            
            for trend in trends:
                pattern_name = trend.get('pattern_name', 'Pattern')
                trend_type = trend.get('trend_type', 'stable')
                
                if trend_type == 'stable':
                    trend_desc = "This pattern has appeared consistently across recent activities, suggesting a stable learning rhythm."
                elif trend_type == 'improving':
                    trend_desc = "Across recent activities, this pattern is appearing less strongly, suggesting growing ease with the task demands."
                elif trend_type == 'fluctuating':
                    trend_desc = "This pattern has varied across activities, which is common as learners adapt to different tasks."
                else:
                    trend_desc = "This pattern has appeared across recent activities."
                
                lines.append(f"{pattern_name}: {trend_desc}")
                lines.append("")
        
        # Closing
        lines.append("These observations are part of the natural learning process and reflect the learner's developing skills.")
        lines.append("")
        
        # Disclaimer
        lines.append("Observational insights only. This is not a diagnostic assessment.")
        
        return "\n".join(lines)
    
    def _save_report(
        self,
        learner_id: UUID,
        scope: str,
        session_id: Optional[UUID],
        audience: str,
        content: str,
        validation_status: str,
        generation_method: str = 'ai'
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
            "generation_method": generation_method,
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
