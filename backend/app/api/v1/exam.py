import uuid
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, status, Query
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.api.dependencies import get_current_user
from app.models.user import User
from app.services.exam_service import ExamService
from app.models.exam import SessionStatus

router = APIRouter(prefix="/exam", tags=["Exam Engine"])


# ─── Schemas ──────────────────────────────────────────────────────────────
class StartSessionRequest(BaseModel):
    internship_id: uuid.UUID
    device_fingerprint: Optional[str] = None


class SubmitAnswerRequest(BaseModel):
    question_id: uuid.UUID
    answer_text: Optional[str] = None
    selected_option_index: Optional[int] = None
    time_spent_seconds: Optional[int] = None


class ProctorEventRequest(BaseModel):
    session_id: uuid.UUID
    event_type: str
    severity: int = Field(default=1, ge=1, le=3)
    screenshot_url: Optional[str] = None
    metadata: Optional[dict] = None


class QuestionOut(BaseModel):
    id: uuid.UUID
    question_text: str
    question_type: str
    difficulty: str
    marks: int
    options: Optional[list] = None
    time_limit_seconds: Optional[int] = None

    class Config:
        from_attributes = True


class SessionOut(BaseModel):
    id: uuid.UUID
    status: str
    started_at: Optional[str]
    expires_at: Optional[str]
    duration_minutes: int
    question_count: int
    warnings_count: int
    integrity_score: Optional[int]
    percentage: Optional[float]

    class Config:
        from_attributes = True


# ─── Routes ───────────────────────────────────────────────────────────────
@router.post("/sessions", response_model=SessionOut, status_code=status.HTTP_201_CREATED)
async def start_exam_session(
    payload: StartSessionRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Start or resume an exam session for an internship."""
    student_id = current_user.id
    service = ExamService(db)
    session = await service.start_session(
        student_id=student_id,
        internship_id=payload.internship_id,
        device_fingerprint=payload.device_fingerprint,
    )
    return SessionOut(
        id=session.id,
        status=session.status.value,
        started_at=session.started_at,
        expires_at=session.expires_at,
        duration_minutes=session.duration_minutes,
        question_count=len(session.question_ids),
        warnings_count=session.warnings_count,
        integrity_score=session.integrity_score,
        percentage=session.percentage,
    )


@router.get("/sessions/{session_id}", response_model=SessionOut)
async def get_session(
    session_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
):
    service = ExamService(db)
    session = await service.get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    return SessionOut(
        id=session.id,
        status=session.status.value,
        started_at=session.started_at,
        expires_at=session.expires_at,
        duration_minutes=session.duration_minutes,
        question_count=len(session.question_ids),
        warnings_count=session.warnings_count,
        integrity_score=session.integrity_score,
        percentage=session.percentage,
    )


@router.get("/sessions/{session_id}/questions", response_model=list[QuestionOut])
async def get_session_questions(
    session_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
):
    """Return all questions for this session (options included, correct answer NOT)."""
    service = ExamService(db)
    session = await service.get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    questions = await service.get_questions_for_session(session)
    return [
        QuestionOut(
            id=q.id,
            question_text=q.question_text,
            question_type=q.question_type.value,
            difficulty=q.difficulty.value,
            marks=q.marks,
            options=[
                {"index": i, "text": opt["text"]}
                for i, opt in enumerate(q.options or [])
            ],
            time_limit_seconds=q.time_limit_seconds,
        )
        for q in questions
    ]


@router.post("/sessions/{session_id}/answers")
async def submit_answer(
    session_id: uuid.UUID,
    payload: SubmitAnswerRequest,
    db: AsyncSession = Depends(get_db),
):
    """Submit or update answer to a question during an active session."""
    service = ExamService(db)
    answer = await service.submit_answer(
        session_id=session_id,
        question_id=payload.question_id,
        answer_text=payload.answer_text,
        selected_option_index=payload.selected_option_index,
        time_spent_seconds=payload.time_spent_seconds,
    )
    return {"id": str(answer.id), "saved": True}


@router.post("/sessions/{session_id}/submit", response_model=SessionOut)
async def submit_session(
    session_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
):
    """Finalize and submit the exam."""
    service = ExamService(db)
    try:
        session = await service.submit_session(session_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))

    return SessionOut(
        id=session.id,
        status=session.status.value,
        started_at=session.started_at,
        expires_at=session.expires_at,
        duration_minutes=session.duration_minutes,
        question_count=len(session.question_ids),
        warnings_count=session.warnings_count,
        integrity_score=session.integrity_score,
        percentage=session.percentage,
    )


@router.post("/proctor/events")
async def log_proctor_event(
    payload: ProctorEventRequest,
    db: AsyncSession = Depends(get_db),
):
    """Log a proctoring violation from the client."""
    service = ExamService(db)
    event = await service.log_proctor_event(
        session_id=payload.session_id,
        event_type=payload.event_type,
        severity=payload.severity,
        screenshot_url=payload.screenshot_url,
        metadata=payload.metadata,
    )
    return {"event_id": str(event.id), "logged": True}
