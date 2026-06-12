import logging
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.db_models import AppUsageStat, User
from app.models.schemas import (
    LoginRequest,
    LoginResponse,
    RegisterRequest,
    RegisterResponse,
    UserProfileResponse,
)
from app.services.auth import (
    create_access_token,
    get_current_user,
    hash_password,
    verify_password,
)

logger = logging.getLogger("course_advisor.auth")
router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=RegisterResponse, status_code=status.HTTP_201_CREATED)
async def register(request: RegisterRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == request.email))
    if result.scalar_one_or_none():
        raise HTTPException(status_code=409, detail="Email already registered.")

    user = User(
        email=request.email,
        password_hash=hash_password(request.password),
        full_name=request.full_name,
        role=request.role,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)

    token = create_access_token({"sub": str(user.id), "role": user.role})
    logger.info("User %s registered as %s", user.email, user.role)
    return RegisterResponse(
        user_id=user.id, email=user.email, role=user.role, access_token=token
    )


@router.post("/login", response_model=LoginResponse)
async def login(request: LoginRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(User).where(User.email == request.email.strip().lower())
    )
    user = result.scalar_one_or_none()

    if not user or not verify_password(request.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid email or password.")

    if user.is_blocked:
        raise HTTPException(status_code=403, detail="Account is blocked. Contact admin.")

    if not user.is_active:
        raise HTTPException(status_code=403, detail="Account is inactive. Contact admin.")

    user.last_login = datetime.utcnow()
    db.add(AppUsageStat(user_id=user.id, action_type="login"))
    await db.commit()

    token = create_access_token({"sub": str(user.id), "role": user.role})
    logger.info("User %s logged in", user.email)
    return LoginResponse(
        access_token=token,
        token_type="bearer",
        role=user.role,
        full_name=user.full_name or "",
    )


@router.get("/me", response_model=UserProfileResponse)
async def get_me(current_user: User = Depends(get_current_user)):
    return UserProfileResponse.model_validate(current_user)
