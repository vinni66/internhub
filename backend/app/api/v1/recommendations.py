import uuid
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.api.dependencies import get_current_user
from app.models.user import User
from app.services.recommendation_service import RecommendationService

router = APIRouter(prefix="/recommend", tags=["Recommendations & AI"])


@router.get("/internships")
async def get_recommendations(
    limit: int = Query(default=10, ge=1, le=50),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get AI-ranked internship recommendations for the current student."""
    student_id = current_user.id
    service = RecommendationService(db)
    return await service.get_recommended_internships(student_id, limit)


@router.get("/skill-gaps")
async def get_skill_gaps(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Return skill gaps and demand analysis for the current student."""
    student_id = current_user.id
    service = RecommendationService(db)
    return await service.get_skill_gaps(student_id)


@router.get("/career-roadmap")
async def get_career_roadmap(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Return a personalized learning roadmap based on skill gaps."""
    student_id = current_user.id
    service = RecommendationService(db)
    return await service.get_career_roadmap(student_id)
