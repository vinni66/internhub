from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, Body
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel

from app.api.dependencies import get_db, require_role
from app.models.user import User, UserRole
from app.services.faculty_service import FacultyService
from app.services.application_service import ApplicationService
from app.services.exam_service import ExamService

router = APIRouter(prefix="/faculty", tags=["Faculty"])

_require_faculty = require_role(UserRole.FACULTY, UserRole.ADMIN, UserRole.SUPER_ADMIN)


class InternshipCreate(BaseModel):
    title: str
    company_name: str
    description: str
    mode: str = "hybrid"
    location: Optional[str] = None
    required_skills: list[str] = []
    stipend_min: Optional[int] = None
    stipend_max: Optional[int] = None
    openings: int = 1
    duration_weeks: Optional[int] = None
    min_cgpa: Optional[float] = None
    application_deadline: Optional[str] = None
    poster_url: Optional[str] = None

class InternshipUpdate(BaseModel):
    title: Optional[str] = None
    company_name: Optional[str] = None
    description: Optional[str] = None
    mode: Optional[str] = None
    location: Optional[str] = None
    required_skills: Optional[list[str]] = None
    stipend_min: Optional[int] = None
    stipend_max: Optional[int] = None
    openings: Optional[int] = None
    duration_weeks: Optional[int] = None
    min_cgpa: Optional[float] = None
    application_deadline: Optional[str] = None
    poster_url: Optional[str] = None


class OverrideFlagRequest(BaseModel):
    is_flagged: bool


@router.get("/internships", summary="Faculty: list own internship postings")
async def list_my_internships(
    current_user: User = Depends(_require_faculty),
    db: AsyncSession = Depends(get_db),
):
    return await FacultyService(db).list_my_internships(current_user.id)


@router.post("/internships", summary="Faculty: create a new internship posting")
async def create_internship(
    data: InternshipCreate,
    current_user: User = Depends(_require_faculty),
    db: AsyncSession = Depends(get_db),
):
    internship = await FacultyService(db).create_internship(
        faculty_user_id=current_user.id,
        data=data.model_dump(),
    )
    return {
        "id": str(internship.id),
        "title": internship.title,
        "company_name": internship.company_name,
        "is_published": internship.is_published,
        "created_at": internship.created_at.isoformat() if internship.created_at else None,
    }


@router.patch("/internships/{internship_id}", summary="Faculty: update an internship posting")
async def update_internship(
    internship_id: UUID,
    data: InternshipUpdate,
    current_user: User = Depends(_require_faculty),
    db: AsyncSession = Depends(get_db),
):
    internship = await FacultyService(db).update_internship(
        internship_id=internship_id,
        faculty_user_id=current_user.id,
        data=data.model_dump(exclude_none=True),
    )
    return {"id": str(internship.id), "title": internship.title, "is_published": internship.is_published}


@router.post("/internships/{internship_id}/publish", summary="Faculty: toggle publish status")
async def toggle_publish(
    internship_id: UUID,
    current_user: User = Depends(_require_faculty),
    db: AsyncSession = Depends(get_db),
):
    return await FacultyService(db).toggle_publish(internship_id, current_user.id)


@router.delete("/internships/{internship_id}", summary="Faculty: delete (soft) an internship")
async def delete_internship(
    internship_id: UUID,
    current_user: User = Depends(_require_faculty),
    db: AsyncSession = Depends(get_db),
):
    await FacultyService(db).delete_internship(internship_id, current_user.id)
    return {"message": "Internship removed"}


@router.get("/internships/{internship_id}/applications", summary="Faculty: view applicants")
async def view_applicants(
    internship_id: UUID,
    current_user: User = Depends(_require_faculty),
    db: AsyncSession = Depends(get_db),
):
    return await ApplicationService(db).get_internship_applications(internship_id, current_user.id)


@router.get("/internships/{internship_id}/sessions/active", summary="Faculty: view active and flagged exam sessions")
async def view_active_sessions(
    internship_id: UUID,
    current_user: User = Depends(_require_faculty),
    db: AsyncSession = Depends(get_db),
):
    return await ExamService(db).get_active_sessions_for_internship(internship_id)


@router.get("/sessions/{session_id}/events", summary="Faculty: view timeline of proctoring events")
async def view_session_events(
    session_id: UUID,
    current_user: User = Depends(_require_faculty),
    db: AsyncSession = Depends(get_db),
):
    events = await ExamService(db).get_session_events(session_id)
    return [
        {
            "id": str(e.id),
            "event_type": e.event_type.value,
            "severity": e.severity,
            "created_at": e.created_at.isoformat() if e.created_at else None,
            "screenshot_url": e.screenshot_url,
            "event_metadata": e.event_metadata,
        }
        for e in events
    ]


@router.patch("/sessions/{session_id}/override", summary="Faculty: override AI integrity flag")
async def override_session_flag(
    session_id: UUID,
    payload: OverrideFlagRequest,
    current_user: User = Depends(_require_faculty),
    db: AsyncSession = Depends(get_db),
):
    session = await ExamService(db).override_session_flag(session_id, payload.is_flagged)
    return {"id": str(session.id), "is_flagged": session.is_flagged}

