from typing import List

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    # OpenAI
    openai_api_key: str
    openai_model: str = "gpt-4o-mini"
    max_tokens: int = 800
    temperature: float = 0.4

    # File upload
    max_file_bytes: int = 10 * 1024 * 1024  # 10 MB

    # Session lifecycle
    session_ttl_seconds: int = 7200
    session_cleanup_interval: int = 300
    max_history_turns: int = 10

    # MySQL (Docker)
    mysql_host: str = "127.0.0.1"
    mysql_port: int = 3306
    mysql_user: str = "root"
    mysql_password: str = "root"
    mysql_database: str = "course_advisor"

    # JWT
    jwt_secret_key: str
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 1440

    # Server / RAG
    cors_origins: List[str] = ["*"]
    embedding_model_name: str = "all-MiniLM-L6-v2"
    chunk_size: int = 300
    rag_top_k: int = 3


settings = Settings()
