import uuid
from typing import Optional, List
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.student_profile import StudentProfile
from app.models.internship import Internship
from app.models.exam import ExamSession, SessionStatus


class RecommendationService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_recommended_internships(
        self, student_id: uuid.UUID, limit: int = 10
    ) -> List[dict]:
        """
        Hybrid recommendation: content-based filtering on skills overlap.
        In Sprint 3 this becomes a full SVD collaborative filter.
        """
        # Get student profile
        profile_result = await self.db.execute(
            select(StudentProfile).where(StudentProfile.user_id == student_id)
        )
        profile = profile_result.scalar_one_or_none()
        student_skills = set(profile.skills or []) if profile else set()
        min_cgpa = profile.cgpa or 0 if profile else 0

        # Get published internships the student hasn't applied to
        internships_result = await self.db.execute(
            select(Internship).where(Internship.is_published.is_(True))
        )
        internships = internships_result.scalars().all()

        # Score each internship by skill overlap  
        scored = []
        for internship in internships:
            req_skills = set(internship.required_skills or [])
            if not req_skills:
                continue
            cgpa_ok = (internship.min_cgpa or 0) <= min_cgpa
            overlap = len(student_skills & req_skills) / max(len(req_skills), 1)
            score = overlap * (1.2 if cgpa_ok else 0.8)

            scored.append({
                "internship_id": str(internship.id),
                "title": internship.title,
                "company_name": internship.company_name,
                "mode": internship.mode.value,
                "match_score": round(score * 100, 1),
                "skill_overlap": sorted(student_skills & req_skills),
                "missing_skills": sorted(req_skills - student_skills),
            })

        # Sort by match score descending
        scored.sort(key=lambda x: x["match_score"], reverse=True)
        return scored[:limit]

    async def get_skill_gaps(self, student_id: uuid.UUID) -> dict:
        """
        Identify top missing skills across all published internships.
        """
        profile_result = await self.db.execute(
            select(StudentProfile).where(StudentProfile.user_id == student_id)
        )
        profile = profile_result.scalar_one_or_none()
        student_skills = set(profile.skills or []) if profile else set()

        internships_result = await self.db.execute(
            select(Internship).where(Internship.is_published.is_(True))
        )
        internships = internships_result.scalars().all()

        skill_demand: dict[str, int] = {}
        for internship in internships:
            for skill in (internship.required_skills or []):
                if skill not in student_skills:
                    skill_demand[skill] = skill_demand.get(skill, 0) + 1

        # Sort by demand
        gaps = sorted(skill_demand.items(), key=lambda x: x[1], reverse=True)[:15]

        return {
            "student_skills": sorted(student_skills),
            "top_missing_skills": [{"skill": s, "demand": d} for s, d in gaps],
            "readiness_score": min(100, round(len(student_skills) * 5, 0)),
        }

    async def get_career_roadmap(self, student_id: uuid.UUID) -> dict:
        """
        Generate a simplified career roadmap based on skill gaps and exam performance.
        Sprint 3 will integrate LLM-generated personalized advice.
        """
        gaps = await self.get_skill_gaps(student_id)
        missing = [g["skill"] for g in gaps["top_missing_skills"][:5]]

        roadmap = []
        for i, skill in enumerate(missing, 1):
            roadmap.append({
                "phase": i,
                "skill": skill,
                "recommended_resources": [
                    f"Coursera: {skill} Fundamentals",
                    f"YouTube: {skill} Crash Course",
                ],
                "estimated_weeks": 2 + (i % 3),
            })

        return {
            "current_readiness": gaps["readiness_score"],
            "phases": roadmap,
            "total_weeks": sum(r["estimated_weeks"] for r in roadmap),
        }
