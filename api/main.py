"""Hyperion Fleet Manager API -- FastAPI application entry point.

Provides:
- CORS middleware with configurable origins
- Request-ID middleware that injects a correlation ID into every
  request/response cycle and binds it to structlog context vars
- A ``/health`` endpoint for load-balancer probes
- Lifespan handler that manages Redis connection pool startup / shutdown
- All versioned routers mounted under ``/api/v1``

Start locally with::

    uvicorn api.main:app --reload --host 0.0.0.0 --port 8000
"""

from __future__ import annotations

import uuid
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from typing import AsyncGenerator

import structlog
from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint

from api.config import Settings, get_settings

# ---------------------------------------------------------------------------
# Structured logging configuration
# ---------------------------------------------------------------------------


def _configure_logging(settings: Settings) -> None:
    """Set up structlog for JSON output with bound context vars."""
    structlog.configure(
        processors=[
            structlog.contextvars.merge_contextvars,
            structlog.stdlib.add_log_level,
            structlog.stdlib.add_logger_name,
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.processors.UnicodeDecoder(),
            structlog.processors.JSONRenderer(),
        ],
        wrapper_class=structlog.stdlib.BoundLogger,
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )


logger = structlog.get_logger(__name__)


# ---------------------------------------------------------------------------
# Lifespan handler (startup / shutdown)
# ---------------------------------------------------------------------------


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Manage application-level resources.

    * **Startup** -- open Redis connection pool.
    * **Shutdown** -- close Redis connection pool gracefully.
    """
    settings = get_settings()
    _configure_logging(settings)

    logger.info(
        "application_startup",
        api_version=settings.api_version,
        aws_region=settings.aws_region,
        log_level=settings.log_level,
    )

    # --- Redis connection pool ------------------------------------------------
    redis_pool = None
    try:
        import redis.asyncio as aioredis

        redis_pool = aioredis.from_url(
            settings.redis_url,
            decode_responses=True,
            max_connections=20,
        )
        # Verify connectivity
        await redis_pool.ping()
        app.state.redis = redis_pool
        logger.info("redis_connected", url=settings.redis_url)
    except Exception as exc:
        logger.warning("redis_connection_failed", error=str(exc))
        app.state.redis = None

    yield  # ---- application is running ----

    # --- Shutdown -------------------------------------------------------------
    if redis_pool is not None:
        await redis_pool.aclose()
        logger.info("redis_disconnected")

    logger.info("application_shutdown")


# ---------------------------------------------------------------------------
# Application factory
# ---------------------------------------------------------------------------


def create_app(settings: Settings | None = None) -> FastAPI:
    """Build and return the configured FastAPI application."""
    _settings = settings or get_settings()

    app = FastAPI(
        title=_settings.api_title,
        version=_settings.api_version,
        description=(
            "Enterprise-grade REST API for managing a fleet of 500+ "
            "Windows EC2 instances on AWS.  Provides instance inventory, "
            "remote command execution via SSM, and CloudWatch metrics queries."
        ),
        docs_url="/docs",
        redoc_url="/redoc",
        openapi_url="/openapi.json",
        lifespan=lifespan,
    )

    # --- CORS -----------------------------------------------------------------
    app.add_middleware(
        CORSMiddleware,
        allow_origins=_settings.cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
        expose_headers=["X-Request-ID"],
    )

    # --- Request-ID middleware ------------------------------------------------
    app.add_middleware(RequestIDMiddleware)

    # --- Exception handlers ---------------------------------------------------
    _register_exception_handlers(app)

    # --- Routers --------------------------------------------------------------
    _include_routers(app, _settings)

    return app


# ---------------------------------------------------------------------------
# Request-ID middleware
# ---------------------------------------------------------------------------


class RequestIDMiddleware(BaseHTTPMiddleware):
    """Inject a correlation ID into every request/response cycle.

    The middleware checks for an incoming ``X-Request-ID`` header and
    reuses it if present; otherwise a new UUID-4 is generated.  The ID
    is bound to structlog context vars so every log line emitted during
    the request carries it automatically.
    """

    async def dispatch(
        self, request: Request, call_next: RequestResponseEndpoint
    ) -> Response:
        request_id = request.headers.get("x-request-id", str(uuid.uuid4()))

        # Bind to structlog context for the duration of the request
        structlog.contextvars.clear_contextvars()
        structlog.contextvars.bind_contextvars(
            request_id=request_id,
            method=request.method,
            path=request.url.path,
        )

        # Store on request state so handlers can read it
        request.state.request_id = request_id

        logger.info("request_started")
        response = await call_next(request)
        response.headers["X-Request-ID"] = request_id
        logger.info("request_completed", status_code=response.status_code)

        return response


# ---------------------------------------------------------------------------
# Exception handlers
# ---------------------------------------------------------------------------


def _register_exception_handlers(app: FastAPI) -> None:
    """Attach global exception handlers for consistent error shapes."""

    @app.exception_handler(Exception)
    async def _unhandled_exception_handler(
        request: Request, exc: Exception
    ) -> JSONResponse:
        request_id = getattr(request.state, "request_id", None)
        logger.error("unhandled_exception", error=str(exc), exc_info=exc)
        return JSONResponse(
            status_code=500,
            content={
                "success": False,
                "error": {
                    "code": "INTERNAL_SERVER_ERROR",
                    "message": "An unexpected error occurred.",
                },
                "request_id": request_id,
                "timestamp": datetime.now(timezone.utc).isoformat(),
            },
        )


# ---------------------------------------------------------------------------
# Router registration
# ---------------------------------------------------------------------------


def _include_routers(app: FastAPI, settings: Settings) -> None:
    """Mount all versioned endpoint routers.

    Import routers lazily so the module can be loaded even when endpoint
    files have not been created yet (handy during incremental dev).
    """
    prefix = settings.api_prefix

    # Health check is always available (no auth, no versioned prefix)
    @app.get(
        "/health",
        tags=["health"],
        summary="Health check",
        response_model=dict,
    )
    async def health_check() -> dict:
        """Lightweight liveness probe for load balancers and orchestrators."""
        return {
            "status": "healthy",
            "version": settings.api_version,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }

    # Attempt to import and mount endpoint routers.
    # If an endpoints module does not exist yet, log a warning and continue.
    _router_specs = [
        ("api.endpoints.instances", "router", "/instances", ["instances"]),
        ("api.endpoints.commands", "router", "/commands", ["commands"]),
        ("api.endpoints.metrics", "router", "/metrics", ["metrics"]),
        ("api.endpoints.compliance", "router", "/compliance", ["compliance"]),
    ]

    for module_path, attr_name, sub_prefix, tags in _router_specs:
        try:
            import importlib

            mod = importlib.import_module(module_path)
            router = getattr(mod, attr_name)
            app.include_router(router, prefix=f"{prefix}{sub_prefix}", tags=tags)
            logger.info("router_registered", module=module_path, prefix=f"{prefix}{sub_prefix}")
        except (ModuleNotFoundError, AttributeError) as exc:
            logger.debug(
                "router_skipped",
                module=module_path,
                reason=str(exc),
            )

    # Health router is mounted without the versioned prefix so that
    # load balancers and orchestrators can reach /health directly.
    try:
        import importlib

        health_mod = importlib.import_module("api.endpoints.health")
        health_router = getattr(health_mod, "router")
        app.include_router(health_router, tags=["health"])
        logger.info("router_registered", module="api.endpoints.health", prefix="/health")
    except (ModuleNotFoundError, AttributeError) as exc:
        logger.debug("router_skipped", module="api.endpoints.health", reason=str(exc))


# ---------------------------------------------------------------------------
# Module-level app instance (used by ``uvicorn api.main:app``)
# ---------------------------------------------------------------------------

app = create_app()
