"""Common models shared across the API.

Provides standardised pagination, response wrappers, and error shapes
so every endpoint returns a consistent JSON structure.
"""

from __future__ import annotations

from datetime import datetime
from typing import Any, Generic, List, Optional, TypeVar

from pydantic import BaseModel, Field

T = TypeVar("T")


# ---------------------------------------------------------------------------
# Pagination
# ---------------------------------------------------------------------------

class PaginationParams(BaseModel):
    """Query parameters accepted by every list endpoint."""

    page: int = Field(default=1, ge=1, description="Page number (1-indexed).")
    page_size: int = Field(
        default=50, ge=1, le=200, description="Items per page (max 200)."
    )

    @property
    def offset(self) -> int:
        """Calculate the SQL OFFSET for the current page."""
        return (self.page - 1) * self.page_size


class PaginationMeta(BaseModel):
    """Pagination metadata returned alongside list results."""

    page: int
    page_size: int
    total_items: int
    total_pages: int


# ---------------------------------------------------------------------------
# Unified API response wrappers
# ---------------------------------------------------------------------------

class APIResponse(BaseModel, Generic[T]):
    """Standard envelope for all successful responses."""

    success: bool = True
    data: T
    meta: Optional[PaginationMeta] = None
    request_id: Optional[str] = Field(
        default=None, description="Correlation ID echoed from the request."
    )
    timestamp: datetime = Field(default_factory=datetime.utcnow)


# ---------------------------------------------------------------------------
# Error response
# ---------------------------------------------------------------------------

class ErrorDetail(BaseModel):
    """Machine-readable detail about a single error."""

    code: str = Field(description="Application error code, e.g. RESOURCE_NOT_FOUND.")
    message: str = Field(description="Human-readable explanation of the error.")
    details: Optional[dict[str, Any]] = Field(
        default=None,
        description="Optional structured context (field errors, IDs, etc.).",
    )


class ErrorResponse(BaseModel):
    """Standard envelope for all error responses."""

    success: bool = False
    error: ErrorDetail
    request_id: Optional[str] = None
    timestamp: datetime = Field(default_factory=datetime.utcnow)
