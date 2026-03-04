import asyncio
from app.main import get_db
from app.models.user import User
from sqlalchemy.future import select

async def run():
    async for session in get_db():
        result = await session.execute(select(User))
        for r in result.scalars():
            print(f'DB USER: {r.email} | ROLE: {r.role}')
        break

asyncio.run(run())
