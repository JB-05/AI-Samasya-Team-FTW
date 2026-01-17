# =============================================================================
# CHAT ROUTES
# AI Assistant Chat Endpoint
# Uses Gemini for conversational AI
# =============================================================================

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel
from typing import List, Dict, Optional

from ..dependencies import CurrentObserver
from ..config import get_settings_dev
import google.generativeai as genai

router = APIRouter(prefix="/chat", tags=["chat"])


# =============================================================================
# REQUEST/RESPONSE MODELS
# =============================================================================

class ChatMessage(BaseModel):
    """Individual chat message."""
    role: str  # 'user' or 'assistant'
    content: str


class ChatRequest(BaseModel):
    """Chat request payload."""
    message: str
    conversation_history: Optional[List[Dict[str, str]]] = None


class ChatResponse(BaseModel):
    """Chat response payload."""
    response: str


# =============================================================================
# SYSTEM PROMPT
# =============================================================================

CHAT_SYSTEM_PROMPT = """You are a helpful educational assistant for NeuroPlay, a learning behavior observation platform.

Your role:
- Help parents and teachers understand learning patterns and reports
- Provide guidance on supporting learners
- Answer questions about the platform
- Use calm, supportive, non-diagnostic language

CRITICAL RULES:
- DO NOT diagnose or label conditions
- DO NOT mention disorders, disabilities, or medical terms
- DO NOT compare learners to others
- Use observational, growth-oriented language
- Keep responses concise and helpful

Tone: Calm, supportive, neutral, non-judgmental."""


# =============================================================================
# ROUTES
# =============================================================================

@router.post("", response_model=ChatResponse)
async def chat(
    request: ChatRequest,
    observer: CurrentObserver
):
    """
    Chat with AI assistant using Gemini.
    
    Provides conversational AI support for the NeuroPlay platform.
    Uses Gemini to generate helpful, non-diagnostic responses.
    """
    settings = get_settings_dev()
    
    if not settings or not settings.gemini_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="AI chat service is not configured. Please contact support."
        )
    
    # Configure Gemini
    try:
        genai.configure(api_key=settings.gemini_key)
        model = genai.GenerativeModel(
            'gemini-flash-latest',
            generation_config={
                'temperature': 0.7,  # Balanced for conversational tone
                'max_output_tokens': 500,
            }
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Failed to initialize AI model: {str(e)}"
        )
    
    # Build conversation history
    conversation_parts = []
    
    # Add system prompt as first message
    conversation_parts.append({
        'role': 'user',
        'parts': [CHAT_SYSTEM_PROMPT]
    })
    conversation_parts.append({
        'role': 'model',
        'parts': ['I understand. I will help you with questions about NeuroPlay and learning patterns using calm, supportive, non-diagnostic language.']
    })
    
    # Add conversation history if provided
    if request.conversation_history:
        for msg in request.conversation_history:
            role = msg.get('role', 'user')
            content = msg.get('content', '')
            if content and role in ['user', 'assistant']:
                conversation_parts.append({
                    'role': 'user' if role == 'user' else 'model',
                    'parts': [content]
                })
    
    # Add current user message
    conversation_parts.append({
        'role': 'user',
        'parts': [request.message]
    })
    
    # Generate response
    try:
        chat = model.start_chat(history=conversation_parts[:-1])  # All except last
        response = chat.send_message(conversation_parts[-1]['parts'][0])
        
        if not response.text:
            raise ValueError("Empty response from AI model")
        
        return ChatResponse(response=response.text.strip())
        
    except Exception as e:
        error_str = str(e)
        
        # Handle quota/billing errors
        if "429" in error_str or "quota" in error_str.lower() or "limit: 0" in error_str:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="AI service is temporarily unavailable due to quota limits. Please try again later."
            )
        
        # Handle API key errors
        if "API_KEY" in error_str.upper() or "API key" in error_str:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="AI service configuration error. Please contact support."
            )
        
        # Generic error
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate response: {str(e)}"
        )
