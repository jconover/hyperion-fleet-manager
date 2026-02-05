"""Application configuration via pydantic-settings.

All settings are loaded from environment variables with sensible defaults
for local development. In production, inject via container environment
or AWS Secrets Manager.
"""

from __future__ import annotations

from functools import lru_cache
from typing import List

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Central configuration for the Hyperion Fleet Manager API.

    Every attribute maps to an environment variable of the same name
    (case-insensitive).  Defaults target a local Docker Compose setup
    so the service starts without extra configuration during development.
    """

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # --- AWS ------------------------------------------------------------------
    aws_region: str = Field(
        default="us-east-1",
        description="Primary AWS region for EC2 / SSM / CloudWatch calls.",
    )
    aws_account_id: str = Field(
        default="",
        description="AWS account ID (used for ARN construction).",
    )

    # --- Data stores ----------------------------------------------------------
    database_url: str = Field(
        default="postgresql+asyncpg://hyperion:hyperion@localhost:5432/hyperion",
        description="Async SQLAlchemy connection string for PostgreSQL.",
    )
    redis_url: str = Field(
        default="redis://localhost:6379/0",
        description="Redis connection URL (used for caching and rate limiting).",
    )

    # --- Authentication -------------------------------------------------------
    api_key_header: str = Field(
        default="X-API-Key",
        description="HTTP header name that carries the API key.",
    )
    jwt_secret: str = Field(
        default="CHANGE-ME-in-production",
        description="HMAC secret for signing JWT access tokens.",
    )
    jwt_algorithm: str = Field(
        default="HS256",
        description="Algorithm used for JWT encoding / decoding.",
    )
    jwt_expiration_minutes: int = Field(
        default=60,
        description="Access-token lifetime in minutes.",
    )

    # --- Observability --------------------------------------------------------
    log_level: str = Field(
        default="INFO",
        description="Root log level (DEBUG, INFO, WARNING, ERROR, CRITICAL).",
    )
    cloudwatch_namespace: str = Field(
        default="Hyperion/FleetManager",
        description="CloudWatch custom-metric namespace.",
    )

    # --- CORS -----------------------------------------------------------------
    cors_origins: List[str] = Field(
        default=["http://localhost:3000", "http://localhost:8000"],
        description="Allowed origins for CORS. Use ['*'] only in development.",
    )

    # --- SSM ------------------------------------------------------------------
    ssm_command_timeout: int = Field(
        default=300,
        description="Maximum seconds to wait for an SSM Run Command invocation.",
    )

    # --- API ------------------------------------------------------------------
    api_title: str = "Hyperion Fleet Manager API"
    api_version: str = "1.0.0"
    api_prefix: str = "/api/v1"

    # --- Rate limiting --------------------------------------------------------
    rate_limit_per_minute: int = Field(
        default=100,
        description="Default rate limit (requests per minute per caller).",
    )

    @field_validator("log_level")
    @classmethod
    def _validate_log_level(cls, value: str) -> str:
        allowed = {"DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"}
        upper = value.upper()
        if upper not in allowed:
            raise ValueError(f"log_level must be one of {allowed}, got {value!r}")
        return upper


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Return a cached singleton of the application settings."""
    return Settings()
