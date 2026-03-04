import hashlib
from datetime import datetime, timedelta, timezone
from typing import Optional
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update

from app.models.user import User, RefreshToken, UserRole
from app.models.student_profile import StudentProfile
from app.models.faculty_profile import FacultyProfile
from app.core.security import (
    hash_password,
    verify_password,
    create_access_token,
    create_refresh_token_value,
    hash_refresh_token,
    create_email_verification_token,
    verify_email_token,
    create_password_reset_token,
    verify_password_reset_token,
)
from app.config import settings
from app.schemas.auth import RegisterRequest, LoginRequest


MAX_FAILED_LOGINS = 5
LOCKOUT_DURATION_MINUTES = 15


class AuthService:
    def __init__(self, db: AsyncSession, redis=None):
        self.db = db
        self.redis = redis   # Optional: Redis for token blacklist

    async def register(self, data: RegisterRequest, ip_address: Optional[str] = None) -> User:
        """Register a new user and create their profile."""

        # Check email uniqueness
        existing = await self.db.execute(
            select(User).where(User.email == data.email, User.deleted_at.is_(None))
        )
        if existing.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="An account with this email already exists",
            )

        # Create User record
        new_user = User(
            email=data.email,
            password_hash=hash_password(data.password),
            role=UserRole(data.role),
            is_active=True,
            is_verified=False,   # Require email verification
        )
        self.db.add(new_user)
        await self.db.flush()    # Get user.id without committing

        # Create profile based on role
        if new_user.role == UserRole.STUDENT:
            profile = StudentProfile(
                user_id=new_user.id,
                full_name=data.full_name,
                usn=data.usn,
            )
            self.db.add(profile)

        elif new_user.role in (UserRole.FACULTY, UserRole.ADMIN):
            profile = FacultyProfile(
                user_id=new_user.id,
                full_name=data.full_name,
            )
            self.db.add(profile)

        await self.db.commit()
        await self.db.refresh(new_user)
        return new_user

    async def login(
        self,
        data: LoginRequest,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> dict:
        """Authenticate user, return access + refresh tokens."""

        user = await self._get_user_by_email(data.email)

        if user is None:
            # Constant-time response to prevent email enumeration
            hash_password("dummy_prevent_timing_attack")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password",
            )

        # Check account lock
        if user.is_locked:
            raise HTTPException(
                status_code=status.HTTP_423_LOCKED,
                detail=f"Account locked due to too many failed attempts. Try again later.",
            )

        # Verify password
        if not verify_password(data.password, user.password_hash):
            await self._record_failed_login(user)
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password",
            )

        if not user.is_active:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Account deactivated. Contact support.",
            )

        # Successful login — reset failed attempts, update last_login
        await self.db.execute(
            update(User)
            .where(User.id == user.id)
            .values(
                failed_logins=0,
                locked_until=None,
                last_login_at=datetime.now(timezone.utc),
                login_count=User.login_count + 1,
            )
        )

        # Issue tokens
        access_token = create_access_token(
            user_id=str(user.id),
            role=user.role.value,
            email=user.email,
        )
        refresh_token_raw = create_refresh_token_value()

        # Save hashed refresh token to DB
        refresh_expires = datetime.now(timezone.utc) + timedelta(
            days=settings.REFRESH_TOKEN_EXPIRE_DAYS
        )
        token_record = RefreshToken(
            user_id=user.id,
            token_hash=hash_refresh_token(refresh_token_raw),
            device_fingerprint=data.device_fingerprint,
            ip_address=ip_address,
            user_agent=user_agent,
            expires_at=refresh_expires,
            created_at=datetime.now(timezone.utc),
        )
        self.db.add(token_record)
        await self.db.commit()

        return {
            "access_token": access_token,
            "refresh_token": refresh_token_raw,
            "token_type": "Bearer",
            "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
            "user": user,
        }

    async def refresh_tokens(self, refresh_token_raw: str) -> dict:
        """Rotate refresh token: revoke old, issue new pair."""
        token_hash = hash_refresh_token(refresh_token_raw)

        result = await self.db.execute(
            select(RefreshToken).where(
                RefreshToken.token_hash == token_hash,
                RefreshToken.revoked_at.is_(None),
            )
        )
        token_record = result.scalar_one_or_none()

        if token_record is None or not token_record.is_valid:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired refresh token",
            )

        # Revoke old token
        token_record.revoked_at = datetime.now(timezone.utc)

        # Get user
        user_result = await self.db.execute(
            select(User).where(User.id == token_record.user_id)
        )
        user = user_result.scalar_one_or_none()
        if not user or not user.is_active:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED)

        # Create new tokens
        access_token = create_access_token(
            user_id=str(user.id),
            role=user.role.value,
            email=user.email,
        )
        new_refresh_raw = create_refresh_token_value()
        new_refresh_expires = datetime.now(timezone.utc) + timedelta(
            days=settings.REFRESH_TOKEN_EXPIRE_DAYS
        )
        new_token_record = RefreshToken(
            user_id=user.id,
            token_hash=hash_refresh_token(new_refresh_raw),
            device_fingerprint=token_record.device_fingerprint,
            ip_address=token_record.ip_address,
            user_agent=token_record.user_agent,
            expires_at=new_refresh_expires,
            created_at=datetime.now(timezone.utc),
        )
        self.db.add(new_token_record)
        await self.db.commit()

        return {
            "access_token": access_token,
            "refresh_token": new_refresh_raw,
            "token_type": "Bearer",
            "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
            "user": user,
        }

    async def logout(self, refresh_token_raw: str) -> None:
        """Revoke refresh token (logout)."""
        token_hash = hash_refresh_token(refresh_token_raw)
        result = await self.db.execute(
            select(RefreshToken).where(RefreshToken.token_hash == token_hash)
        )
        token = result.scalar_one_or_none()
        if token:
            token.revoked_at = datetime.now(timezone.utc)
            await self.db.commit()

    async def verify_email(self, token: str) -> bool:
        """Verify user email with token."""
        email = verify_email_token(token)
        if not email:
            raise HTTPException(status_code=400, detail="Invalid or expired verification token")

        user = await self._get_user_by_email(email)
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        user.is_verified = True
        await self.db.commit()
        return True

    async def forgot_password(self, email: str) -> Optional[str]:
        """Generate password reset token (blind — no error if email not found)."""
        user = await self._get_user_by_email(email)
        if not user:
            return None  # Don't reveal whether email exists
        return create_password_reset_token(email)

    async def reset_password(self, token: str, new_password: str) -> bool:
        """Reset password using token."""
        email = verify_password_reset_token(token)
        if not email:
            raise HTTPException(status_code=400, detail="Invalid or expired reset token")

        user = await self._get_user_by_email(email)
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        user.password_hash = hash_password(new_password)
        user.failed_logins = 0
        user.locked_until = None
        await self.db.commit()
        return True

    # ─── Private helpers ────────────────────────────────────────────────────

    async def _get_user_by_email(self, email: str) -> Optional[User]:
        result = await self.db.execute(
            select(User).where(User.email == email, User.deleted_at.is_(None))
        )
        return result.scalar_one_or_none()

    async def _record_failed_login(self, user: User) -> None:
        user.failed_logins = (user.failed_logins or 0) + 1
        if user.failed_logins >= MAX_FAILED_LOGINS:
            user.locked_until = datetime.now(timezone.utc) + timedelta(
                minutes=LOCKOUT_DURATION_MINUTES
            )
        await self.db.commit()
