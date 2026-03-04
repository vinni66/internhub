import hashlib
import secrets
from datetime import datetime, timedelta, timezone
from typing import Optional
from uuid import UUID

from jose import jwt, JWTError
import bcrypt

from app.config import settings

# JWT algorithm
ALGORITHM = "HS256"   # Using HS256 for simplicity in dev; switch to RS256 in prod



def hash_password(password: str) -> str:
    """Hash a plaintext password with bcrypt."""
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt(rounds=12)).decode()


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a plaintext password against a bcrypt hash."""
    try:
        return bcrypt.checkpw(plain_password.encode(), hashed_password.encode())
    except Exception:
        return False


def create_access_token(
    user_id: str,
    role: str,
    email: str,
    expires_delta: Optional[timedelta] = None,
) -> str:
    """Create a short-lived JWT access token."""
    expire = datetime.now(timezone.utc) + (
        expires_delta or timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    jti = secrets.token_urlsafe(16)   # unique token ID for blacklisting

    payload = {
        "sub": user_id,
        "role": role,
        "email": email,
        "exp": expire,
        "iat": datetime.now(timezone.utc),
        "jti": jti,
        "type": "access",
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=ALGORITHM)


def decode_access_token(token: str) -> dict:
    """
    Decode and validate a JWT access token.
    Raises JWTError on failure.
    """
    return jwt.decode(token, settings.SECRET_KEY, algorithms=[ALGORITHM])


def create_refresh_token_value() -> str:
    """Generate a cryptographically secure refresh token string."""
    return secrets.token_urlsafe(64)


def hash_refresh_token(token: str) -> str:
    """One-way hash of a refresh token for storage (SHA-256)."""
    return hashlib.sha256(token.encode()).hexdigest()


def create_email_verification_token(email: str) -> str:
    """Create a short-lived token for email verification."""
    expire = datetime.now(timezone.utc) + timedelta(hours=24)
    payload = {
        "sub": email,
        "exp": expire,
        "type": "email_verify",
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=ALGORITHM)


def verify_email_token(token: str) -> Optional[str]:
    """Returns email if token is valid, None otherwise."""
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("type") != "email_verify":
            return None
        return payload.get("sub")
    except JWTError:
        return None


def create_password_reset_token(email: str) -> str:
    """Create a short-lived password reset token."""
    expire = datetime.now(timezone.utc) + timedelta(hours=1)
    payload = {
        "sub": email,
        "exp": expire,
        "type": "password_reset",
        "jti": secrets.token_urlsafe(16),
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=ALGORITHM)


def verify_password_reset_token(token: str) -> Optional[str]:
    """Returns email if reset token is valid, None otherwise."""
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("type") != "password_reset":
            return None
        return payload.get("sub")
    except JWTError:
        return None
