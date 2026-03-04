from functools import wraps
from fastapi import HTTPException, status
from app.models.user import UserRole


def require_roles(*roles: UserRole):
    """
    FastAPI dependency factory that checks the current user's role.
    Usage:
        @router.get("/admin")
        async def admin_only(current_user = Depends(require_roles(UserRole.ADMIN))):
            ...
    """
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, current_user=None, **kwargs):
            if current_user is None:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Authentication required",
                )
            if current_user.role not in roles:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=f"Access denied. Required roles: {[r.value for r in roles]}",
                )
            return await func(*args, current_user=current_user, **kwargs)
        return wrapper
    return decorator


# Pre-built role collections for convenience
STUDENT_ONLY = (UserRole.STUDENT,)
FACULTY_ONLY = (UserRole.FACULTY, UserRole.ADMIN, UserRole.SUPER_ADMIN)
ADMIN_ONLY = (UserRole.ADMIN, UserRole.SUPER_ADMIN)
SUPER_ADMIN_ONLY = (UserRole.SUPER_ADMIN,)
ALL_AUTHENTICATED = (
    UserRole.STUDENT,
    UserRole.FACULTY,
    UserRole.ADMIN,
    UserRole.SUPER_ADMIN,
)
