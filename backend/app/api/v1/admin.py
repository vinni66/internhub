from typing import Optional
from uuid import UUID
from pydantic import BaseModel

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_db, require_role
from app.models.user import UserRole
from app.services.admin_service import AdminService

router = APIRouter(prefix="/admin", tags=["Admin"])

_require_admin = require_role(UserRole.ADMIN, UserRole.SUPER_ADMIN)

class UserStatusUpdate(BaseModel):
    is_active: Optional[bool] = None
    is_verified: Optional[bool] = None

class UserRoleUpdate(BaseModel):
    role: str


@router.get("/stats", summary="Platform-wide statistics")
async def get_stats(
    _=Depends(_require_admin),
    db: AsyncSession = Depends(get_db),
):
    return await AdminService(db).get_platform_stats()


@router.get("/users", summary="List all users")
async def list_users(
    role: Optional[str] = Query(None),
    is_active: Optional[bool] = Query(None),
    page: int = Query(1, ge=1),
    limit: int = Query(20, le=100),
    _=Depends(_require_admin),
    db: AsyncSession = Depends(get_db),
):
    return await AdminService(db).list_users(role=role, is_active=is_active, page=page, limit=limit)


@router.patch("/users/{user_id}/status", summary="Update user active or verified status")
async def set_user_status(
    user_id: UUID,
    payload: UserStatusUpdate,
    _=Depends(_require_admin),
    db: AsyncSession = Depends(get_db),
):
    return await AdminService(db).set_user_status(
        user_id, 
        is_active=payload.is_active, 
        is_verified=payload.is_verified
    )


@router.patch("/users/{user_id}/role", summary="Change user role")
async def change_role(
    user_id: UUID,
    payload: UserRoleUpdate,
    _=Depends(_require_admin),
    db: AsyncSession = Depends(get_db),
):
    return await AdminService(db).change_user_role(user_id, payload.role)


@router.patch("/internships/{internship_id}/moderate", summary="Approve or reject internship")
async def moderate_internship(
    internship_id: UUID,
    approved: bool,
    _=Depends(_require_admin),
    db: AsyncSession = Depends(get_db),
):
    return await AdminService(db).moderate_internship(internship_id, approved)
