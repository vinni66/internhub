from fastapi import APIRouter, Depends, HTTPException, Request, status, Body
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_current_user
from app.db.session import get_db
from app.schemas.auth import (
    RegisterRequest,
    LoginRequest,
    RefreshTokenRequest,
    LoginResponse,
    UserResponse,
    VerifyEmailRequest,
    ForgotPasswordRequest,
    ResetPasswordRequest,
    MessageResponse,
)
from app.services.auth_service import AuthService
from app.models.user import User

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post(
    "/register",
    response_model=dict,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new account",
)
async def register(
    data: RegisterRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    service = AuthService(db)
    user = await service.register(
        data=data,
        ip_address=request.client.host if request.client else None,
    )
    # In production: trigger email verification here
    verify_token = service.__class__  # placeholder for email send
    return {
        "id": str(user.id),
        "email": user.email,
        "role": user.role.value,
        "is_verified": user.is_verified,
        "message": "Registration successful. Please verify your email.",
    }


@router.post(
    "/login",
    response_model=LoginResponse,
    summary="Authenticate and receive JWT tokens",
)
async def login(
    data: LoginRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    service = AuthService(db)
    result = await service.login(
        data=data,
        ip_address=request.client.host if request.client else None,
        user_agent=request.headers.get("user-agent"),
    )
    return LoginResponse(
        access_token=result["access_token"],
        refresh_token=result["refresh_token"],
        token_type="Bearer",
        expires_in=result["expires_in"],
        user=UserResponse(
            id=result["user"].id,
            email=result["user"].email,
            role=result["user"].role.value,
            is_verified=result["user"].is_verified,
            avatar_url=result["user"].avatar_url,
        ),
    )


@router.post(
    "/refresh",
    response_model=LoginResponse,
    summary="Rotate refresh token and get new access token",
)
async def refresh_tokens(
    data: RefreshTokenRequest,
    db: AsyncSession = Depends(get_db),
):
    service = AuthService(db)
    result = await service.refresh_tokens(data.refresh_token)
    return LoginResponse(
        access_token=result["access_token"],
        refresh_token=result["refresh_token"],
        token_type="Bearer",
        expires_in=result["expires_in"],
        user=UserResponse(
            id=result["user"].id,
            email=result["user"].email,
            role=result["user"].role.value,
            is_verified=result["user"].is_verified,
        ),
    )


@router.post(
    "/logout",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Logout and revoke refresh token",
)
async def logout(
    data: RefreshTokenRequest,
    db: AsyncSession = Depends(get_db),
):
    service = AuthService(db)
    await service.logout(data.refresh_token)


@router.post(
    "/verify-email",
    response_model=MessageResponse,
    summary="Verify email address with token",
)
async def verify_email(
    data: VerifyEmailRequest,
    db: AsyncSession = Depends(get_db),
):
    service = AuthService(db)
    await service.verify_email(data.token)
    return MessageResponse(message="Email verified successfully")


@router.post(
    "/forgot-password",
    response_model=MessageResponse,
    summary="Request a password reset email",
)
async def forgot_password(
    data: ForgotPasswordRequest,
    db: AsyncSession = Depends(get_db),
):
    service = AuthService(db)
    # Always return success to prevent email enumeration
    await service.forgot_password(data.email)
    return MessageResponse(message="If that email exists, a reset link has been sent")


@router.post(
    "/reset-password",
    response_model=MessageResponse,
    summary="Reset password using token from email",
)
async def reset_password(
    data: ResetPasswordRequest,
    db: AsyncSession = Depends(get_db),
):
    service = AuthService(db)
    await service.reset_password(data.token, data.new_password)
    return MessageResponse(message="Password reset successfully. Please log in.")


@router.get(
    "/me",
    response_model=UserResponse,
    summary="Get current authenticated user info",
)
async def get_me(current_user: User = Depends(get_current_user)):
    return UserResponse(
        id=current_user.id,
        email=current_user.email,
        role=current_user.role.value,
        is_verified=current_user.is_verified,
        avatar_url=current_user.avatar_url,
    )
