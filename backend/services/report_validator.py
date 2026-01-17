# =============================================================================
# REPORT VALIDATOR SERVICE
# Phase 3.2: AI Report Validation with RAG
# Validates, constrains, and rewrites reports generated in Phase 3.1
# =============================================================================
#
# CRITICAL: This is a governance layer, NOT an intelligence layer.
# The validator does NOT add insights or infer patterns.
# It only ensures compliance with language and safety rules.
#
# RAG Corpus: Static files containing constraints and examples
# - forbidden_terms.txt
# - allowed_phrasing.txt
# - structure_rules.txt
# - example_safe_reports.md
#
# =============================================================================

import os
from pathlib import Path
from typing import Dict, Optional, Tuple
from uuid import UUID
import google.generativeai as genai

from ..config import get_settings_dev
from ..db.supabase import get_supabase_admin
from ..utils.safety_filters import validate_output_safety


class ReportValidator:
    """
    Gemini-based report validator.
    
    Reviews AI-generated reports and ensures compliance with
    non-diagnostic, non-clinical language rules.
    """
    
    def __init__(self):
        """Initialize the report validator."""
        self.settings = get_settings_dev()
        self._client = None
        self._system_prompt = None
        self._rag_corpus = {}
        
        # Load static system prompt
        self._load_system_prompt()
        
        # Load RAG corpus
        self._load_rag_corpus()
        
        # Initialize Gemini client if key is available
        if self.settings and self.settings.gemini_key:
            genai.configure(api_key=self.settings.gemini_key)
            # Use same model as generator for consistency
            model_name = 'gemini-flash-latest'
            self._client = genai.GenerativeModel(
                model_name,  # Try latest Flash model (may have better free tier support)
                generation_config={
                    'temperature': 0.1,  # Very low temperature for strict validation
                    'max_output_tokens': 800,
                }
            )
    
    def _load_system_prompt(self) -> None:
        """Load static system prompt from file."""
        try:
            current_dir = Path(__file__).parent
            prompt_file = current_dir / 'prompts' / 'gemini_report_validator.txt'
            
            if prompt_file.exists():
                with open(prompt_file, 'r', encoding='utf-8') as f:
                    self._system_prompt = f.read().strip()
            else:
                self._system_prompt = self._get_fallback_prompt()
        except Exception as e:
            print(f"[WARNING] Could not load validator prompt: {e}")
            self._system_prompt = self._get_fallback_prompt()
    
    def _get_fallback_prompt(self) -> str:
        """Fallback prompt if file cannot be loaded."""
        return """You are a language validator for educational reports.
Review reports and ensure they comply with non-diagnostic language rules.
Return STATUS: APPROVED, STATUS: REWRITTEN, or STATUS: REJECTED.
"""
    
    def _load_rag_corpus(self) -> None:
        """Load RAG corpus files (static constraints)."""
        current_dir = Path(__file__).parent
        rag_dir = current_dir / 'rag_corpus'
        
        corpus_files = {
            'forbidden_terms': 'forbidden_terms.txt',
            'allowed_phrasing': 'allowed_phrasing.txt',
            'structure_rules': 'structure_rules.txt',
            'example_reports': 'example_safe_reports.md',
        }
        
        for key, filename in corpus_files.items():
            file_path = rag_dir / filename
            try:
                if file_path.exists():
                    with open(file_path, 'r', encoding='utf-8') as f:
                        self._rag_corpus[key] = f.read().strip()
                else:
                    print(f"[WARNING] RAG corpus file not found: {file_path}")
                    self._rag_corpus[key] = ""
            except Exception as e:
                print(f"[WARNING] Could not load RAG corpus {key}: {e}")
                self._rag_corpus[key] = ""
    
    def validate_report(self, report_id: UUID) -> Dict:
        """
        Validate a generated report.
        
        Args:
            report_id: UUID of the report to validate
            
        Returns:
            Dict with status and updated content (if rewritten)
        """
        if not self._client:
            # If Gemini not available, use basic safety filter only
            return self._basic_validation(report_id)
        
        # Load report from database
        report = self._load_report(report_id)
        if not report:
            raise ValueError(f"Report {report_id} not found")
        
        content = report.get('content', '')
        if not content:
            raise ValueError("Report content is empty")
        
        # Build validation prompt with RAG context
        validation_prompt = self._build_validation_prompt(content)
        
        # Call Gemini validator
        try:
            response = self._call_validator(validation_prompt)
        except Exception as e:
            print(f"[ERROR] Validator call failed: {e}")
            # Fallback to basic validation
            return self._basic_validation(report_id)
        
        # Parse response
        status, updated_content = self._parse_validator_response(response, content)
        
        # Update report in database
        self._update_report(report_id, status, updated_content)
        
        return {
            "report_id": str(report_id),
            "status": status,
            "content_updated": status == "rewritten"
        }
    
    def _load_report(self, report_id: UUID) -> Optional[Dict]:
        """Load report from database."""
        supabase = get_supabase_admin()
        if not supabase:
            return None
        
        result = supabase.table("reports").select("*").eq(
            "report_id", str(report_id)
        ).execute()
        
        if result.data and len(result.data) > 0:
            return result.data[0]
        return None
    
    def _build_validation_prompt(self, report_content: str) -> str:
        """
        Build validation prompt with RAG corpus context.
        
        Includes:
        - Forbidden terms list
        - Allowed phrasing examples
        - Structure rules
        - Example safe reports
        """
        lines = []
        
        lines.append("=== RAG CORPUS: FORBIDDEN TERMS ===")
        lines.append(self._rag_corpus.get('forbidden_terms', ''))
        lines.append("")
        
        lines.append("=== RAG CORPUS: ALLOWED PHRASING ===")
        lines.append(self._rag_corpus.get('allowed_phrasing', ''))
        lines.append("")
        
        lines.append("=== RAG CORPUS: STRUCTURE RULES ===")
        lines.append(self._rag_corpus.get('structure_rules', ''))
        lines.append("")
        
        lines.append("=== RAG CORPUS: EXAMPLE SAFE REPORTS ===")
        lines.append(self._rag_corpus.get('example_reports', ''))
        lines.append("")
        
        lines.append("=== REPORT TO VALIDATE ===")
        lines.append(report_content)
        lines.append("")
        
        lines.append("Review the report above against the constraints and examples.")
        lines.append("Return STATUS: APPROVED, STATUS: REWRITTEN, or STATUS: REJECTED.")
        lines.append("If REWRITTEN, provide the corrected report text.")
        lines.append("If REJECTED, provide a brief reason.")
        
        return "\n".join(lines)
    
    def _call_validator(self, prompt: str) -> str:
        """Call Gemini validator model."""
        if not self._client:
            raise ValueError("Gemini client not initialized")
        
        # Combine system prompt and validation prompt
        full_prompt = f"{self._system_prompt}\n\n{prompt}"
        
        response = self._client.generate_content(full_prompt)
        
        if not response.text:
            raise ValueError("Validator returned empty response")
        
        return response.text.strip()
    
    def _parse_validator_response(
        self,
        response: str,
        original_content: str
    ) -> Tuple[str, Optional[str]]:
        """
        Parse validator response.
        
        Returns:
            Tuple of (status, updated_content)
            status: 'approved', 'rewritten', or 'rejected'
            updated_content: new content if rewritten, None otherwise
        """
        response_lower = response.lower()
        
        # Check for status indicators
        if 'status: approved' in response_lower:
            return ('approved', None)
        elif 'status: rewritten' in response_lower:
            # Extract rewritten content (everything after STATUS: REWRITTEN)
            parts = response.split('STATUS: REWRITTEN', 1)
            if len(parts) > 1:
                rewritten = parts[1].strip()
                # Remove any trailing status indicators
                rewritten = rewritten.split('STATUS:')[0].strip()
                return ('rewritten', rewritten)
            else:
                # Fallback: use original if parsing fails
                return ('approved', None)
        elif 'status: rejected' in response_lower:
            # Fallback to static template report when rejected
            fallback_content = self._generate_fallback_report(original_content)
            # Mark as rewritten with template (not rejected) so user still gets a report
            return ('rewritten', fallback_content)
        else:
            # Default: approved if unclear
            print(f"[WARNING] Unclear validator response, defaulting to approved")
            return ('approved', None)
    
    def _update_report(
        self,
        report_id: UUID,
        status: str,
        updated_content: Optional[str]
    ) -> None:
        """Update report validation status and content in database."""
        supabase = get_supabase_admin()
        if not supabase:
            raise ValueError("Database connection unavailable")
        
        update_data = {
            "validation_status": status
        }
        
        if updated_content:
            update_data["content"] = updated_content
        
        supabase.table("reports").update(update_data).eq(
            "report_id", str(report_id)
        ).execute()
    
    def _generate_fallback_report(self, original_content: str) -> str:
        """
        Generate a safe template report when validation rejects the original.
        This ensures users always get a report, even if AI generation fails.
        """
        return """The learner has engaged in learning activities, and patterns of 
engagement have been observed. These patterns are part of the natural learning 
process and reflect the learner's developing skills.

Supportive approaches that may help include providing structured routines and 
allowing for natural breaks during activities. These approaches can help 
maintain engagement while respecting the learner's natural rhythm.

Observational insights only. This is not a diagnostic assessment."""
    
    def _basic_validation(self, report_id: UUID) -> Dict:
        """
        Basic validation using safety filters only.
        Used when Gemini is not available.
        """
        report = self._load_report(report_id)
        if not report:
            raise ValueError(f"Report {report_id} not found")
        
        content = report.get('content', '')
        is_safe, violations = validate_output_safety(content)
        
        status = 'approved' if is_safe else 'rejected'
        self._update_report(report_id, status, None)
        
        return {
            "report_id": str(report_id),
            "status": status,
            "content_updated": False
        }


# Singleton instance
_report_validator: Optional[ReportValidator] = None


def get_report_validator() -> ReportValidator:
    """Get or create report validator instance."""
    global _report_validator
    if _report_validator is None:
        _report_validator = ReportValidator()
    return _report_validator
