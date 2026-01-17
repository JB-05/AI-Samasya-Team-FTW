# =============================================================================
# GEMINI MODEL GUARD
# Validates Gemini model availability on startup
# Fails fast if required model is not available
# =============================================================================

import sys
from typing import Optional
import google.generativeai as genai

from ..config import get_settings_dev


def validate_gemini_model(model_name: str = 'gemini-2.0-flash') -> bool:
    """
    Validate that the specified Gemini model is available.
    
    Args:
        model_name: The model name to validate (e.g., 'gemini-pro')
        
    Returns:
        True if model is available, False otherwise
        
    Raises:
        SystemExit: If model validation fails and fail-fast is enabled
    """
    settings = get_settings_dev()
    
    if not settings or not settings.gemini_key:
        # Gemini key not configured - model validation skipped
        print(f"[INFO] Gemini API key not configured - skipping model validation")
        return False
    
    try:
        genai.configure(api_key=settings.gemini_key)
        
        # List available models
        available_models = genai.list_models()
        model_names = [model.name for model in available_models]
        
        # Check if our target model is in the list
        target_model_full = f'models/{model_name}'
        model_available = any(
            target_model_full in name or model_name in name 
            for name in model_names
        )
        
        if model_available:
            print(f"[OK] Gemini model '{model_name}' is available")
            return True
        else:
            print(f"\n{'=' * 70}")
            print(f"❌ GEMINI MODEL NOT FOUND")
            print(f"{'=' * 70}")
            print(f"\nRequired model: {model_name}")
            print(f"\nAvailable models:")
            for name in model_names[:10]:  # Show first 10
                print(f"  - {name}")
            if len(model_names) > 10:
                print(f"  ... and {len(model_names) - 10} more")
            print(f"\n{'=' * 70}\n")
            return False
            
    except Exception as e:
        print(f"[WARNING] Could not validate Gemini model: {e}")
        return False


def validate_gemini_on_startup(fail_fast: bool = False) -> bool:
    """
    Validate Gemini model availability on application startup.
    
    Args:
        fail_fast: If True, exit application if model is unavailable
        
    Returns:
        True if model is available, False otherwise
    """
    is_available = validate_gemini_model('gemini-2.0-flash')
    
    if not is_available and fail_fast:
        print("\n⚠️  Gemini model validation failed. Exiting...\n")
        sys.exit(1)
    
    return is_available


if __name__ == '__main__':
    # Standalone validation
    validate_gemini_model('gemini-2.0-flash')
