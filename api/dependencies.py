"""Shared FastAPI dependencies.

All AWS client factories use aioboto3 for non-blocking I/O so route
handlers never block the event loop on network calls.  Each dependency
yields a client scoped to the request lifetime, ensuring sessions are
properly closed.

Redis and database connections are managed as application-level
singletons initialised during the lifespan handler in ``main.py``.
"""

from __future__ import annotations

from typing import AsyncGenerator

import aioboto3
import structlog
from fastapi import Depends, Request

from api.config import Settings, get_settings

logger = structlog.get_logger(__name__)


# ---------------------------------------------------------------------------
# AWS session
# ---------------------------------------------------------------------------

def _get_aioboto3_session(settings: Settings | None = None) -> aioboto3.Session:
    """Create an aioboto3 session configured for the target region."""
    _settings = settings or get_settings()
    return aioboto3.Session(region_name=_settings.aws_region)


async def get_aws_session(
    settings: Settings = Depends(get_settings),
) -> aioboto3.Session:
    """Return an aioboto3 session as a FastAPI dependency."""
    return _get_aioboto3_session(settings)


# ---------------------------------------------------------------------------
# EC2 async client
# ---------------------------------------------------------------------------

async def get_ec2_client(
    settings: Settings = Depends(get_settings),
) -> AsyncGenerator:
    """Yield an async EC2 client, closing it after the request."""
    session = _get_aioboto3_session(settings)
    async with session.client("ec2") as client:
        yield client


# ---------------------------------------------------------------------------
# SSM async client
# ---------------------------------------------------------------------------

async def get_ssm_client(
    settings: Settings = Depends(get_settings),
) -> AsyncGenerator:
    """Yield an async SSM client, closing it after the request."""
    session = _get_aioboto3_session(settings)
    async with session.client("ssm") as client:
        yield client


# ---------------------------------------------------------------------------
# CloudWatch async client
# ---------------------------------------------------------------------------

async def get_cloudwatch_client(
    settings: Settings = Depends(get_settings),
) -> AsyncGenerator:
    """Yield an async CloudWatch client, closing it after the request."""
    session = _get_aioboto3_session(settings)
    async with session.client("cloudwatch") as client:
        yield client


# ---------------------------------------------------------------------------
# Redis
# ---------------------------------------------------------------------------

async def get_redis(request: Request):
    """Retrieve the application-level Redis connection pool.

    The pool is initialised during application startup (see ``main.py``
    lifespan handler) and stored on ``app.state``.  Returns ``None``
    when Redis is not configured or unavailable so callers can degrade
    gracefully.
    """
    redis = getattr(request.app.state, "redis", None)
    if redis is None:
        logger.debug("redis_not_available")
    return redis
