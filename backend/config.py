# Application configuration settings
# Manages environment variables and app-wide constants
# FAIL-FAST: Application will not start without required config

import sys
from pydantic_settings import BaseSettings
from pydantic import field_validator, Field
from functools import lru_cache
from typing import Optional


class Settings(BaseSettings):
    """
    Application settings loaded from environment variables.
    
    REQUIRED ENV VARS:
    - SUPABASE_URL
    - SUPABASE_ANON_KEY
    
    OPTIONAL:
    - GEMINI_KEY (for AI-generated explanations)
    
    FAIL-FAST: App refuses to start with invalid config.
    """
    
    # Application
    app_name: str = "Learning Pattern Analysis API"
    debug: bool = False
    environment: str = "development"
    
    # Supabase Configuration (REQUIRED)
    supabase_url: str = Field(..., alias="SUPABASE_URL")
    supabase_anon_key: str = Field(..., alias="SUPABASE_ANON_KEY")
    supabase_service_key: Optional[str] = Field(None, alias="SUPABASE_SERVICE_KEY")
    
    # Gemini API Configuration (OPTIONAL - for AI explanations)
    gemini_key: Optional[str] = Field(None, alias="GEMINI_KEY")
    
    # Session Configuration
    session_ttl_hours: int = 24
    
    # Security
    secret_key: str = Field(default="dev-secret-key-change-in-production-min-32-chars")
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    
    @field_validator('supabase_url')
    @classmethod
    def validate_supabase_url(cls, v: str) -> str:
        if not v or not v.startswith('https://'):
            raise ValueError(
                'SUPABASE_URL must be set and start with https://\n'
                'Get from: Supabase Dashboard → Settings → API → Project URL'
            )
        return v
    
    @field_validator('supabase_anon_key')
    @classmethod
    def validate_supabase_anon_key(cls, v: str) -> str:
        if not v or len(v) < 20:
            raise ValueError(
                'SUPABASE_ANON_KEY must be set\n'
                'Get from: Supabase Dashboard → Settings → API → anon public'
            )
        return v
    
    @field_validator('gemini_key')
    @classmethod
    def validate_gemini_key(cls, v: Optional[str]) -> Optional[str]:
        """Gemini key is optional - used for AI explanations only."""
        if v and v.startswith('YOUR_'):
            return None  # Treat placeholder as missing
        return v
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        extra = "ignore"
        populate_by_name = True


def validate_config_or_exit() -> Settings:
    """
    Validate configuration and exit immediately if invalid.
    FAIL-FAST behavior.
    """
    try:
        settings = Settings()
        return settings
    except Exception as e:
        print("\n" + "=" * 60)
        print("❌ CONFIGURATION ERROR - Application cannot start")
        print("=" * 60)
        print(f"\n{e}\n")
        print("Required environment variables:")
        print("  - SUPABASE_URL")
        print("  - SUPABASE_ANON_KEY")
        print("\nOptional:")
        print("  - GEMINI_KEY (for AI explanations)")
        print("\nCopy env.example to .env and fill in values.")
        print("=" * 60 + "\n")
        sys.exit(1)


@lru_cache()
def get_settings() -> Settings:
    """Get cached settings instance with fail-fast validation."""
    return validate_config_or_exit()


def get_settings_dev() -> Optional[Settings]:
    """Get settings without fail-fast (for development/testing)."""
    try:
        return Settings()
    except Exception:
        return None
