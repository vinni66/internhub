from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_db, get_current_user
from app.models.user import User, UserRole
from app.services.notification_service import NotificationService

router = APIRouter(prefix="/notifications", tags=["Notifications"])


@router.get("", summary="List my notifications")
async def list_notifications(
    limit: int = 30,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await NotificationService(db).list_for_user(current_user.id, limit=limit)


@router.get("/unread-count", summary="Get unread notification count")
async def unread_count(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    count = await NotificationService(db).unread_count(current_user.id)
    return {"unread_count": count}


@router.patch("/{notification_id}/read", summary="Mark notification as read")
async def mark_read(
    notification_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await NotificationService(db).mark_read(notification_id, current_user.id)


@router.post("/read-all", summary="Mark all notifications as read")
async def mark_all_read(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await NotificationService(db).mark_all_read(current_user.id)


# ─── Broadcast (faculty / admin only) ─────────────────────────────────────────
class BroadcastRequest(BaseModel):
    title: str
    message: str
    action_url: Optional[str] = None


@router.post("/broadcast", summary="Broadcast notification to all students")
async def broadcast_notification(
    body: BroadcastRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if current_user.role not in (UserRole.FACULTY, UserRole.ADMIN, UserRole.SUPER_ADMIN):
        raise HTTPException(
            status_code=403,
            detail="Only faculty or admins can send broadcast notifications.",
        )
    result = await NotificationService(db).broadcast_to_students(
        title=body.title,
        message=body.message,
        action_url=body.action_url,
    )
    return {"success": True, "sent_to": result["sent_to"]}
