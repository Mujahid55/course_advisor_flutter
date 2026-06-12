import logging
from datetime import date, datetime, timedelta
from typing import List, Optional

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.db_models import AppUsageStat, User
from app.models.schemas import (
    AnalyticsOverviewResponse,
    DailyActiveUsersItem,
    FeatureUsageItem,
    TopActiveUserItem,
    UsageByHourItem,
    UsersByRoleResponse,
)
from app.services.auth import get_current_admin

logger = logging.getLogger("course_advisor.analytics")
router = APIRouter(prefix="/analytics", tags=["analytics"])


@router.get("/overview", response_model=AnalyticsOverviewResponse)
async def overview(
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    today = date.today()
    week_ago = datetime.utcnow() - timedelta(days=7)

    total_users = (await db.execute(select(func.count(User.id)))).scalar() or 0

    active_users_today = (
        await db.execute(
            select(func.count(func.distinct(AppUsageStat.user_id))).where(
                func.date(AppUsageStat.timestamp) == today
            )
        )
    ).scalar() or 0

    new_users_this_week = (
        await db.execute(
            select(func.count(User.id)).where(User.created_at >= week_ago)
        )
    ).scalar() or 0

    total_uploads_today = (
        await db.execute(
            select(func.count(AppUsageStat.id)).where(
                func.date(AppUsageStat.timestamp) == today,
                AppUsageStat.action_type == "upload",
            )
        )
    ).scalar() or 0

    total_chat_messages_today = (
        await db.execute(
            select(func.count(AppUsageStat.id)).where(
                func.date(AppUsageStat.timestamp) == today,
                AppUsageStat.action_type == "chat_message",
            )
        )
    ).scalar() or 0

    blocked_users_count = (
        await db.execute(select(func.count(User.id)).where(User.is_blocked == True))
    ).scalar() or 0

    return AnalyticsOverviewResponse(
        total_users=total_users,
        active_users_today=active_users_today,
        new_users_this_week=new_users_this_week,
        total_uploads_today=total_uploads_today,
        total_chat_messages_today=total_chat_messages_today,
        blocked_users_count=blocked_users_count,
    )


@router.get("/daily-active-users", response_model=List[DailyActiveUsersItem])
async def daily_active_users(
    days: int = 30,
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    start = datetime.utcnow() - timedelta(days=days)
    result = await db.execute(
        select(
            func.date(AppUsageStat.timestamp).label("day"),
            func.count(func.distinct(AppUsageStat.user_id)).label("count"),
        )
        .where(AppUsageStat.timestamp >= start)
        .group_by(func.date(AppUsageStat.timestamp))
        .order_by(func.date(AppUsageStat.timestamp))
    )
    rows = result.all()
    return [DailyActiveUsersItem(date=str(r.day), count=r.count) for r in rows]


@router.get("/usage-by-hour", response_model=List[UsageByHourItem])
async def usage_by_hour(
    target_date: Optional[str] = None,
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    day = date.fromisoformat(target_date) if target_date else date.today()
    result = await db.execute(
        select(
            func.hour(AppUsageStat.timestamp).label("hour"),
            func.count(AppUsageStat.id).label("count"),
        )
        .where(func.date(AppUsageStat.timestamp) == day)
        .group_by(func.hour(AppUsageStat.timestamp))
        .order_by(func.hour(AppUsageStat.timestamp))
    )
    rows = result.all()
    return [UsageByHourItem(hour=r.hour, count=r.count) for r in rows]


@router.get("/feature-usage", response_model=List[FeatureUsageItem])
async def feature_usage(
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(
            AppUsageStat.action_type.label("feature"),
            func.count(AppUsageStat.id).label("count"),
        )
        .group_by(AppUsageStat.action_type)
        .order_by(func.count(AppUsageStat.id).desc())
    )
    rows = result.all()
    return [FeatureUsageItem(feature=r.feature, count=r.count) for r in rows]


@router.get("/users-by-role", response_model=UsersByRoleResponse)
async def users_by_role(
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(User.role, func.count(User.id).label("count")).group_by(User.role)
    )
    counts: dict[str, int] = {r.role: r.count for r in result.all()}
    return UsersByRoleResponse(
        student=counts.get("student", 0),
        doctor=counts.get("doctor", 0),
        it_admin=counts.get("it_admin", 0),
    )


@router.get("/top-active-users", response_model=List[TopActiveUserItem])
async def top_active_users(
    limit: int = 10,
    current_admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(
            AppUsageStat.user_id,
            User.email,
            User.full_name,
            func.count(AppUsageStat.id).label("message_count"),
        )
        .join(User, User.id == AppUsageStat.user_id)
        .where(AppUsageStat.action_type == "chat_message")
        .group_by(AppUsageStat.user_id, User.email, User.full_name)
        .order_by(func.count(AppUsageStat.id).desc())
        .limit(limit)
    )
    rows = result.all()
    return [
        TopActiveUserItem(
            user_id=r.user_id,
            email=r.email,
            full_name=r.full_name,
            message_count=r.message_count,
        )
        for r in rows
    ]
