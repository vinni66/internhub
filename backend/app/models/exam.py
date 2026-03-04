import enum
import uuid
from typing import Optional

from sqlalchemy import (
    String, Integer, Boolean, SmallInteger, Text,
    ForeignKey, Enum as SAEnum, Float
)
from sqlalchemy.dialects.postgresql import UUID, JSONB, ARRAY
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class QuestionType(str, enum.Enum):
    MCQ = "mcq"
    TRUE_FALSE = "true_false"
    FILL_BLANK = "fill_blank"
    CODING = "coding"
    ESSAY = "essay"


class QuestionDifficulty(str, enum.Enum):
    EASY = "easy"
    MEDIUM = "medium"
    HARD = "hard"


class SessionStatus(str, enum.Enum):
    PENDING = "pending"
    ACTIVE = "active"
    PAUSED = "paused"
    SUBMITTED = "submitted"
    FLAGGED = "flagged"
    COMPLETED = "completed"
    EXPIRED = "expired"


class ProctorEventType(str, enum.Enum):
    TAB_SWITCH = "tab_switch"
    FACE_NOT_DETECTED = "face_not_detected"
    MULTIPLE_FACES = "multiple_faces"
    LOOKING_AWAY = "looking_away"
    PHONE_DETECTED = "phone_detected"
    VOICE_DETECTED = "voice_detected"
    SUSPICIOUS_KEYSTROKES = "suspicious_keystrokes"
    COPY_PASTE = "copy_paste"
    FULLSCREEN_EXIT = "fullscreen_exit"


class Question(Base, TimestampMixin):
    __tablename__ = "questions"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    internship_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True), ForeignKey("internships.id", ondelete="CASCADE"), nullable=True
    )
    question_type: Mapped[QuestionType] = mapped_column(SAEnum(QuestionType), nullable=False)
    difficulty: Mapped[QuestionDifficulty] = mapped_column(
        SAEnum(QuestionDifficulty), default=QuestionDifficulty.MEDIUM
    )
    topic: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    question_text: Mapped[str] = mapped_column(Text, nullable=False)
    # MCQ: [{"text": "...", "is_correct": true}, ...]
    options: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True)
    correct_answer: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    explanation: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    marks: Mapped[int] = mapped_column(SmallInteger, default=1)
    negative_marks: Mapped[float] = mapped_column(Float, default=0.0)
    time_limit_seconds: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    # Tags for AI-based recommendation and gap analysis
    tags: Mapped[Optional[list]] = mapped_column(ARRAY(String), nullable=True)

    # Relationships
    answers: Mapped[list["StudentAnswer"]] = relationship(
        "StudentAnswer", back_populates="question"
    )


class ExamSession(Base, TimestampMixin):
    __tablename__ = "exam_sessions"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    student_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    internship_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("internships.id", ondelete="CASCADE"), nullable=False
    )
    status: Mapped[SessionStatus] = mapped_column(
        SAEnum(SessionStatus), default=SessionStatus.PENDING
    )
    # Ordered question IDs for this session
    question_ids: Mapped[list] = mapped_column(JSONB, default=list)
    started_at: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    submitted_at: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    expires_at: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    duration_minutes: Mapped[int] = mapped_column(SmallInteger, default=60)

    # Scoring
    total_marks: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    obtained_marks: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    percentage: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    rank: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    # Integrity
    integrity_score: Mapped[Optional[int]] = mapped_column(SmallInteger, nullable=True)
    warnings_count: Mapped[int] = mapped_column(SmallInteger, default=0)
    is_flagged: Mapped[bool] = mapped_column(Boolean, default=False)
    flag_reason: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # Device fingerprint at exam start
    device_fingerprint: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)

    # Relationships
    answers: Mapped[list["StudentAnswer"]] = relationship(
        "StudentAnswer", back_populates="session"
    )
    proctor_events: Mapped[list["ProctorEvent"]] = relationship(
        "ProctorEvent", back_populates="session"
    )


class StudentAnswer(Base, TimestampMixin):
    __tablename__ = "student_answers"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    session_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("exam_sessions.id", ondelete="CASCADE"), nullable=False
    )
    question_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("questions.id", ondelete="CASCADE"), nullable=False
    )
    answer_text: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    selected_option_index: Mapped[Optional[int]] = mapped_column(SmallInteger, nullable=True)
    is_correct: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)
    marks_awarded: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    time_spent_seconds: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    # Relationships
    session: Mapped["ExamSession"] = relationship("ExamSession", back_populates="answers")
    question: Mapped["Question"] = relationship("Question", back_populates="answers")


class ProctorEvent(Base, TimestampMixin):
    __tablename__ = "proctor_events"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    session_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("exam_sessions.id", ondelete="CASCADE"), nullable=False
    )
    event_type: Mapped[ProctorEventType] = mapped_column(
        SAEnum(ProctorEventType), nullable=False
    )
    severity: Mapped[int] = mapped_column(SmallInteger, default=1)  # 1=low, 2=medium, 3=high
    screenshot_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    event_metadata: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True)

    # Relationship
    session: Mapped["ExamSession"] = relationship("ExamSession", back_populates="proctor_events")
