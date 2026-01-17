#!/usr/bin/env python3
"""
Test script to list all available Gemini models using the configured API key.
This helps identify which model names are supported for generateContent.
"""

import os
import sys
from pathlib import Path
from dotenv import load_dotenv

# Load environment variables
load_dotenv(Path(__file__).parent.parent.parent / '.env')

try:
    import google.generativeai as genai
except ImportError:
    print("❌ ERROR: google.generativeai package not installed")
    print("   Install with: pip install google-generativeai")
    sys.exit(1)


def list_available_models():
    """List all available Gemini models for the configured API key."""
    
    # Get API key from environment
    gemini_key = os.getenv('GEMINI_KEY')
    
    if not gemini_key:
        print("❌ ERROR: GEMINI_KEY not found in environment")
        print("   Please set GEMINI_KEY in your .env file")
        sys.exit(1)
    
    if gemini_key.startswith('YOUR_') or len(gemini_key) < 10:
        print("❌ ERROR: GEMINI_KEY appears to be a placeholder")
        print("   Please set a valid GEMINI_KEY in your .env file")
        sys.exit(1)
    
    print("=" * 80)
    print("Gemini API - Available Models")
    print("=" * 80)
    print(f"\nAPI Key: {gemini_key[:10]}...{gemini_key[-5:]}\n")
    
    try:
        # Configure API
        genai.configure(api_key=gemini_key)
        
        # List all models
        print("Fetching available models...\n")
        models = genai.list_models()
        
        if not models:
            print("❌ No models found")
            return
        
        # Group models by support for generateContent
        models_with_generate = []
        models_other = []
        
        for model in models:
            model_info = {
                'name': model.name,
                'display_name': getattr(model, 'display_name', 'N/A'),
                'supported_methods': list(model.supported_generation_methods) if hasattr(model, 'supported_generation_methods') else [],
            }
            
            if 'generateContent' in model_info['supported_methods']:
                models_with_generate.append(model_info)
            else:
                models_other.append(model_info)
        
        # Display models that support generateContent (these are what we need)
        print("=" * 80)
        print("MODELS SUPPORTING generateContent (USE THESE)")
        print("=" * 80)
        
        if models_with_generate:
            for model in models_with_generate:
                print(f"\n✅ {model['name']}")
                print(f"   Display Name: {model['display_name']}")
                print(f"   Methods: {', '.join(model['supported_methods'])}")
                
                # Extract short model name (e.g., 'gemini-pro' from 'models/gemini-pro')
                short_name = model['name'].replace('models/', '')
                print(f"   Short Name: '{short_name}'")
        else:
            print("\n❌ No models found that support generateContent")
        
        # Display other models (for reference)
        if models_other:
            print("\n" + "=" * 80)
            print("OTHER MODELS (do not support generateContent)")
            print("=" * 80)
            for model in models_other[:5]:  # Show first 5
                print(f"\n  {model['name']}")
                print(f"    Methods: {', '.join(model['supported_methods']) if model['supported_methods'] else 'None'}")
            
            if len(models_other) > 5:
                print(f"\n  ... and {len(models_other) - 5} more")
        
        # Summary and recommendations
        print("\n" + "=" * 80)
        print("RECOMMENDATIONS")
        print("=" * 80)
        
        if models_with_generate:
            # Look for preferred models
            preferred_names = ['gemini-pro', 'gemini-1.5-pro', 'gemini-1.0-pro', 'models/gemini-pro']
            found_preferred = []
            
            for model in models_with_generate:
                short_name = model['name'].replace('models/', '')
                if any(pref in model['name'] for pref in preferred_names):
                    found_preferred.append(short_name)
            
            if found_preferred:
                print(f"\n✅ Recommended model(s): {', '.join(found_preferred[:3])}")
                print(f"   Use the short name in GenerativeModel: '{found_preferred[0]}'")
            else:
                # Use first available model
                first_model = models_with_generate[0]['name'].replace('models/', '')
                print(f"\n✅ Use first available model: '{first_model}'")
                print(f"   Update your code to use: genai.GenerativeModel('{first_model}')")
        
        print("\n" + "=" * 80)
        print(f"Models supporting generateContent: {len(models_with_generate)}")
        print("=" * 80 + "\n")
        
    except Exception as e:
        print(f"\n❌ ERROR: {type(e).__name__}: {str(e)}\n")
        
        if "API key" in str(e).lower() or "invalid" in str(e).lower():
            print("   This usually means:")
            print("   - API key is invalid or expired")
            print("   - API key doesn't have required permissions")
            print("   - Check your .env file for GEMINI_KEY")
        
        sys.exit(1)


if __name__ == '__main__':
    list_available_models()
