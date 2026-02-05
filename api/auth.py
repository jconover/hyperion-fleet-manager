"""Authentication and authorisation layer.

Supports two authentication mechanisms:
1. **API key** -- passed via the X-API-Key header (configurable).
2. **JWT bearer token** -- passed via the standard Authorization header.

Both mechanisms resolve to a ``User`` object injected into route handlers
through FastAPI's dependency-injection system.

A simple in-memory rate limiter is also provided.  For production use,
replace the in-memory store with Redis (see ``dependencies.py``).
"""

from __future__ import annotations

import time
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from typing import Optional

import structlog
from fastapi import Depends, HTTPException, Request, Security, status
from fastapi.security import APIKeyHeader, HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from pydantic import BaseModel

from api.config import Settings, get_settings

logger = structlog.get_logger(__name__)


# ---------------------------------------------------------------------------
# User model
# ---------------------------------------------------------------------------

class User(BaseModel):
    """Authenticated caller identity."""

    subject: str
    scopes: list[str] = []
    auth_method: str = "api_key"  # "api_key" | "jwt"


# ---------------------------------------------------------------------------
# Security schemes
# ---------------------------------------------------------------------------

_api_key_scheme = APIKeyHeader(name="X-API-Key", auto_error=False)
_bearer_scheme = HTTPBearer(auto_error=False)


# ---------------------------------------------------------------------------
# API-key validation
# ---------------------------------------------------------------------------

async def _validate_api_key(
    api_key: Optional[str],
    settings: Settings,
) -> Optional[User]:
    """Check the API key against a known set.

    In production, look this up in a database or Secrets Manager.
    For the prototype, accept any non-empty key that matches
    ``settings.jwt_secret`` (acting as a shared secret).
    """
    if not api_key:
        return None

    # Constant-time comparison would be ideal; for a portfolio project
    # a straightforward check is acceptable.
    if api_key == settings.jwt_secret:
        return User(subject="api-key-user", scopes=["fleet:read", "fleet:write"], auth_method="api_key")

    return None


# ---------------------------------------------------------------------------
# JWT validation
# ---------------------------------------------------------------------------

async def _validate_jwt(
    credentials: Optional[HTTPAuthorizationCredentials],
    settings: Settings,
) -> Optional[User]:
    """Decode and verify a JWT bearer token."""
    if credentials is None:
        return None

    token = credentials.credentials
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=[settings.jwt_algorithm],
        )
        sub: Optional[str] = payload.get("sub")
        if sub is None:
            return None
        scopes: list[str] = payload.get("scopes", [])
        return User(subject=sub, scopes=scopes, auth_method="jwt")
    except JWTError as exc:
        logger.warning("jwt_decode_failed", error=str(exc))
        return None


# ---------------------------------------------------------------------------
# JWT token creation (utility for tests / login endpoint)
# ---------------------------------------------------------------------------

def create_access_token(
    subject: str,
    scopes: list[str] | None = None,
    settings: Settings | None = None,
) -> str:
    """Mint a signed JWT access token."""
    _settings = settings or get_settings()
    now = datetime.now(timezone.utc)
    expire = now + timedelta(minutes=_settings.jwt_expiration_minutes)
    payload = {
        "sub": subject,
        "scopes": scopes or [],
        "iat": now,
        "exp": expire,
    }
    return jwt.encode(payload, _settings.jwt_secret, algorithm=_settings.jwt_algorithm)


# ---------------------------------------------------------------------------
# Combined dependency -- try API key first, then JWT
# ---------------------------------------------------------------------------

async def get_current_user(
    request: Request,
    api_key: Optional[str] = Security(_api_key_scheme),
    bearer: Optional[HTTPAuthorizationCredentials] = Security(_bearer_scheme),
    settings: Settings = Depends(get_settings),
) -> User:
    """Resolve the authenticated user from the request.

    Tries API-key authentication first, then falls back to JWT bearer.
    Raises 401 if neither mechanism succeeds.
    """
    user = await _validate_api_key(api_key, settings)
    if user is not None:
        structlog.contextvars.bind_contextvars(auth_subject=user.subject, auth_method="api_key")
        return user

    user = await _validate_jwt(bearer, settings)
    if user is not None:
        structlog.contextvars.bind_contextvars(auth_subject=user.subject, auth_method="jwt")
        return user

    logger.warning("authentication_failed", path=request.url.path)
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or missing authentication credentials.",
        headers={"WWW-Authenticate": "Bearer"},
    )


# ---------------------------------------------------------------------------
# Rate limiter (in-memory -- swap for Redis in production)
# ---------------------------------------------------------------------------

class RateLimiter:
    """Sliding-window rate limiter.

    Parameters
    ----------
    max_requests:
        Maximum number of requests allowed within ``window_seconds``.
    window_seconds:
        Length of the sliding window.
    """

    def __init__(self, max_requests: int = 100, window_seconds: int = 60) -> None:
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self._hits: dict[str, list[float]] = defaultdict(list)

    def _client_key(self, request: Request) -> str:
        """Derive a rate-limit key from the request.

        Uses the API key if present, otherwise falls back to the
        client IP address.
        """
        api_key = request.headers.get("x-api-key", "")
        if api_key:
            return f"apikey:{api_key}"
        forwarded = request.headers.get("x-forwarded-for")
        if forwarded:
            return f"ip:{forwarded.split(',')[0].strip()}"
        client = request.client
        host = client.host if client else "unknown"
        return f"ip:{host}"

    async def __call__(self, request: Request) -> None:
        """FastAPI dependency -- raises 429 when the limit is exceeded."""
        key = self._client_key(request)
        now = time.monotonic()
        window_start = now - self.window_seconds

        # Purge expired timestamps
        hits = self._hits[key]
        self._hits[key] = [t for t in hits if t > window_start]
        hits = self._hits[key]

        if len(hits) >= self.max_requests:
            logger.warning(
                "rate_limit_exceeded",
                client_key=key,
                limit=self.max_requests,
                window=self.window_seconds,
            )
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Rate limit exceeded. Maximum {self.max_requests} requests per {self.window_seconds}s.",
            )

        hits.append(now)


# Default limiter instance (100 req / 60 s)
rate_limiter = RateLimiter(max_requests=100, window_seconds=60)
