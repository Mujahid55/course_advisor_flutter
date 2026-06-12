import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.database import AsyncSessionLocal, engine
from app.models.db_models import User
from app.models import db_models  # noqa: F401 — registers ORM models with Base
from app.database import Base
from app.routes import chat, health, upload
from app.routes import auth, admin, analytics, users
from app.services.auth import hash_password
from app.services.session import session_store
from sqlalchemy import select

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("course_advisor")


async def _cleanup_loop() -> None:
    while True:
        await asyncio.sleep(settings.session_cleanup_interval)
        await session_store.purge_expired()


async def _init_db() -> None:
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    logger.info("Database tables created/verified")

    async with AsyncSessionLocal() as db:
        result = await db.execute(select(User).where(User.role == "it_admin"))
        if not result.scalar_one_or_none():
            admin_user = User(
                email="admin@courseadvisor.com",
                password_hash=hash_password("Admin@12345"),
                role="it_admin",
                full_name="System Admin",
                is_active=True,
                is_blocked=False,
            )
            db.add(admin_user)
            await db.commit()
            logger.info("Default admin seeded: admin@courseadvisor.com / Admin@12345")


@asynccontextmanager
async def lifespan(app: FastAPI):
    await _init_db()
    task = asyncio.create_task(_cleanup_loop())
    logger.info(
        "CourseAdvisor API started (cleanup every %ds, TTL %ds)",
        settings.session_cleanup_interval,
        settings.session_ttl_seconds,
    )
    yield
    task.cancel()
    try:
        await task
    except asyncio.CancelledError:
        pass
    logger.info("CourseAdvisor API shut down cleanly")


app = FastAPI(
    title="CourseAdvisor API",
    version="2.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router)
app.include_router(upload.router)
app.include_router(chat.router)
app.include_router(auth.router)
app.include_router(admin.router)
app.include_router(analytics.router)
app.include_router(users.router)
