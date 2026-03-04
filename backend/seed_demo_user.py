"""
Seed demo users for local development.

Usage:
    python seed_demo_user.py

Demo credentials:
    student@internhub.dev  / Demo@1234   (role: student)
    faculty@internhub.dev  / Demo@1234   (role: faculty)
    admin@internhub.dev    / Admin@1234  (role: admin)
"""

import asyncio
import uuid
import bcrypt

import os
from dotenv import load_dotenv

load_dotenv()
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+asyncpg://internhub:internhub_secret@localhost:5432/internhub_db",
)

from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from sqlalchemy import select

from app.models import User, StudentProfile, FacultyProfile  # noqa: E402
from app.models.base import Base  # noqa: E402


def hash_pw(password: str) -> str:
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt(rounds=10)).decode()


DEMO_USERS = [
    {
        "id": uuid.UUID("10000000-0000-0000-0000-000000000001"),
        "email": "student@internhub.dev",
        "password": "Demo@1234",
        "full_name": "Demo Student",
        "role": "student",
        "is_verified": True,
    },
    {
        "id": uuid.UUID("10000000-0000-0000-0000-000000000002"),
        "email": "faculty@internhub.dev",
        "password": "Demo@1234",
        "full_name": "Demo Faculty",
        "role": "faculty",
        "is_verified": True,
    },
    {
        "id": uuid.UUID("10000000-0000-0000-0000-000000000003"),
        "email": "admin@internhub.dev",
        "password": "Admin@1234",
        "full_name": "Platform Admin",
        "role": "admin",
        "is_verified": True,
    },
]


async def seed():
    # asyncpg doesn't support sslmode/channel_binding as query params.
    # Strip them and pass ssl=True via connect_args instead.
    from urllib.parse import urlparse, parse_qs, urlencode, urlunparse
    parsed = urlparse(DATABASE_URL)
    qs = parse_qs(parsed.query)
    qs.pop('sslmode', None)
    qs.pop('channel_binding', None)
    clean_url = urlunparse(parsed._replace(
        query=urlencode({k: v[0] for k, v in qs.items()})
    ))
    is_remote = 'localhost' not in clean_url and '127.0.0.1' not in clean_url
    connect_args = {"ssl": True} if is_remote else {}

    engine = create_async_engine(clean_url, echo=False, connect_args=connect_args)


    # Create tables if they don't exist yet
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as session:
        for demo in DEMO_USERS:
            existing = await session.execute(
                select(User).where(User.email == demo["email"])
            )
            if existing.scalar_one_or_none():
                print(f"  ⚠  {demo['email']} already exists — skipping")
                continue

            user = User(
                id=demo["id"],
                email=demo["email"],
                password_hash=hash_pw(demo["password"]),
                role=demo["role"],
                is_verified=demo["is_verified"],
                is_active=True,
            )
            session.add(user)
            await session.flush()

            if demo["role"] == "student":
                session.add(StudentProfile(
                    user_id=user.id,
                    full_name=demo["full_name"],
                    skills=["Python", "Flutter", "Dart"],
                    interests=["AI", "Mobile Development"],
                ))
            elif demo["role"] == "faculty":
                session.add(FacultyProfile(
                    user_id=user.id,
                    full_name=demo["full_name"],
                ))

            print(f"  ✅  Created {demo['role']}: {demo['email']}")

        await session.commit()

    await engine.dispose()
    print("\nDone! Demo credentials:")
    print("  student@internhub.dev  /  Demo@1234")
    print("  faculty@internhub.dev  /  Demo@1234")
    print("  admin@internhub.dev    /  Admin@1234")


if __name__ == "__main__":
    asyncio.run(seed())
