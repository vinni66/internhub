from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.pool import NullPool
from typing import AsyncGenerator

from app.config import settings

from urllib.parse import urlparse, parse_qs, urlencode, urlunparse

def _build_engine_args(raw_url: str):
    """
    asyncpg doesn't accept sslmode / channel_binding as URL query params.
    Strip them and pass ssl=True via connect_args for remote (cloud) DBs.
    """
    parsed = urlparse(raw_url)
    qs = parse_qs(parsed.query)
    qs.pop("sslmode", None)
    qs.pop("channel_binding", None)
    clean_url = urlunparse(
        parsed._replace(query=urlencode({k: v[0] for k, v in qs.items()}))
    )
    is_remote = "localhost" not in clean_url and "127.0.0.1" not in clean_url
    connect_args = {"ssl": True} if is_remote else {}
    return clean_url, connect_args

_db_url, _connect_args = _build_engine_args(settings.DATABASE_URL)

# Create async engine
engine = create_async_engine(
    _db_url,
    echo=settings.DB_ECHO,
    pool_size=settings.DB_POOL_SIZE,
    max_overflow=settings.DB_MAX_OVERFLOW,
    pool_pre_ping=True,
    pool_recycle=3600,
    connect_args=_connect_args,
)

# Session factory
AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,     # Don't expire objects after commit
    autocommit=False,
    autoflush=False,
)


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """FastAPI dependency: yields an async DB session."""
    async with AsyncSessionLocal() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


# For testing: engine with NullPool (no connection reuse)
def create_test_engine(url: str):
    return create_async_engine(url, poolclass=NullPool, echo=True)
