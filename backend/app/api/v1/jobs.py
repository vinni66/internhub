"""
Jobs API router — public proxy endpoints for external job sources.
Currently supports Adzuna (GET /jobs/adzuna).
"""
from typing import Optional
from fastapi import APIRouter, Query, HTTPException

from app.services.adzuna_service import search_adzuna

router = APIRouter(prefix="/jobs", tags=["External Jobs"])


@router.get(
    "/adzuna",
    summary="Search live internship listings from Adzuna (India)",
)
async def adzuna_search(
    what: str = Query("internship", description="Job title / keywords to search"),
    where: Optional[str] = Query(None, description="City or region in India"),
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(20, ge=1, le=50, description="Results per page"),
):
    """
    Proxy endpoint that calls the Adzuna API server-side and returns
    normalised results. The Adzuna credentials never leave the backend.
    """
    try:
        return await search_adzuna(what=what, where=where, page=page, page_size=page_size)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Adzuna API error: {exc}")
