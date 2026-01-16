# =============================================================================
# REPORT GENERATION ROUTES
# Phase 3.1: AI Report Generation via Gemini
# =============================================================================

from uuid import UUID
from typing import Optional
from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field

from ..dependencies import CurrentObserver
from ..services.report_generator import get_report_generator

router = APIRouter(prefix="/reports", tags=["reports"])


# =============================================================================
# REQUEST/RESPONSE SCHEMAS
# =============================================================================

class GenerateReportRequest(BaseModel):
    """Request to generate a new report."""
    learner_id: UUID
    scope: str = Field(..., pattern="^(session|learner)$")
    session_id: Optional[UUID] = None
    audience: str = Field(default="parent", pattern="^(parent|teacher)$")


class GenerateReportResponse(BaseModel):
    """Response after generating a report."""
    report_id: UUID
    status: str


# =============================================================================
# ROUTES
# =============================================================================

@router.post("/generate", response_model=GenerateReportResponse)
async def generate_report(
    request: GenerateReportRequest,
    observer: CurrentObserver
):
    """
    Generate a narrative report using Gemini AI.
    
    CRITICAL SAFETY:
    - Gemini receives ONLY pattern names, learning impacts, support focuses, and trend types
    - NEVER sends raw gameplay data, metrics, numbers, or game names
    - Output is validated for prohibited terms
    - Reports saved with validation_status='pending' for review
    
    Request Body:
    {
        "learner_id": "uuid",
        "scope": "session" | "learner",
        "session_id": "uuid" (required if scope="session"),
        "audience": "parent" | "teacher"
    }
    
    Response:
    {
        "report_id": "uuid",
        "status": "generated_pending_validation" | "generated_rejected"
    }
    """
    # Validate session_id is provided when scope is 'session'
    if request.scope == 'session' and not request.session_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="session_id is required when scope='session'"
        )
    
    # Verify learner belongs to observer
    from ..db.supabase import get_supabase_admin
    supabase = get_supabase_admin()
    if not supabase:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database connection unavailable"
        )
    
    # Check learner ownership
    learner_check = supabase.table("learners").select("learner_id").eq(
        "learner_id", str(request.learner_id)
    ).eq(
        "observer_id", str(observer.observer_id)
    ).execute()
    
    if not learner_check.data:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Learner not found or does not belong to you"
        )
    
    # If session scope, verify session belongs to learner
    if request.session_id:
        session_check = supabase.table("sessions").select("learner_id").eq(
            "session_id", str(request.session_id)
        ).eq(
            "learner_id", str(request.learner_id)
        ).execute()
        
        if not session_check.data:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Session does not belong to this learner"
            )
    
    # Check if report already exists (caching)
    existing_report_query = supabase.table("reports").select("report_id, content, validation_status").eq(
        "learner_id", str(request.learner_id)
    ).eq(
        "report_scope", request.scope
    ).eq(
        "audience", request.audience
    )
    
    if request.session_id:
        existing_report_query = existing_report_query.eq(
            "source_session_id", str(request.session_id)
        )
    else:
        existing_report_query = existing_report_query.is_("source_session_id", "null")
    
    existing_report = existing_report_query.order("created_at", desc=True).limit(1).execute()
    
    if existing_report.data:
        # Return cached report if it's approved or rewritten
        existing = existing_report.data[0]
        if existing["validation_status"] in ["approved", "rewritten"]:
            return GenerateReportResponse(
                report_id=UUID(existing["report_id"]),
                status="cached_approved"
            )
    
    # Generate new report
    try:
        generator = get_report_generator()
        result = generator.generate_report(
            learner_id=request.learner_id,
            scope=request.scope,
            session_id=request.session_id,
            audience=request.audience
        )
        
        return GenerateReportResponse(
            report_id=UUID(result["report_id"]),
            status=result["status"]
        )
        
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        print(f"[ERROR] Report generation failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to generate report. Please try again."
        )
