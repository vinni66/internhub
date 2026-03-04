from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.api.dependencies import get_current_user, require_role
from app.db.session import get_db
from app.models.user import User, UserRole
from app.models.student_profile import StudentProfile
from app.models.faculty_profile import FacultyProfile
from app.schemas.student import (
    StudentProfileUpdate,
    StudentProfileResponse,
    FacultyProfileUpdate,
    FacultyProfileResponse,
)

router = APIRouter(prefix="/students", tags=["Student Profiles"])


@router.get(
    "/me",
    response_model=StudentProfileResponse,
    summary="Get authenticated student's profile",
)
async def get_my_profile(
    current_user: User = Depends(require_role(UserRole.STUDENT)),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(StudentProfile).where(StudentProfile.user_id == current_user.id)
    )
    profile = result.scalar_one_or_none()
    if not profile:
        raise HTTPException(status_code=404, detail="Student profile not found")
    return profile


@router.patch(
    "/me",
    response_model=StudentProfileResponse,
    summary="Update authenticated student's profile",
)
async def update_my_profile(
    updates: StudentProfileUpdate,
    current_user: User = Depends(require_role(UserRole.STUDENT)),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(StudentProfile).where(StudentProfile.user_id == current_user.id)
    )
    profile = result.scalar_one_or_none()
    if not profile:
        raise HTTPException(status_code=404, detail="Student profile not found")

    # Apply only provided fields
    update_data = updates.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(profile, field, value)

    await db.commit()
    await db.refresh(profile)
    return profile


@router.get(
    "/{student_id}",
    response_model=StudentProfileResponse,
    summary="Get a student profile by ID (faculty/admin only)",
)
async def get_student_profile(
    student_id: str,
    current_user: User = Depends(
        require_role(UserRole.FACULTY, UserRole.ADMIN, UserRole.SUPER_ADMIN)
    ),
    db: AsyncSession = Depends(get_db),
):
    from uuid import UUID
    result = await db.execute(
        select(StudentProfile).where(StudentProfile.id == UUID(student_id))
    )
    profile = result.scalar_one_or_none()
    if not profile:
        raise HTTPException(status_code=404, detail="Student profile not found")
    return profile


# ─── Faculty Profile Routes ─────────────────────────────────────────────────

faculty_router = APIRouter(prefix="/faculty", tags=["Faculty Profiles"])


@faculty_router.get(
    "/me",
    response_model=FacultyProfileResponse,
    summary="Get authenticated faculty's profile",
)
async def get_faculty_profile(
    current_user: User = Depends(
        require_role(UserRole.FACULTY, UserRole.ADMIN, UserRole.SUPER_ADMIN)
    ),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(FacultyProfile).where(FacultyProfile.user_id == current_user.id)
    )
    profile = result.scalar_one_or_none()
    if not profile:
        raise HTTPException(status_code=404, detail="Faculty profile not found")
    return profile


@faculty_router.patch(
    "/me",
    response_model=FacultyProfileResponse,
    summary="Update authenticated faculty's profile",
)
async def update_faculty_profile(
    updates: FacultyProfileUpdate,
    current_user: User = Depends(
        require_role(UserRole.FACULTY, UserRole.ADMIN, UserRole.SUPER_ADMIN)
    ),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(FacultyProfile).where(FacultyProfile.user_id == current_user.id)
    )
    profile = result.scalar_one_or_none()
    if not profile:
        raise HTTPException(status_code=404, detail="Faculty profile not found")

    update_data = updates.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(profile, field, value)

    await db.commit()
    await db.refresh(profile)
    return profile
