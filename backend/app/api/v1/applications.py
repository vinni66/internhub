from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, Body
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_db, get_current_user, require_role
from app.models.user import User, UserRole
from app.services.application_service import ApplicationService

router = APIRouter(prefix="/applications", tags=["Applications"])

_require_faculty = require_role(UserRole.FACULTY, UserRole.ADMIN, UserRole.SUPER_ADMIN)


@router.post("", summary="Student: apply to an internship")
async def apply(
    internship_id: UUID = Body(..., embed=True),
    cover_letter: Optional[str] = Body(None, embed=True),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    app = await ApplicationService(db).apply(
        user_id=current_user.id,
        internship_id=internship_id,
        cover_letter=cover_letter,
    )
    return {
        "id": str(app.id),
        "status": app.status.value,
        "internship_id": str(app.internship_id),
        "applied_at": app.applied_at.isoformat() if app.applied_at else None,
    }


@router.get("/me", summary="Student: list my applications")
async def my_applications(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await ApplicationService(db).get_student_applications(current_user.id)


@router.get("/internship/{internship_id}", summary="Faculty: list applicants for an internship")
async def internship_applications(
    internship_id: UUID,
    current_user: User = Depends(_require_faculty),
    db: AsyncSession = Depends(get_db),
):
    return await ApplicationService(db).get_internship_applications(internship_id, current_user.id)


@router.patch("/{application_id}/status", summary="Faculty: update application status")
async def update_status(
    application_id: UUID,
    new_status: str = Body(..., embed=True),
    decision_note: Optional[str] = Body(None, embed=True),
    current_user: User = Depends(_require_faculty),
    db: AsyncSession = Depends(get_db),
):
    return await ApplicationService(db).update_status(
        application_id=application_id,
        new_status=new_status,
        faculty_user_id=current_user.id,
        decision_note=decision_note,
    )


@router.patch("/{application_id}/withdraw", summary="Student: withdraw application")
async def withdraw(
    application_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await ApplicationService(db).withdraw(application_id, current_user.id)
