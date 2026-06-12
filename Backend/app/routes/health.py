from fastapi import APIRouter

from app.models.schemas import HealthResponse
from app.services.session import session_store

router = APIRouter(tags=["meta"])


@router.get("/health", response_model=HealthResponse)
async def health_check() -> HealthResponse:
    return HealthResponse(
        status="ok",
        version="1.0.0",
        sessions_active=session_store.count,
    )
