from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
from sqlalchemy.orm import selectinload

from app.models.application import Application, ApplicationStatus
from app.models.internship import Internship
from app.models.student_profile import StudentProfile


class ApplicationService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def apply(
        self,
        user_id: UUID,
        internship_id: UUID,
        cover_letter: Optional[str] = None,
    ) -> Application:
        # Get student profile
        sp_result = await self.db.execute(
            select(StudentProfile).where(StudentProfile.user_id == user_id)
        )
        student = sp_result.scalar_one_or_none()
        if not student:
            raise HTTPException(status_code=404, detail="Student profile not found")

        # Check internship exists and is published
        int_result = await self.db.execute(
            select(Internship).where(
                Internship.id == internship_id,
                Internship.is_published == True,
                Internship.is_active == True,
            )
        )
        internship = int_result.scalar_one_or_none()
        if not internship:
            raise HTTPException(status_code=404, detail="Internship not found or not open")

        # Check deadline
        if internship.application_deadline:
            try:
                deadline = datetime.fromisoformat(internship.application_deadline)
                if datetime.now(timezone.utc) > deadline.replace(tzinfo=timezone.utc):
                    raise HTTPException(status_code=400, detail="Application deadline has passed")
            except ValueError:
                pass  # Skip deadline check if format invalid

        # Prevent duplicate applications
        dup = await self.db.execute(
            select(Application).where(
                Application.student_id == student.id,
                Application.internship_id == internship_id,
            )
        )
        if dup.scalar_one_or_none():
            raise HTTPException(status_code=409, detail="You have already applied to this internship")

        app = Application(
            student_id=student.id,
            internship_id=internship_id,
            cover_letter=cover_letter,
            applied_at=datetime.now(timezone.utc),
            status=ApplicationStatus.SUBMITTED,
        )
        self.db.add(app)
        await self.db.commit()
        await self.db.refresh(app)
        return app

    async def get_student_applications(self, user_id: UUID) -> list:
        sp_result = await self.db.execute(
            select(StudentProfile).where(StudentProfile.user_id == user_id)
        )
        student = sp_result.scalar_one_or_none()
        if not student:
            return []

        result = await self.db.execute(
            select(Application)
            .options(selectinload(Application.internship))
            .where(Application.student_id == student.id)
            .order_by(Application.applied_at.desc())
        )
        apps = result.scalars().all()

        return [
            {
                "id": str(a.id),
                "status": a.status.value,
                "cover_letter": a.cover_letter,
                "applied_at": a.applied_at.isoformat() if a.applied_at else None,
                "decision_note": a.decision_note,
                "internship": {
                    "id": str(a.internship.id),
                    "title": a.internship.title,
                    "company_name": a.internship.company_name,
                    "mode": a.internship.mode.value,
                    "location": a.internship.location,
                } if a.internship else None,
            }
            for a in apps
        ]

    async def get_internship_applications(
        self, internship_id: UUID, faculty_user_id: UUID
    ) -> list:
        # Verify faculty owns the internship
        int_result = await self.db.execute(
            select(Internship).where(
                Internship.id == internship_id,
                Internship.created_by == faculty_user_id,
            )
        )
        if not int_result.scalar_one_or_none():
            raise HTTPException(status_code=403, detail="You don't own this internship")

        result = await self.db.execute(
            select(Application)
            .options(selectinload(Application.student))
            .where(Application.internship_id == internship_id)
            .order_by(Application.applied_at.desc())
        )
        apps = result.scalars().all()

        return [
            {
                "id": str(a.id),
                "status": a.status.value,
                "cover_letter": a.cover_letter,
                "applied_at": a.applied_at.isoformat() if a.applied_at else None,
                "decision_note": a.decision_note,
                "student": {
                    "id": str(a.student.id),
                    "full_name": a.student.full_name,
                    "usn": a.student.usn,
                    "cgpa": float(a.student.cgpa) if a.student.cgpa else None,
                    "skills": a.student.skills,
                } if a.student else None,
            }
            for a in apps
        ]

    async def update_status(
        self,
        application_id: UUID,
        new_status: str,
        faculty_user_id: UUID,
        decision_note: Optional[str] = None,
    ) -> dict:
        if new_status not in [s.value for s in ApplicationStatus]:
            raise HTTPException(status_code=400, detail=f"Invalid status: {new_status}")

        result = await self.db.execute(
            select(Application)
            .options(selectinload(Application.internship))
            .where(Application.id == application_id)
        )
        app = result.scalar_one_or_none()
        if not app:
            raise HTTPException(status_code=404, detail="Application not found")

        # Verify faculty owns the internship
        if app.internship.created_by != faculty_user_id:
            raise HTTPException(status_code=403, detail="Insufficient permissions")

        app.status = ApplicationStatus(new_status)
        if decision_note:
            app.decision_note = decision_note

        await self.db.commit()
        return {"id": str(application_id), "status": new_status}

    async def withdraw(self, application_id: UUID, user_id: UUID) -> dict:
        sp_result = await self.db.execute(
            select(StudentProfile).where(StudentProfile.user_id == user_id)
        )
        student = sp_result.scalar_one_or_none()

        result = await self.db.execute(
            select(Application).where(
                Application.id == application_id,
                Application.student_id == student.id if student else False,
            )
        )
        app = result.scalar_one_or_none()
        if not app:
            raise HTTPException(status_code=404, detail="Application not found")

        app.status = ApplicationStatus.WITHDRAWN
        await self.db.commit()
        return {"id": str(application_id), "status": "withdrawn"}
