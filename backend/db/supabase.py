# Supabase client configuration and initialization
# Provides database connection and JWT verification

from supabase import create_client, Client
from typing import Optional
from ..config import get_settings_dev

# Supabase client instance
_supabase_client: Client | None = None


def get_supabase() -> Optional[Client]:
    """
    Get or create Supabase client instance.
    
    Returns:
        Supabase client for database operations, or None if not configured
    """
    global _supabase_client
    
    if _supabase_client is None:
        settings = get_settings_dev()
        if settings is None:
            return None
        
        _supabase_client = create_client(
            settings.supabase_url,
            settings.supabase_anon_key
        )
    
    return _supabase_client


def get_supabase_admin() -> Optional[Client]:
    """
    Get Supabase client with service role key (admin access).
    Used for operations that bypass RLS.
    
    Returns:
        Supabase admin client, or None if not configured
    """
    settings = get_settings_dev()
    if settings is None or not settings.supabase_service_key:
        return None
    
    return create_client(
        settings.supabase_url,
        settings.supabase_service_key
    )
