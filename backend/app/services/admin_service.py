from typing import Optional
from uuid import UUID
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, update
from fastapi import HTTPException, status

from app.models.user import User, UserRole
from app.models.internship import Internship
from app.models.application import Application
from app.models.exam import ExamSession


class AdminService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_platform_stats(self) -> dict:
        """Aggregate counts for admin dashboard."""
        total_users = (await self.db.execute(
            select(func.count()).select_from(User).where(User.deleted_at.is_(None))
        )).scalar_one()

        total_internships = (await self.db.execute(
            select(func.count()).select_from(Internship).where(Internship.is_active == True)
        )).scalar_one()

        published_internships = (await self.db.execute(
            select(func.count()).select_from(Internship).where(
                Internship.is_active == True, Internship.is_published == True
            )
        )).scalar_one()

        total_applications = (await self.db.execute(
            select(func.count()).select_from(Application)
        )).scalar_one()

        total_exams = (await self.db.execute(
            select(func.count()).select_from(ExamSession)
        )).scalar_one()

        # Users by role
        role_counts = {}
        for role in UserRole:
            count = (await self.db.execute(
                select(func.count()).select_from(User).where(
                    User.role == role, User.deleted_at.is_(None)
                )
            )).scalar_one()
            role_counts[role.value] = count

        return {
            "total_users": total_users,
            "users_by_role": role_counts,
            "total_internships": total_internships,
            "published_internships": published_internships,
            "total_applications": total_applications,
            "total_exams": total_exams,
        }

    async def list_users(
        self,
        role: Optional[str] = None,
        is_active: Optional[bool] = None,
        page: int = 1,
        limit: int = 20,
    ) -> dict:
        query = select(User).where(User.deleted_at.is_(None))
        if role:
            query = query.where(User.role == role)
        if is_active is not None:
            query = query.where(User.is_active == is_active)

        total = (await self.db.execute(
            select(func.count()).select_from(query.subquery())
        )).scalar_one()

        query = query.order_by(User.created_at.desc()).offset((page - 1) * limit).limit(limit)
        users = (await self.db.execute(query)).scalars().all()

        return {
            "total": total,
            "page": page,
            "pages": (total + limit - 1) // limit,
            "users": [
                {
                    "id": str(u.id),
                    "email": u.email,
                    "role": u.role.value,
                    "is_active": u.is_active,
                    "is_verified": u.is_verified,
                    "login_count": u.login_count,
                    "last_login_at": u.last_login_at.isoformat() if u.last_login_at else None,
                    "created_at": u.created_at.isoformat() if u.created_at else None,
                }
                for u in users
            ],
        }

    async def set_user_status(
        self, user_id: UUID, is_active: Optional[bool] = None, is_verified: Optional[bool] = None
    ) -> dict:
        result = await self.db.execute(
            select(User).where(User.id == user_id, User.deleted_at.is_(None))
        )
        user = result.scalar_one_or_none()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        updates = {}
        if is_active is not None:
            user.is_active = is_active
            updates["is_active"] = is_active
        if is_verified is not None:
            user.is_verified = is_verified
            updates["is_verified"] = is_verified

        if updates:
            await self.db.commit()
            await self.db.refresh(user)

        return {
            "id": str(user_id),
            "is_active": user.is_active,
            "is_verified": user.is_verified
        }

    async def change_user_role(self, user_id: UUID, new_role: str) -> dict:
        if new_role not in [r.value for r in UserRole]:
            raise HTTPException(status_code=400, detail=f"Invalid role: {new_role}")

        result = await self.db.execute(
            select(User).where(User.id == user_id, User.deleted_at.is_(None))
        )
        if not result.scalar_one_or_none():
            raise HTTPException(status_code=404, detail="User not found")

        await self.db.execute(
            update(User).where(User.id == user_id).values(role=new_role)
        )
        await self.db.commit()
        return {"id": str(user_id), "role": new_role}

    async def moderate_internship(self, internship_id: UUID, approved: bool) -> dict:
        result = await self.db.execute(
            select(Internship).where(Internship.id == internship_id)
        )
        internship = result.scalar_one_or_none()
        if not internship:
            raise HTTPException(status_code=404, detail="Internship not found")

        if approved:
            internship.is_published = True
        else:
            internship.is_published = False
            internship.is_active = False

        await self.db.commit()
        return {
            "id": str(internship_id),
            "is_published": internship.is_published,
            "is_active": internship.is_active,
        }
