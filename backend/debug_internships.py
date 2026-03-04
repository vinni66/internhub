import asyncio
from sqlalchemy import select
from app.db.session import AsyncSessionLocal
from app.models.internship import Internship

async def main():
    async with AsyncSessionLocal() as ds:
        result = await ds.execute(select(Internship))
        for i in result.scalars().all():
            print(f"Title: {i.title}, Published: {i.is_published}, Active: {i.is_active}, Deleted: {i.deleted_at}")

if __name__ == "__main__":
    asyncio.run(main())
