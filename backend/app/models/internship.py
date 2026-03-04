import enum
import uuid
from typing import Optional

from sqlalchemy import String, Boolean, Integer, SmallInteger, Numeric, Text, ForeignKey, Enum as SAEnum
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class InternshipMode(str, enum.Enum):
    REMOTE = "remote"
    ONSITE = "onsite"
    HYBRID = "hybrid"


class Internship(Base, TimestampMixin):
    __tablename__ = "internships"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    created_by: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=False
    )
    title: Mapped[str] = mapped_column(String(300), nullable=False)
    company_name: Mapped[str] = mapped_column(String(200), nullable=False)
    company_logo_url: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    poster_url: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    required_skills: Mapped[list] = mapped_column(JSONB, default=list, server_default="[]")
    min_cgpa: Mapped[Optional[float]] = mapped_column(Numeric(4, 2), nullable=True)
    stipend_min: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    stipend_max: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    duration_weeks: Mapped[Optional[int]] = mapped_column(SmallInteger, nullable=True)
    mode: Mapped[InternshipMode] = mapped_column(
        SAEnum(InternshipMode, name="internship_mode"),
        nullable=False,
        default=InternshipMode.HYBRID,
    )
    location: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    openings: Mapped[int] = mapped_column(SmallInteger, nullable=False, default=1)
    application_deadline: Mapped[Optional[str]] = mapped_column(
        String(50), nullable=True
    )
    is_published: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    metadata_: Mapped[dict] = mapped_column(
        "metadata", JSONB, default=dict, server_default="{}"
    )

    # Relationships
    creator: Mapped["User"] = relationship("User", foreign_keys=[created_by])
    applications: Mapped[list] = relationship(
        "Application", back_populates="internship"
    )

    def __repr__(self) -> str:
        return f"<Internship id={self.id} title={self.title}>"
