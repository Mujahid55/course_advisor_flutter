import logging
from typing import List

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.db_models import User, Warning
from app.models.schemas import WarningResponse
from app.services.auth import get_current_user

logger = logging.getLogger("course_advisor.users")
router = APIRouter(prefix="/users", tags=["users"])


@router.get("/warnings", response_model=List[WarningResponse])
async def get_my_warnings(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Warning)
        .where(Warning.to_user_id == current_user.id, Warning.is_read == False)
        .order_by(Warning.sent_at.desc())
    )
    warnings = result.scalars().all()

    response = []
    for w in warnings:
        admin_result = await db.get(User, w.from_admin_id)
        response.append(
            WarningResponse(
                id=w.id,
                message=w.message,
                from_admin_name=admin_result.full_name if admin_result else None,
                sent_at=w.sent_at,
                is_read=w.is_read,
            )
        )
        w.is_read = True

    if warnings:
        await db.commit()

    return response
