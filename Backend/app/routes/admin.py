import logging
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.models.db_models import AdminActivityLog, AppUsageStat, User, Warning
from app.models.schemas import (
    ActivityLogItemResponse,
    BlockUserRequest,
    PaginatedActivityLogResponse,
    PaginatedUsersResponse,
    UpdateStatusRequest,
    UserDetailResponse,
    UserListItemResponse,
    WarningItemResponse,
    WarnUserRequest,
)
from app.services.auth import get_current_admin

logger = logging.getLogger("course_advisor.admin")
router = APIRouter(prefix="/admin", tags=["admin"])


def _ip(request: Request) -> Optional[str]:
    return request.client.host if request.client else None


async def _log_action(
    db: AsyncSession,
    admin_id: int,
    action: str,
    target_user_id: Optional[int] = None,
    ip_address: Optional[str] = None,
) -> None:
    db.add(
        AdminActivityLog(
            admin_id=admin_id,
            action=action,
            target_user_id=target_user_id,
            ip_address=ip_address,
        )
    )


# ---------------------------------------------------------------------------
# GET /admin/users
# ---------------------------------------------------------------------------

@router.get("/users", response_model=PaginatedUsersResponse)
async def list_users(
    page: int = 1,
    limit: int = 20,
    role: Optional[str] = None,
    is_active: Optional[bool] = None,
    is_blocked: Optional[bool] = None,
    search: Optional[str] = None,
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    query = select(User)
    if role:
        query = query.where(User.role == role)
    if is_active is not None:
        query = query.where(User.is_active == is_active)
    if is_blocked is not None:
        query = query.where(User.is_blocked == is_blocked)
    if search:
        pattern = f"%{search}%"
        query = query.where(
            User.email.like(pattern) | User.full_name.like(pattern)
        )

    total_result = await db.execute(
        select(func.count()).select_from(query.subquery())
    )
    total = total_result.scalar() or 0

    query = query.order_by(User.created_at.desc()).offset((page - 1) * limit).limit(limit)
    result = await db.execute(query)
    users = result.scalars().all()

    return PaginatedUsersResponse(
        total=total,
        page=page,
        limit=limit,
        items=[UserListItemResponse.model_validate(u) for u in users],
    )


# ---------------------------------------------------------------------------
# GET /admin/users/{user_id}
# ---------------------------------------------------------------------------

@router.get("/users/{user_id}", response_model=UserDetailResponse)
async def get_user(
    user_id: int,
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(User).options(selectinload(User.warnings_received)).where(User.id == user_id)
    )
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found.")

    return UserDetailResponse(
        id=user.id,
        email=user.email,
        full_name=user.full_name,
        role=user.role,
        is_active=user.is_active,
        is_blocked=user.is_blocked,
        created_at=user.created_at,
        last_login=user.last_login,
        warnings=[WarningItemResponse.model_validate(w) for w in user.warnings_received],
    )


# ---------------------------------------------------------------------------
# PATCH /admin/users/{user_id}/status
# ---------------------------------------------------------------------------

@router.patch("/users/{user_id}/status")
async def update_user_status(
    user_id: int,
    body: UpdateStatusRequest,
    http_request: Request,
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found.")

    user.is_active = body.is_active
    action = f"set user #{user_id} active={body.is_active}"
    await _log_action(db, current_admin.id, action, user_id, _ip(http_request))
    await db.commit()
    logger.info("Admin %s: %s", current_admin.email, action)
    return {"detail": "Status updated."}


# ---------------------------------------------------------------------------
# POST /admin/users/{user_id}/block
# ---------------------------------------------------------------------------

@router.post("/users/{user_id}/block")
async def block_user(
    user_id: int,
    body: BlockUserRequest,
    http_request: Request,
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found.")
    if user.role == "it_admin":
        raise HTTPException(status_code=400, detail="Cannot block another admin.")

    user.is_blocked = True
    user.is_active = False
    action = f"blocked user #{user_id}: {body.reason}"
    await _log_action(db, current_admin.id, action, user_id, _ip(http_request))
    await db.commit()
    logger.info("Admin %s: %s", current_admin.email, action)
    return {"detail": "User blocked."}


# ---------------------------------------------------------------------------
# POST /admin/users/{user_id}/unblock
# ---------------------------------------------------------------------------

@router.post("/users/{user_id}/unblock")
async def unblock_user(
    user_id: int,
    http_request: Request,
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found.")

    user.is_blocked = False
    user.is_active = True
    action = f"unblocked user #{user_id}"
    await _log_action(db, current_admin.id, action, user_id, _ip(http_request))
    await db.commit()
    logger.info("Admin %s: %s", current_admin.email, action)
    return {"detail": "User unblocked."}


# ---------------------------------------------------------------------------
# POST /admin/users/{user_id}/warn
# ---------------------------------------------------------------------------

@router.post("/users/{user_id}/warn")
async def warn_user(
    user_id: int,
    body: WarnUserRequest,
    http_request: Request,
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found.")

    db.add(Warning(
        from_admin_id=current_admin.id,
        to_user_id=user_id,
        message=body.message,
    ))
    action = f"sent warning to user #{user_id}"
    await _log_action(db, current_admin.id, action, user_id, _ip(http_request))
    await db.commit()
    logger.info("Admin %s: %s", current_admin.email, action)
    return {"detail": "Warning sent."}


# ---------------------------------------------------------------------------
# GET /admin/activity-log
# ---------------------------------------------------------------------------

@router.get("/activity-log", response_model=PaginatedActivityLogResponse)
async def get_activity_log(
    page: int = 1,
    limit: int = 20,
    admin_id: Optional[int] = None,
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    query = select(AdminActivityLog).options(selectinload(AdminActivityLog.admin))
    if admin_id:
        query = query.where(AdminActivityLog.admin_id == admin_id)
    if date_from:
        query = query.where(AdminActivityLog.timestamp >= datetime.fromisoformat(date_from))
    if date_to:
        query = query.where(AdminActivityLog.timestamp <= datetime.fromisoformat(date_to))

    total_result = await db.execute(
        select(func.count()).select_from(query.subquery())
    )
    total = total_result.scalar() or 0

    query = (
        query.order_by(AdminActivityLog.timestamp.desc())
        .offset((page - 1) * limit)
        .limit(limit)
    )
    result = await db.execute(query)
    logs = result.scalars().all()

    items = [
        ActivityLogItemResponse(
            id=log.id,
            admin_id=log.admin_id,
            admin_name=log.admin.full_name if log.admin else None,
            action=log.action,
            target_user_id=log.target_user_id,
            timestamp=log.timestamp,
            ip_address=log.ip_address,
        )
        for log in logs
    ]

    return PaginatedActivityLogResponse(total=total, page=page, limit=limit, items=items)
