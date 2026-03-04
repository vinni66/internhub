import uuid
from typing import Optional, List

from sqlalchemy import String, Boolean, Numeric, SmallInteger, Text, ForeignKey
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class StudentProfile(Base, TimestampMixin):
    __tablename__ = "student_profiles"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )
    full_name: Mapped[str] = mapped_column(String(200), nullable=False)
    usn: Mapped[Optional[str]] = mapped_column(String(20), unique=True, nullable=True)
    department: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    semester: Mapped[Optional[int]] = mapped_column(SmallInteger, nullable=True)
    cgpa: Mapped[Optional[float]] = mapped_column(Numeric(4, 2), nullable=True)
    skills: Mapped[list] = mapped_column(JSONB, default=list, server_default="[]")
    interests: Mapped[list] = mapped_column(JSONB, default=list, server_default="[]")
    resume_url: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    linkedin_url: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    github_url: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    portfolio_url: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    bio: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    location: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    is_available: Mapped[bool] = mapped_column(Boolean, default=True)

    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="student_profile")
    applications: Mapped[List["Application"]] = relationship(
        "Application", back_populates="student"
    )

    def __repr__(self) -> str:
        return f"<StudentProfile id={self.id} name={self.full_name}>"
