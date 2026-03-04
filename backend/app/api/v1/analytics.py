import uuid
from fastapi import APIRouter, Depends, Query
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.api.dependencies import get_current_user
from app.models.user import User
from app.models.exam import ExamSession, SessionStatus, ProctorEvent
from app.models.application import Application

router = APIRouter(prefix="/analytics", tags=["Analytics"])


@router.get("/me")
async def get_my_analytics(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Return performance analytics for the current student."""
    student_id = current_user.id

    # Exam sessions
    sessions_result = await db.execute(
        select(ExamSession).where(
            ExamSession.student_id == student_id,
            ExamSession.status == SessionStatus.COMPLETED,
        )
    )
    sessions = sessions_result.scalars().all()

    # Applications
    apps_result = await db.execute(
        select(Application).where(Application.student_profile_id == student_id)
    )
    applications = apps_result.scalars().all()

    total_exams = len(sessions)
    avg_score = (
        round(sum(s.percentage or 0 for s in sessions) / total_exams, 1)
        if total_exams > 0
        else 0
    )
    avg_integrity = (
        round(sum(s.integrity_score or 100 for s in sessions) / total_exams, 1)
        if total_exams > 0
        else 100
    )
    best_score = max((s.percentage or 0 for s in sessions), default=0)

    score_history = [
        {
            "session_id": str(s.id),
            "percentage": s.percentage,
            "integrity_score": s.integrity_score,
            "submitted_at": s.submitted_at,
        }
        for s in sorted(sessions, key=lambda x: x.submitted_at or "")
    ]

    return {
        "total_exams_taken": total_exams,
        "average_score": avg_score,
        "best_score": best_score,
        "average_integrity_score": avg_integrity,
        "total_applications": len(applications),
        "applications_shortlisted": sum(
            1 for a in applications if a.status == "shortlisted"
        ),
        "score_history": score_history,
        "performance_trend": "improving" if len(sessions) >= 2 and
            (sessions[-1].percentage or 0) > (sessions[0].percentage or 0)
            else "stable",
    }
