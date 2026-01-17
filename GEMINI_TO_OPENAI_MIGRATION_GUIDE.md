# Gemini → OpenAI API Migration Guide

**Status:** Analysis Only - No Changes Made  
**Date:** 2025-01-17  
**Purpose:** Document all changes required to switch from Gemini API to OpenAI API

---

## Overview

This guide lists all changes needed to replace Google Gemini API with OpenAI API for report generation and validation. The core logic, safety constraints, and prompt structure remain the same—only the API client implementation changes.

---

## 1. DEPENDENCIES (`requirements.txt`)

### Remove:
```
google-generativeai>=0.1.0
```

### Add:
```
openai>=1.0.0
```

**Action:** Update `requirements.txt`, then run `pip install -r requirements.txt`

---

## 2. ENVIRONMENT CONFIGURATION (`.env` / `backend/env.example`)

### Change:
```
# OLD:
GEMINI_KEY=your-gemini-api-key

# NEW:
OPENAI_API_KEY=your-openai-api-key
```

### Files to update:
- `backend/env.example` (line 13)
- `.env` file (actual API key)

**Action:** Rename environment variable from `GEMINI_KEY` to `OPENAI_API_KEY`

---

## 3. CONFIGURATION (`backend/config.py`)

### Change in `Settings` class:

**OLD (lines 36-37, 67-73):**
```python
# Gemini API Configuration (OPTIONAL - for AI explanations)
gemini_key: Optional[str] = Field(None, alias="GEMINI_KEY")

@field_validator('gemini_key')
@classmethod
def validate_gemini_key(cls, v: Optional[str]) -> Optional[str]:
    """Gemini key is optional - used for AI explanations only."""
    if v and v.startswith('YOUR_'):
        return None  # Treat placeholder as missing
    return v
```

**NEW:**
```python
# OpenAI API Configuration (OPTIONAL - for AI explanations)
openai_api_key: Optional[str] = Field(None, alias="OPENAI_API_KEY")

@field_validator('openai_api_key')
@classmethod
def validate_openai_key(cls, v: Optional[str]) -> Optional[str]:
    """OpenAI key is optional - used for AI explanations only."""
    if v and v.startswith('YOUR_'):
        return None  # Treat placeholder as missing
    return v
```

### Update help text:
- Line 21: Change `GEMINI_KEY` to `OPENAI_API_KEY`
- Line 99: Update in error messages

**Action:** Replace all references to `gemini_key` with `openai_api_key`

---

## 4. REPORT GENERATOR (`backend/services/report_generator.py`)

### A. Imports (line 19)

**OLD:**
```python
import google.generativeai as genai
```

**NEW:**
```python
from openai import OpenAI
```

### B. Class docstring (lines 26-32)

**OLD:**
```python
"""
Gemini-based report generator.
"""
```

**NEW:**
```python
"""
OpenAI-based report generator.
"""
```

### C. `__init__` method (lines 43-69)

**OLD:**
```python
# Initialize Gemini client if key is available
if self.settings and self.settings.gemini_key:
    # Validate API key format
    if not self.settings.gemini_key or len(self.settings.gemini_key) < 10:
        print("[WARNING] GEMINI_KEY appears invalid (too short or empty)")
        return
    
    try:
        genai.configure(api_key=self.settings.gemini_key)
        model_name = 'gemini-flash-latest'
        self._client = genai.GenerativeModel(
            model_name,
            generation_config={
                'temperature': 0.25,
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
```

**NEW:**
```python
# Initialize OpenAI client if key is available
if self.settings and self.settings.openai_api_key:
    # Validate API key format
    if not self.settings.openai_api_key or len(self.settings.openai_api_key) < 20:
        print("[WARNING] OPENAI_API_KEY appears invalid (too short or empty)")
        return
    
    try:
        self._client = OpenAI(api_key=self.settings.openai_api_key)
        self._model_name = 'gpt-4o-mini'  # Or 'gpt-3.5-turbo' for cheaper option
        self._temperature = 0.25
        self._max_tokens = 600
    except Exception as e:
        print(f"[WARNING] Failed to initialize OpenAI client: {e}")
        self._client = None
else:
    if not self.settings:
        print("[WARNING] Settings not loaded - OPENAI_API_KEY may not be configured")
    elif not self.settings.openai_api_key:
        print("[WARNING] OPENAI_API_KEY not found in environment. Report generation will fail.")
```

### D. `generate_report` method (lines 115-130)

**OLD:**
```python
if not self._client:
    if not self.settings:
        raise ValueError("Configuration not loaded...")
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
```

**NEW:**
```python
if not self._client:
    if not self.settings:
        raise ValueError("Configuration not loaded...")
    elif not self.settings.openai_api_key:
        raise ValueError(
            "OPENAI_API_KEY not found in environment variables. "
            "Please set OPENAI_API_KEY in your .env file. "
            "Get your key from: https://platform.openai.com/api-keys"
        )
    else:
        raise ValueError(
            "OpenAI client not initialized. API key may be invalid. "
            f"Key length: {len(self.settings.openai_api_key) if self.settings.openai_api_key else 0}"
        )
```

### E. `_call_gemini` method → Rename to `_call_openai` (lines 294-339)

**OLD:**
```python
def _call_gemini(self, user_prompt: str) -> str:
    if not self._client:
        raise ValueError("Gemini client not initialized")
    
    if self.settings and self.settings.gemini_key:
        genai.configure(api_key=self.settings.gemini_key)
    
    full_prompt = f"{self._system_prompt}\n\n{user_prompt}"
    
    try:
        response = self._client.generate_content(full_prompt)
    except Exception as e:
        error_str = str(e)
        if "API_KEY" in error_str.upper() or "API key" in error_str:
            raise ValueError(f"Gemini API key error: {error_str}...")
        if "429" in error_str or "quota" in error_str.lower():
            raise ValueError("Gemini API quota error (429)...")
        raise
    
    if not response.text:
        raise ValueError("Gemini returned empty response")
    
    return response.text.strip()
```

**NEW:**
```python
def _call_openai(self, user_prompt: str) -> str:
    if not self._client:
        raise ValueError("OpenAI client not initialized")
    
    full_prompt = f"{self._system_prompt}\n\n{user_prompt}"
    
    try:
        response = self._client.chat.completions.create(
            model=self._model_name,
            messages=[
                {"role": "system", "content": self._system_prompt},
                {"role": "user", "content": user_prompt}
            ],
            temperature=self._temperature,
            max_tokens=self._max_tokens
        )
    except Exception as e:
        error_str = str(e)
        if "API key" in error_str or "invalid_api_key" in error_str.lower():
            raise ValueError(
                f"OpenAI API key error: {error_str}. "
                "Please verify OPENAI_API_KEY is correctly set in your .env file. "
                "Get your key from: https://platform.openai.com/api-keys"
            )
        if "429" in error_str or "rate_limit" in error_str.lower() or "quota" in error_str.lower():
            raise ValueError(
                "OpenAI API quota/rate limit error (429). "
                "Check your OpenAI account limits and billing status."
            )
        raise
    
    if not response.choices or not response.choices[0].message.content:
        raise ValueError("OpenAI returned empty response")
    
    return response.choices[0].message.content.strip()
```

### F. Update method calls (line 152)

**OLD:**
```python
report_content = self._call_gemini(safe_input)
```

**NEW:**
```python
report_content = self._call_openai(safe_input)
```

### G. Update comments and error messages

- Line 3: `Gemini-based` → `OpenAI-based`
- Line 8: `Gemini receives` → `OpenAI receives`
- Line 143: `Build safe input for Gemini` → `Build safe input for OpenAI`
- Line 146: `Generate report via Gemini` → `Generate report via OpenAI`
- All error messages mentioning "Gemini" → "OpenAI"

---

## 5. REPORT VALIDATOR (`backend/services/report_validator.py`)

### A. Imports (line 23)

**OLD:**
```python
import google.generativeai as genai
```

**NEW:**
```python
from openai import OpenAI
```

### B. Class docstring (lines 30-36)

**OLD:**
```python
"""
Gemini-based report validator.
"""
```

**NEW:**
```python
"""
OpenAI-based report validator.
"""
```

### C. `__init__` method (lines 51-62)

**OLD:**
```python
if self.settings and self.settings.gemini_key:
    genai.configure(api_key=self.settings.gemini_key)
    model_name = 'gemini-flash-latest'
    self._client = genai.GenerativeModel(
        model_name,
        generation_config={
            'temperature': 0.1,
            'max_output_tokens': 800,
        }
    )
```

**NEW:**
```python
if self.settings and self.settings.openai_api_key:
    self._client = OpenAI(api_key=self.settings.openai_api_key)
    self._model_name = 'gpt-4o-mini'  # Or 'gpt-3.5-turbo'
    self._temperature = 0.1
    self._max_tokens = 800
```

### D. `validate_report` method (line 121)

**OLD:**
```python
if not self._client:
    # If Gemini not available, use basic safety filter only
    return self._basic_validation(report_id)
```

**NEW:**
```python
if not self._client:
    # If OpenAI not available, use basic safety filter only
    return self._basic_validation(report_id)
```

### E. `_call_validator` method → Update API call (lines 208-221)

**OLD:**
```python
def _call_validator(self, prompt: str) -> str:
    if not self._client:
        raise ValueError("Gemini client not initialized")
    
    full_prompt = f"{self._system_prompt}\n\n{prompt}"
    
    response = self._client.generate_content(full_prompt)
    
    if not response.text:
        raise ValueError("Validator returned empty response")
    
    return response.text.strip()
```

**NEW:**
```python
def _call_validator(self, prompt: str) -> str:
    if not self._client:
        raise ValueError("OpenAI client not initialized")
    
    try:
        response = self._client.chat.completions.create(
            model=self._model_name,
            messages=[
                {"role": "system", "content": self._system_prompt},
                {"role": "user", "content": prompt}
            ],
            temperature=self._temperature,
            max_tokens=self._max_tokens
        )
    except Exception as e:
        error_str = str(e)
        if "API key" in error_str or "invalid_api_key" in error_str.lower():
            raise ValueError(f"OpenAI API key error: {error_str}")
        if "429" in error_str or "rate_limit" in error_str.lower():
            raise ValueError("OpenAI API quota/rate limit error (429)")
        raise
    
    if not response.choices or not response.choices[0].message.content:
        raise ValueError("Validator returned empty response")
    
    return response.choices[0].message.content.strip()
```

### F. Update comments

- Line 32: `Gemini-based` → `OpenAI-based`
- Line 137: `Call Gemini validator` → `Call OpenAI validator`
- All references to "Gemini" → "OpenAI"

---

## 6. PROMPT FILES (Optional - Keep Same)

### Files:
- `backend/services/prompts/gemini_report_generator.txt`
- `backend/services/prompts/gemini_report_validator.txt`

### Change:
**Option A:** Keep file names (content is model-agnostic)  
**Option B:** Rename for clarity:
- `gemini_report_generator.txt` → `openai_report_generator.txt`
- `gemini_report_validator.txt` → `openai_report_validator.txt`

**Action:** If renaming, update file paths in `_load_system_prompt()` methods

---

## 7. UTILITIES (`backend/utils/gemini_guard.py`)

### Options:

**Option A:** Delete file (no longer needed)  
**Option B:** Rename to `openai_guard.py` and update:

**OLD:**
```python
import google.generativeai as genai
from ..config import get_settings_dev

def validate_gemini_model(model_name: str = 'gemini-2.0-flash') -> bool:
    settings = get_settings_dev()
    if not settings or not settings.gemini_key:
        ...
    genai.configure(api_key=settings.gemini_key)
    models = genai.list_models()
    ...
```

**NEW:**
```python
from openai import OpenAI
from ..config import get_settings_dev

def validate_openai_model(model_name: str = 'gpt-4o-mini') -> bool:
    settings = get_settings_dev()
    if not settings or not settings.openai_api_key:
        ...
    client = OpenAI(api_key=settings.openai_api_key)
    # OpenAI doesn't have list_models() - just verify key works
    try:
        client.models.list()
        return True
    except Exception:
        return False
```

**Action:** Delete or refactor `gemini_guard.py`

---

## 8. TEST FILES

### A. `backend/tests/test_gemini_models.py`

**Action:** Delete or rename to `test_openai_models.py` with updated code:

**NEW:**
```python
from openai import OpenAI
import os
from dotenv import load_dotenv

def list_available_models():
    openai_key = os.getenv('OPENAI_API_KEY')
    if not openai_key:
        print("❌ ERROR: OPENAI_API_KEY not found")
        return
    
    client = OpenAI(api_key=openai_key)
    
    # OpenAI API doesn't expose model list easily - just test connection
    try:
        response = client.chat.completions.create(
            model='gpt-4o-mini',
            messages=[{"role": "user", "content": "test"}],
            max_tokens=1
        )
        print("✅ OpenAI API connection successful")
    except Exception as e:
        print(f"❌ ERROR: {e}")
```

### B. `backend/tests/e2e_test.py` (line 30)

**OLD:**
```python
GEMINI_KEY = os.getenv('GEMINI_KEY', '')
```

**NEW:**
```python
OPENAI_API_KEY = os.getenv('OPENAI_API_KEY', '')
```

---

## 9. ROUTES (`backend/routes/reports_generate.py`)

### Update docstring (line 3, 45-48)

**OLD:**
```python
# Phase 3.1: AI Report Generation via Gemini
"""
Generate a narrative report using Gemini AI.
"""
```

**NEW:**
```python
# Phase 3.1: AI Report Generation via OpenAI
"""
Generate a narrative report using OpenAI API.
"""
```

---

## 10. HEALTH CHECK (`backend/routes/health.py`)

### Update (line 49)

**OLD:**
```python
"required_vars": ["SUPABASE_URL", "SUPABASE_ANON_KEY", "GEMINI_KEY"],
```

**NEW:**
```python
"required_vars": ["SUPABASE_URL", "SUPABASE_ANON_KEY", "OPENAI_API_KEY"],
```

---

## 11. MAIN APP (`backend/main.py`)

### Update description (if mentions Gemini)

**Action:** Search for "Gemini" and update to "OpenAI" in documentation strings

---

## Summary of Changes

| Category | Files to Change | Key Changes |
|----------|----------------|-------------|
| **Dependencies** | `requirements.txt` | Replace `google-generativeai` with `openai` |
| **Environment** | `.env`, `backend/env.example` | `GEMINI_KEY` → `OPENAI_API_KEY` |
| **Config** | `backend/config.py` | `gemini_key` → `openai_api_key` |
| **Generator** | `backend/services/report_generator.py` | Replace `genai.GenerativeModel()` with `OpenAI().chat.completions.create()` |
| **Validator** | `backend/services/report_validator.py` | Same API change as generator |
| **Utilities** | `backend/utils/gemini_guard.py` | Delete or refactor |
| **Tests** | `backend/tests/test_gemini_models.py`, `e2e_test.py` | Update or delete |
| **Routes** | `backend/routes/reports_generate.py`, `health.py` | Update docstrings and references |
| **Prompts** | `backend/services/prompts/*.txt` | Optional: rename files |

---

## API Differences: Gemini vs OpenAI

### Gemini API (Current):
```python
import google.generativeai as genai

genai.configure(api_key=key)
model = genai.GenerativeModel('gemini-flash-latest')
response = model.generate_content(prompt)
content = response.text
```

### OpenAI API (New):
```python
from openai import OpenAI

client = OpenAI(api_key=key)
response = client.chat.completions.create(
    model='gpt-4o-mini',
    messages=[
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_prompt}
    ],
    temperature=0.25,
    max_tokens=600
)
content = response.choices[0].message.content
```

### Key Differences:
1. **Initialization:** OpenAI doesn't need `configure()`, just pass key to constructor
2. **Models:** Gemini uses string model names, OpenAI also uses strings (`gpt-4o-mini`, `gpt-3.5-turbo`)
3. **API Format:** Gemini uses `generate_content(prompt)`, OpenAI uses `chat.completions.create()` with messages array
4. **Response:** Gemini returns `response.text`, OpenAI returns `response.choices[0].message.content`
5. **System Prompts:** Gemini concatenates system + user, OpenAI uses separate message roles
6. **Config:** Gemini uses `generation_config={}`, OpenAI uses direct parameters

---

## Recommended OpenAI Models

| Use Case | Recommended Model | Why |
|----------|------------------|-----|
| **Report Generation** | `gpt-4o-mini` | Good quality, cost-effective |
| **Report Validation** | `gpt-4o-mini` | Same model for consistency |
| **Budget Option** | `gpt-3.5-turbo` | Cheaper, still effective |

**Temperature Settings (Keep Same):**
- Generator: `0.25`
- Validator: `0.1`

---

## Migration Checklist

- [ ] Update `requirements.txt`
- [ ] Run `pip install openai`
- [ ] Update `.env` file (`GEMINI_KEY` → `OPENAI_API_KEY`)
- [ ] Update `backend/config.py`
- [ ] Update `backend/services/report_generator.py`
- [ ] Update `backend/services/report_validator.py`
- [ ] Update `backend/routes/reports_generate.py` (docstrings)
- [ ] Update `backend/routes/health.py`
- [ ] Update/delete `backend/utils/gemini_guard.py`
- [ ] Update/delete `backend/tests/test_gemini_models.py`
- [ ] Update `backend/tests/e2e_test.py`
- [ ] (Optional) Rename prompt files
- [ ] Test report generation
- [ ] Test report validation
- [ ] Verify template fallback still works

---

## Testing After Migration

1. **Test Report Generation:**
   ```bash
   POST /api/reports/generate
   ```

2. **Verify:**
   - Reports generate successfully
   - Template fallback still works if API fails
   - Validation pipeline works
   - Error messages are clear

3. **Check Logs:**
   - No "Gemini" references in logs
   - OpenAI API calls succeed
   - Template fallback activates on errors

---

## Notes

- **Prompt Structure:** No changes needed - prompts are model-agnostic
- **Safety Filters:** No changes - same safety filters work with OpenAI
- **Template Fallback:** No changes - fallback system remains the same
- **Database Schema:** No changes - `generation_method` can still track 'ai' vs 'template'
- **RAG Corpus:** No changes - static files work the same way

---

**End of Migration Guide**
