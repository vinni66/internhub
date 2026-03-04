from typing import Optional, List
from uuid import UUID
from datetime import datetime
from pydantic import BaseModel, field_validator


class InternshipCreate(BaseModel):
    title: str
    company_name: str
    description: str
    required_skills: List[str] = []
    min_cgpa: Optional[float] = None
    stipend_min: Optional[int] = None
    stipend_max: Optional[int] = None
    duration_weeks: Optional[int] = None
    mode: str = "hybrid"
    location: Optional[str] = None
    openings: int = 1
    application_deadline: Optional[str] = None

    @field_validator("mode")
    @classmethod
    def valid_mode(cls, v):
        if v not in ["remote", "onsite", "hybrid"]:
            raise ValueError("Mode must be remote, onsite, or hybrid")
        return v

    @field_validator("openings")
    @classmethod
    def valid_openings(cls, v):
        if v < 1:
            raise ValueError("Openings must be at least 1")
        return v


class InternshipUpdate(BaseModel):
    title: Optional[str] = None
    company_name: Optional[str] = None
    description: Optional[str] = None
    required_skills: Optional[List[str]] = None
    min_cgpa: Optional[float] = None
    stipend_min: Optional[int] = None
    stipend_max: Optional[int] = None
    duration_weeks: Optional[int] = None
    mode: Optional[str] = None
    location: Optional[str] = None
    openings: Optional[int] = None
    application_deadline: Optional[str] = None


class InternshipResponse(BaseModel):
    id: UUID
    created_by: UUID
    title: str
    company_name: str
    company_logo_url: Optional[str] = None
    description: str
    required_skills: List[str] = []
    min_cgpa: Optional[float] = None
    stipend_min: Optional[int] = None
    stipend_max: Optional[int] = None
    duration_weeks: Optional[int] = None
    mode: str
    location: Optional[str] = None
    openings: int
    application_deadline: Optional[str] = None
    is_published: bool
    is_active: bool

    model_config = {"from_attributes": True}


class PaginatedInternships(BaseModel):
    items: List[InternshipResponse]
    total: int
    page: int
    page_size: int
    pages: int


class ApplicationCreate(BaseModel):
    internship_id: UUID
    cover_letter: Optional[str] = None


class ApplicationResponse(BaseModel):
    id: UUID
    internship_id: UUID
    status: str
    cover_letter: Optional[str] = None
    applied_at: Optional[datetime] = None

    model_config = {"from_attributes": True}
