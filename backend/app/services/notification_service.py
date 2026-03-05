from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, update

from app.models.notification import Notification
from app.models.user import User, UserRole


class NotificationService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create(
        self,
        user_id: UUID,
        type: str,
        title: str,
        message: str,
        action_url: Optional[str] = None,
    ) -> Notification:
        n = Notification(
            user_id=user_id,
            type=type,
            title=title,
            message=message,
            action_url=action_url,
        )
        self.db.add(n)
        await self.db.commit()
        await self.db.refresh(n)
        return n

    async def list_for_user(self, user_id: UUID, limit: int = 30) -> list:
        result = await self.db.execute(
            select(Notification)
            .where(Notification.user_id == user_id)
            .order_by(Notification.created_at.desc())
            .limit(limit)
        )
        notifications = result.scalars().all()
        return [
            {
                "id": str(n.id),
                "type": n.type,
                "title": n.title,
                "message": n.message,
                "is_read": n.is_read,
                "action_url": n.action_url,
                "created_at": n.created_at.isoformat() if n.created_at else None,
            }
            for n in notifications
        ]

    async def unread_count(self, user_id: UUID) -> int:
        return (await self.db.execute(
            select(func.count()).select_from(Notification).where(
                Notification.user_id == user_id,
                Notification.is_read == False,
            )
        )).scalar_one()

    async def mark_read(self, notification_id: UUID, user_id: UUID) -> dict:
        result = await self.db.execute(
            select(Notification).where(
                Notification.id == notification_id,
                Notification.user_id == user_id,
            )
        )
        n = result.scalar_one_or_none()
        if not n:
            raise HTTPException(status_code=404, detail="Notification not found")
        n.is_read = True
        await self.db.commit()
        return {"id": str(notification_id), "is_read": True}

    async def mark_all_read(self, user_id: UUID) -> dict:
        await self.db.execute(
            update(Notification)
            .where(Notification.user_id == user_id, Notification.is_read == False)
            .values(is_read=True)
        )
        await self.db.commit()
        return {"marked_read": True}

    async def broadcast_to_students(
        self,
        title: str,
        message: str,
        type: str = "faculty_announcement",
        action_url: Optional[str] = None,
    ) -> dict:
        """Send a notification to every active student user."""
        result = await self.db.execute(
            select(User).where(
                User.role == UserRole.STUDENT,
                User.is_active == True,
                User.deleted_at.is_(None),
            )
        )
        students = result.scalars().all()
        for student in students:
            self.db.add(
                Notification(
                    user_id=student.id,
                    type=type,
                    title=title,
                    message=message,
                    action_url=action_url,
                )
            )
        await self.db.commit()
        return {"sent_to": len(students)}
