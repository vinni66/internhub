from typing import Optional, List
from uuid import UUID
from pydantic import BaseModel, field_validator


class StudentProfileUpdate(BaseModel):
    full_name: Optional[str] = None
    usn: Optional[str] = None
    department: Optional[str] = None
    semester: Optional[int] = None
    cgpa: Optional[float] = None
    skills: Optional[List[str]] = None
    interests: Optional[List[str]] = None
    linkedin_url: Optional[str] = None
    github_url: Optional[str] = None
    portfolio_url: Optional[str] = None
    bio: Optional[str] = None
    location: Optional[str] = None
    is_available: Optional[bool] = None

    @field_validator("cgpa")
    @classmethod
    def valid_cgpa(cls, v):
        if v is not None and not (0.0 <= v <= 10.0):
            raise ValueError("CGPA must be between 0.0 and 10.0")
        return v

    @field_validator("semester")
    @classmethod
    def valid_semester(cls, v):
        if v is not None and not (1 <= v <= 8):
            raise ValueError("Semester must be between 1 and 8")
        return v


class StudentProfileResponse(BaseModel):
    id: UUID
    user_id: UUID
    full_name: str
    usn: Optional[str] = None
    department: Optional[str] = None
    semester: Optional[int] = None
    cgpa: Optional[float] = None
    skills: List[str] = []
    interests: List[str] = []
    resume_url: Optional[str] = None
    linkedin_url: Optional[str] = None
    github_url: Optional[str] = None
    portfolio_url: Optional[str] = None
    bio: Optional[str] = None
    location: Optional[str] = None
    is_available: bool = True

    model_config = {"from_attributes": True}


class FacultyProfileUpdate(BaseModel):
    full_name: Optional[str] = None
    employee_id: Optional[str] = None
    department: Optional[str] = None
    designation: Optional[str] = None


class FacultyProfileResponse(BaseModel):
    id: UUID
    user_id: UUID
    full_name: str
    employee_id: Optional[str] = None
    department: Optional[str] = None
    designation: Optional[str] = None
    can_create_exam: bool
    can_view_results: bool

    model_config = {"from_attributes": True}
