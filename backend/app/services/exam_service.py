import uuid
import random
from datetime import datetime, timedelta, timezone
from typing import Optional
from sqlalchemy import select, update, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.exam import (
    ExamSession, Question, StudentAnswer, ProctorEvent,
    SessionStatus, ProctorEventType
)
from app.models.internship import Internship


class ExamService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def start_session(
        self,
        student_id: uuid.UUID,
        internship_id: uuid.UUID,
        device_fingerprint: Optional[str] = None,
        question_count: int = 20,
    ) -> ExamSession:
        """Create and activate a new exam session with randomized questions."""
        # Check for existing active session
        existing = await self.db.execute(
            select(ExamSession).where(
                ExamSession.student_id == student_id,
                ExamSession.internship_id == internship_id,
                ExamSession.status.in_([SessionStatus.ACTIVE, SessionStatus.PAUSED]),
            )
        )
        if active := existing.scalar_one_or_none():
            return active  # Resume existing session

        # Get questions for this internship
        result = await self.db.execute(
            select(Question.id).where(
                Question.internship_id == internship_id,
                Question.is_active.is_(True),
            )
        )
        question_ids = [str(r) for r in result.scalars().all()]

        if not question_ids:
            # Fallback: pull general questions
            result = await self.db.execute(
                select(Question.id).where(
                    Question.internship_id.is_(None),
                    Question.is_active.is_(True),
                ).limit(question_count)
            )
            question_ids = [str(r) for r in result.scalars().all()]

        # Randomize and cap
        random.shuffle(question_ids)
        selected_ids = question_ids[:question_count]

        now = datetime.now(timezone.utc)
        session = ExamSession(
            student_id=student_id,
            internship_id=internship_id,
            status=SessionStatus.ACTIVE,
            question_ids=selected_ids,
            started_at=now.isoformat(),
            expires_at=(now + timedelta(hours=1)).isoformat(),
            duration_minutes=60,
            device_fingerprint=device_fingerprint,
        )
        self.db.add(session)
        await self.db.commit()
        await self.db.refresh(session)
        return session

    async def submit_answer(
        self,
        session_id: uuid.UUID,
        question_id: uuid.UUID,
        answer_text: Optional[str] = None,
        selected_option_index: Optional[int] = None,
        time_spent_seconds: Optional[int] = None,
    ) -> StudentAnswer:
        """Record or update a student's answer to a question."""
        # Check if answer already exists (update scenario)
        result = await self.db.execute(
            select(StudentAnswer).where(
                StudentAnswer.session_id == session_id,
                StudentAnswer.question_id == question_id,
            )
        )
        existing = result.scalar_one_or_none()

        # Get the question for auto-grading
        q_result = await self.db.execute(
            select(Question).where(Question.id == question_id)
        )
        question = q_result.scalar_one_or_none()

        is_correct = None
        marks_awarded = None

        if question and question.options and selected_option_index is not None:
            opts = question.options if isinstance(question.options, list) else []
            if 0 <= selected_option_index < len(opts):
                is_correct = opts[selected_option_index].get("is_correct", False)
                marks_awarded = float(question.marks) if is_correct else -question.negative_marks

        if existing:
            existing.answer_text = answer_text
            existing.selected_option_index = selected_option_index
            existing.is_correct = is_correct
            existing.marks_awarded = marks_awarded
            existing.time_spent_seconds = time_spent_seconds
            await self.db.commit()
            return existing

        answer = StudentAnswer(
            session_id=session_id,
            question_id=question_id,
            answer_text=answer_text,
            selected_option_index=selected_option_index,
            is_correct=is_correct,
            marks_awarded=marks_awarded,
            time_spent_seconds=time_spent_seconds,
        )
        self.db.add(answer)
        await self.db.commit()
        await self.db.refresh(answer)
        return answer

    async def submit_session(self, session_id: uuid.UUID) -> ExamSession:
        """Finalize an exam session, calculate score and integrity."""
        result = await self.db.execute(
            select(ExamSession).where(ExamSession.id == session_id)
        )
        session = result.scalar_one_or_none()
        if not session:
            raise ValueError(f"Session {session_id} not found")

        # Calculate score
        ans_result = await self.db.execute(
            select(StudentAnswer).where(StudentAnswer.session_id == session_id)
        )
        answers = ans_result.scalars().all()

        obtained = sum(a.marks_awarded or 0 for a in answers)
        total = len(session.question_ids)  # 1 mark per question simplified

        # Calculate integrity score (100 - deductions based on events)
        events_result = await self.db.execute(
            select(ProctorEvent).where(ProctorEvent.session_id == session_id)
        )
        events = events_result.scalars().all()
        deduction = sum(e.severity * 5 for e in events)
        integrity = max(0, 100 - deduction)

        now = datetime.now(timezone.utc)
        session.status = SessionStatus.COMPLETED
        session.submitted_at = now.isoformat()
        session.obtained_marks = obtained
        session.total_marks = total
        session.percentage = round((obtained / total * 100) if total > 0 else 0, 2)
        session.integrity_score = integrity
        session.is_flagged = integrity < 70

        await self.db.commit()
        await self.db.refresh(session)
        return session

    async def log_proctor_event(
        self,
        session_id: uuid.UUID,
        event_type: str,
        severity: int = 1,
        screenshot_url: Optional[str] = None,
        metadata: Optional[dict] = None,
    ) -> ProctorEvent:
        """Log a proctoring violation event and update warning count."""
        event = ProctorEvent(
            session_id=session_id,
            event_type=ProctorEventType(event_type),
            severity=severity,
            screenshot_url=screenshot_url,
            event_metadata=metadata,
        )
        self.db.add(event)

        # Update warning counter on session
        await self.db.execute(
            update(ExamSession)
            .where(ExamSession.id == session_id)
            .values(warnings_count=ExamSession.warnings_count + 1)
        )
        await self.db.commit()
        return event

    async def get_session(self, session_id: uuid.UUID) -> Optional[ExamSession]:
        result = await self.db.execute(
            select(ExamSession).where(ExamSession.id == session_id)
        )
        return result.scalar_one_or_none()

    async def get_questions_for_session(
        self, session: ExamSession
    ) -> list[Question]:
        """Return ordered questions for a session."""
        if not session.question_ids:
            return []
        result = await self.db.execute(
            select(Question).where(
                Question.id.in_(
                    [uuid.UUID(i) for i in session.question_ids]
                )
            )
        )
        questions = result.scalars().all()
        # Preserve session order
        order_map = {str(q.id): i for i, q in enumerate(questions)}
        return sorted(questions, key=lambda q: session.question_ids.index(str(q.id))
                      if str(q.id) in session.question_ids else 999)

    async def get_active_sessions_for_internship(self, internship_id: uuid.UUID) -> list[dict]:
        from app.models.user import User
        # Fetch ACTIVE, PAUSED, and FLAGGED sessions
        result = await self.db.execute(
            select(ExamSession, User.email)
            .join(User, User.id == ExamSession.student_id)
            .where(
                ExamSession.internship_id == internship_id,
                ExamSession.status.in_([SessionStatus.ACTIVE, SessionStatus.PAUSED, SessionStatus.FLAGGED])
            )
            .order_by(ExamSession.started_at.desc())
        )
        sessions = []
        for session, email in result:
            sessions.append({
                "id": str(session.id),
                "student_id": str(session.student_id),
                "student_email": email,
                "status": session.status.value,
                "integrity_score": session.integrity_score,
                "is_flagged": session.is_flagged,
                "started_at": session.started_at,
                "duration_minutes": session.duration_minutes,
                "warnings_count": session.warnings_count,
            })
        return sessions

    async def get_session_events(self, session_id: uuid.UUID) -> list[ProctorEvent]:
        result = await self.db.execute(
            select(ProctorEvent)
            .where(ProctorEvent.session_id == session_id)
            .order_by(ProctorEvent.created_at.asc())
        )
        return list(result.scalars().all())

    async def override_session_flag(self, session_id: uuid.UUID, is_flagged: bool) -> ExamSession:
        result = await self.db.execute(
            select(ExamSession).where(ExamSession.id == session_id)
        )
        session = result.scalar_one_or_none()
        if not session:
            raise ValueError("Session not found")
        
        session.is_flagged = is_flagged
        await self.db.commit()
        await self.db.refresh(session)
        return session

