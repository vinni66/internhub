import uuid
from typing import Optional

from sqlalchemy import String, Boolean, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class FacultyProfile(Base, TimestampMixin):
    __tablename__ = "faculty_profiles"

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
    employee_id: Mapped[Optional[str]] = mapped_column(
        String(50), unique=True, nullable=True
    )
    department: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    designation: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    can_create_exam: Mapped[bool] = mapped_column(Boolean, default=True)
    can_view_results: Mapped[bool] = mapped_column(Boolean, default=True)

    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="faculty_profile")

    def __repr__(self) -> str:
        return f"<FacultyProfile id={self.id} name={self.full_name}>"
