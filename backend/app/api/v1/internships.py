import math
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_

from app.api.dependencies import get_current_user, require_role
from app.db.session import get_db
from app.models.user import User, UserRole
from app.models.internship import Internship, InternshipMode
from app.models.application import Application, ApplicationStatus
from app.schemas.internship import (
    InternshipCreate,
    InternshipUpdate,
    InternshipResponse,
    PaginatedInternships,
    ApplicationCreate,
    ApplicationResponse,
)

router = APIRouter(prefix="/internships", tags=["Internships"])


@router.get(
    "",
    response_model=PaginatedInternships,
    summary="List published internships (paginated, filterable)",
)
async def list_internships(
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=50),
    search: Optional[str] = Query(None),
    mode: Optional[str] = Query(None),
    min_cgpa: Optional[float] = Query(None),
    db: AsyncSession = Depends(get_db),
):
    query = select(Internship).where(
        Internship.is_published == True,
        Internship.is_active == True,
        Internship.deleted_at.is_(None),
    )

    # Filters
    if search:
        search_term = f"%{search}%"
        query = query.where(
            Internship.title.ilike(search_term)
            | Internship.company_name.ilike(search_term)
            | Internship.description.ilike(search_term)
        )
    if mode:
        query = query.where(Internship.mode == InternshipMode(mode))
    if min_cgpa is not None:
        query = query.where(
            (Internship.min_cgpa == None) | (Internship.min_cgpa <= min_cgpa)
        )

    # Count total for pagination
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar_one()

    # Paginate
    offset = (page - 1) * page_size
    paginated_query = query.order_by(Internship.created_at.desc()).offset(offset).limit(page_size)
    result = await db.execute(paginated_query)
    items = result.scalars().all()

    return PaginatedInternships(
        items=items,
        total=total,
        page=page,
        page_size=page_size,
        pages=math.ceil(total / page_size) if total > 0 else 0,
    )


@router.get(
    "/{internship_id}",
    response_model=InternshipResponse,
    summary="Get internship details",
)
async def get_internship(
    internship_id: UUID,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Internship).where(
            Internship.id == internship_id,
            Internship.deleted_at.is_(None),
        )
    )
    internship = result.scalar_one_or_none()
    if not internship:
        raise HTTPException(status_code=404, detail="Internship not found")
    return internship


@router.post(
    "",
    response_model=InternshipResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new internship (faculty/admin only)",
)
async def create_internship(
    data: InternshipCreate,
    current_user: User = Depends(
        require_role(UserRole.FACULTY, UserRole.ADMIN, UserRole.SUPER_ADMIN)
    ),
    db: AsyncSession = Depends(get_db),
):
    internship = Internship(
        created_by=current_user.id,
        title=data.title,
        company_name=data.company_name,
        description=data.description,
        required_skills=data.required_skills,
        min_cgpa=data.min_cgpa,
        stipend_min=data.stipend_min,
        stipend_max=data.stipend_max,
        duration_weeks=data.duration_weeks,
        mode=InternshipMode(data.mode),
        location=data.location,
        openings=data.openings,
        application_deadline=data.application_deadline,
        is_published=False,
        is_active=True,
    )
    db.add(internship)
    await db.commit()
    await db.refresh(internship)
    return internship


@router.patch(
    "/{internship_id}",
    response_model=InternshipResponse,
    summary="Update internship (owner faculty/admin only)",
)
async def update_internship(
    internship_id: UUID,
    updates: InternshipUpdate,
    current_user: User = Depends(
        require_role(UserRole.FACULTY, UserRole.ADMIN, UserRole.SUPER_ADMIN)
    ),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Internship).where(
            Internship.id == internship_id, Internship.deleted_at.is_(None)
        )
    )
    internship = result.scalar_one_or_none()
    if not internship:
        raise HTTPException(status_code=404, detail="Internship not found")

    # Only owner or admin can update
    if (
        internship.created_by != current_user.id
        and current_user.role not in (UserRole.ADMIN, UserRole.SUPER_ADMIN)
    ):
        raise HTTPException(status_code=403, detail="You can only update your own internships")

    update_data = updates.model_dump(exclude_unset=True)
    if "mode" in update_data:
        update_data["mode"] = InternshipMode(update_data["mode"])
    for field, value in update_data.items():
        setattr(internship, field, value)

    await db.commit()
    await db.refresh(internship)
    return internship


@router.post(
    "/{internship_id}/publish",
    response_model=dict,
    summary="Toggle internship publish status",
)
async def toggle_publish(
    internship_id: UUID,
    current_user: User = Depends(
        require_role(UserRole.FACULTY, UserRole.ADMIN, UserRole.SUPER_ADMIN)
    ),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Internship).where(
            Internship.id == internship_id, Internship.deleted_at.is_(None)
        )
    )
    internship = result.scalar_one_or_none()
    if not internship:
        raise HTTPException(status_code=404, detail="Internship not found")

    # Only owner or admin can publish
    if (
        internship.created_by != current_user.id
        and current_user.role not in (UserRole.ADMIN, UserRole.SUPER_ADMIN)
    ):
        raise HTTPException(status_code=403, detail="Permission denied")

    internship.is_published = not internship.is_published
    await db.commit()
    return {"id": str(internship.id), "is_published": internship.is_published}


@router.delete(
    "/{internship_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Soft delete internship (admin only)",
)
async def delete_internship(
    internship_id: UUID,
    current_user: User = Depends(require_role(UserRole.ADMIN, UserRole.SUPER_ADMIN)),
    db: AsyncSession = Depends(get_db),
):
    from datetime import datetime, timezone
    result = await db.execute(
        select(Internship).where(
            Internship.id == internship_id, Internship.deleted_at.is_(None)
        )
    )
    internship = result.scalar_one_or_none()
    if not internship:
        raise HTTPException(status_code=404, detail="Internship not found")
    internship.deleted_at = datetime.now(timezone.utc)
    await db.commit()
