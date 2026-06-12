from datetime import datetime

from sqlalchemy import Boolean, DateTime, Enum, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[str] = mapped_column(Enum("student", "doctor", "it_admin"), nullable=False)
    full_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    is_blocked: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
    last_login: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    activity_logs_as_admin: Mapped[list["AdminActivityLog"]] = relationship(
        "AdminActivityLog", foreign_keys="AdminActivityLog.admin_id", back_populates="admin"
    )
    warnings_received: Mapped[list["Warning"]] = relationship(
        "Warning", foreign_keys="Warning.to_user_id", back_populates="target_user"
    )
    warnings_sent: Mapped[list["Warning"]] = relationship(
        "Warning", foreign_keys="Warning.from_admin_id", back_populates="from_admin"
    )
    usage_stats: Mapped[list["AppUsageStat"]] = relationship(
        "AppUsageStat", back_populates="user"
    )


class AdminActivityLog(Base):
    __tablename__ = "admin_activity_log"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    admin_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False)
    action: Mapped[str] = mapped_column(String(255), nullable=False)
    target_user_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("users.id"), nullable=True
    )
    timestamp: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
    ip_address: Mapped[str | None] = mapped_column(String(45), nullable=True)

    admin: Mapped["User"] = relationship(
        "User", foreign_keys=[admin_id], back_populates="activity_logs_as_admin"
    )
    target_user: Mapped["User | None"] = relationship("User", foreign_keys=[target_user_id])


class AppUsageStat(Base):
    __tablename__ = "app_usage_stats"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False)
    action_type: Mapped[str] = mapped_column(String(100), nullable=False)
    timestamp: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    user: Mapped["User"] = relationship("User", back_populates="usage_stats")


class Warning(Base):
    __tablename__ = "warnings"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    from_admin_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False)
    to_user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False)
    message: Mapped[str] = mapped_column(Text, nullable=False)
    is_read: Mapped[bool] = mapped_column(Boolean, default=False)
    sent_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    from_admin: Mapped["User"] = relationship(
        "User", foreign_keys=[from_admin_id], back_populates="warnings_sent"
    )
    target_user: Mapped["User"] = relationship(
        "User", foreign_keys=[to_user_id], back_populates="warnings_received"
    )
