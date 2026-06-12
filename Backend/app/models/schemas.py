from datetime import datetime
from typing import List, Literal, Optional

from pydantic import BaseModel, ConfigDict, field_validator


# ---------------------------------------------------------------------------
# Existing schemas
# ---------------------------------------------------------------------------

class ChatRequest(BaseModel):
    message: str

    @field_validator("message")
    @classmethod
    def message_not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("message must not be empty")
        return v.strip()


class ChatResponse(BaseModel):
    reply: str


class HealthResponse(BaseModel):
    status: str
    version: str
    sessions_active: int


class DeleteResponse(BaseModel):
    deleted: bool


# ---------------------------------------------------------------------------
# Auth schemas
# ---------------------------------------------------------------------------

class RegisterRequest(BaseModel):
    email: str
    password: str
    full_name: str
    role: Literal["student", "doctor"]

    @field_validator("password")
    @classmethod
    def password_min_length(cls, v: str) -> str:
        if len(v) < 6:
            raise ValueError("password must be at least 6 characters")
        return v

    @field_validator("email")
    @classmethod
    def email_not_empty(cls, v: str) -> str:
        if not v.strip() or "@" not in v:
            raise ValueError("invalid email address")
        return v.strip().lower()


class RegisterResponse(BaseModel):
    user_id: int
    email: str
    role: str
    access_token: str


class LoginRequest(BaseModel):
    email: str
    password: str


class LoginResponse(BaseModel):
    access_token: str
    token_type: str
    role: str
    full_name: str


class UserProfileResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    email: str
    full_name: Optional[str]
    role: str
    is_active: bool
    is_blocked: bool
    created_at: datetime
    last_login: Optional[datetime]


# ---------------------------------------------------------------------------
# Admin — User management schemas
# ---------------------------------------------------------------------------

class UserListItemResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    email: str
    full_name: Optional[str]
    role: str
    is_active: bool
    is_blocked: bool
    created_at: datetime
    last_login: Optional[datetime]


class PaginatedUsersResponse(BaseModel):
    total: int
    page: int
    limit: int
    items: List[UserListItemResponse]


class WarningItemResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    message: str
    is_read: bool
    sent_at: datetime


class UserDetailResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    email: str
    full_name: Optional[str]
    role: str
    is_active: bool
    is_blocked: bool
    created_at: datetime
    last_login: Optional[datetime]
    warnings: List[WarningItemResponse] = []


class UpdateStatusRequest(BaseModel):
    is_active: bool


class BlockUserRequest(BaseModel):
    reason: str


class WarnUserRequest(BaseModel):
    message: str


class ActivityLogItemResponse(BaseModel):
    id: int
    admin_id: int
    admin_name: Optional[str]
    action: str
    target_user_id: Optional[int]
    timestamp: datetime
    ip_address: Optional[str]


class PaginatedActivityLogResponse(BaseModel):
    total: int
    page: int
    limit: int
    items: List[ActivityLogItemResponse]


# ---------------------------------------------------------------------------
# Analytics schemas
# ---------------------------------------------------------------------------

class AnalyticsOverviewResponse(BaseModel):
    total_users: int
    active_users_today: int
    new_users_this_week: int
    total_uploads_today: int
    total_chat_messages_today: int
    blocked_users_count: int


class DailyActiveUsersItem(BaseModel):
    date: str
    count: int


class UsageByHourItem(BaseModel):
    hour: int
    count: int


class FeatureUsageItem(BaseModel):
    feature: str
    count: int


class UsersByRoleResponse(BaseModel):
    student: int
    doctor: int
    it_admin: int


class TopActiveUserItem(BaseModel):
    user_id: int
    email: str
    full_name: Optional[str]
    message_count: int


# ---------------------------------------------------------------------------
# Warnings (student/doctor)
# ---------------------------------------------------------------------------

class WarningResponse(BaseModel):
    id: int
    message: str
    from_admin_name: Optional[str]
    sent_at: datetime
    is_read: bool
