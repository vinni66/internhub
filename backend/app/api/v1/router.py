from fastapi import APIRouter
from app.api.v1 import auth, students, internships, exam, recommendations, analytics, admin, applications, faculty, notifications, jobs

api_router = APIRouter(prefix="/api/v1")

api_router.include_router(auth.router)
api_router.include_router(students.router)
api_router.include_router(internships.router)
api_router.include_router(exam.router)
api_router.include_router(recommendations.router)
api_router.include_router(analytics.router)
api_router.include_router(admin.router)
api_router.include_router(applications.router)
api_router.include_router(faculty.router)
api_router.include_router(notifications.router)
api_router.include_router(jobs.router)
