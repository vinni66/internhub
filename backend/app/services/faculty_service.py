from typing import Optional
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

from app.models.internship import Internship, InternshipMode
from app.models.application import Application


class FacultyService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create_internship(self, faculty_user_id: UUID, data: dict) -> Internship:
        internship = Internship(
            created_by=faculty_user_id,
            title=data["title"],
            company_name=data["company_name"],
            description=data["description"],
            required_skills=data.get("required_skills", []),
            mode=InternshipMode(data.get("mode", "hybrid")),
            location=data.get("location"),
            stipend_min=data.get("stipend_min"),
            stipend_max=data.get("stipend_max"),
            openings=data.get("openings", 1),
            duration_weeks=data.get("duration_weeks"),
            min_cgpa=data.get("min_cgpa"),
            application_deadline=data.get("application_deadline"),
            poster_url=data.get("poster_url"),
            is_published=False,
            is_active=True,
        )
        self.db.add(internship)
        await self.db.commit()
        await self.db.refresh(internship)
        return internship

    async def update_internship(
        self, internship_id: UUID, faculty_user_id: UUID, data: dict
    ) -> Internship:
        internship = await self._get_owned(internship_id, faculty_user_id)

        updatable = [
            "title", "company_name", "description", "required_skills",
            "location", "stipend_min", "stipend_max", "openings",
            "duration_weeks", "min_cgpa", "application_deadline", "poster_url"
        ]
        for field in updatable:
            if field in data:
                setattr(internship, field, data[field])

        if "mode" in data:
            internship.mode = InternshipMode(data["mode"])

        await self.db.commit()
        await self.db.refresh(internship)
        return internship

    async def toggle_publish(self, internship_id: UUID, faculty_user_id: UUID) -> dict:
        internship = await self._get_owned(internship_id, faculty_user_id)
        internship.is_published = not internship.is_published
        await self.db.commit()
        return {"id": str(internship_id), "is_published": internship.is_published}

    async def delete_internship(self, internship_id: UUID, faculty_user_id: UUID) -> None:
        internship = await self._get_owned(internship_id, faculty_user_id)
        internship.is_active = False
        internship.is_published = False
        await self.db.commit()

    async def list_my_internships(self, faculty_user_id: UUID) -> list:
        result = await self.db.execute(
            select(Internship)
            .where(
                Internship.created_by == faculty_user_id,
                Internship.is_active == True,
            )
            .order_by(Internship.created_at.desc())
        )
        internships = result.scalars().all()

        # Get application counts
        output = []
        for i in internships:
            count = (await self.db.execute(
                select(func.count()).select_from(Application).where(
                    Application.internship_id == i.id
                )
            )).scalar_one()
            output.append({
                "id": str(i.id),
                "title": i.title,
                "company_name": i.company_name,
                "mode": i.mode.value,
                "location": i.location,
                "openings": i.openings,
                "is_published": i.is_published,
                "required_skills": i.required_skills,
                "stipend_min": i.stipend_min,
                "stipend_max": i.stipend_max,
                "application_deadline": i.application_deadline,
                "applications_count": count,
                "created_at": i.created_at.isoformat() if i.created_at else None,
            })
        return output

    async def _get_owned(self, internship_id: UUID, faculty_user_id: UUID) -> Internship:
        result = await self.db.execute(
            select(Internship).where(
                Internship.id == internship_id,
                Internship.created_by == faculty_user_id,
                Internship.is_active == True,
            )
        )
        internship = result.scalar_one_or_none()
        if not internship:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Internship not found or you do not own it",
            )
        return internship
