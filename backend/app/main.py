from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.config import settings
from app.api.v1.router import api_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown events."""
    # Startup: verify DB connection
    from app.db.session import engine
    from sqlalchemy import text
    async with engine.connect() as conn:
        await conn.execute(text("SELECT 1"))
    print("✅ Database connection verified")
    yield
    # Shutdown: dispose engine pool
    await engine.dispose()
    print("🔴 Database connections closed")


def create_app() -> FastAPI:
    app = FastAPI(
        title=settings.APP_NAME,
        version=settings.APP_VERSION,
        description="AI-Based Cross-Platform Internship Aptitude Test & Recruitment Platform",
        docs_url="/docs" if settings.DEBUG else None,
        redoc_url="/redoc" if settings.DEBUG else None,
        openapi_url="/openapi.json" if settings.DEBUG else None,
        lifespan=lifespan,
    )

    # ─── CORS ────────────────────────────────────────────────────────────────
    # In DEBUG/dev, allow all origins so Flutter web (random port) can connect.
    # In production, restrict to settings.ALLOWED_ORIGINS only.
    cors_origins = ["*"] if settings.DEBUG else settings.ALLOWED_ORIGINS
    app.add_middleware(
        CORSMiddleware,
        allow_origins=cors_origins,
        allow_credentials=not settings.DEBUG,  # credentials not supported with wildcard
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # ─── Security Headers ──────────────────────────────────────────────────
    @app.middleware("http")
    async def add_security_headers(request: Request, call_next):
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        if not settings.DEBUG:
            response.headers["Strict-Transport-Security"] = (
                "max-age=31536000; includeSubDomains; preload"
            )
        return response

    # ─── Request ID ───────────────────────────────────────────────────────
    @app.middleware("http")
    async def add_request_id(request: Request, call_next):
        import uuid
        request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))
        response = await call_next(request)
        response.headers["X-Request-ID"] = request_id
        return response

    # ─── Global Exception Handler ─────────────────────────────────────────
    @app.exception_handler(Exception)
    async def global_exception_handler(request: Request, exc: Exception):
        import traceback, uuid
        error_id = str(uuid.uuid4())
        tb = traceback.format_exc()
        print(f"[ERROR {error_id}] Unhandled: {exc}\n{tb}")
        detail = str(exc) if settings.DEBUG else "An unexpected error occurred"
        return JSONResponse(
            status_code=500,
            content={
                "error": {
                    "code": "INTERNAL_SERVER_ERROR",
                    "message": detail,
                    "traceback": tb if settings.DEBUG else None,
                    "error_id": error_id,
                }
            },
        )

    # ─── Routers ──────────────────────────────────────────────────────────
    app.include_router(api_router)

    # ─── Health Check ─────────────────────────────────────────────────────
    @app.get("/health", tags=["Health"])
    async def health_check():
        return {
            "status": "healthy",
            "app": settings.APP_NAME,
            "version": settings.APP_VERSION,
            "environment": settings.ENVIRONMENT,
        }

    @app.get("/", tags=["Root"])
    async def root():
        return {"message": f"Welcome to {settings.APP_NAME} v{settings.APP_VERSION}"}

    return app


app = create_app()
