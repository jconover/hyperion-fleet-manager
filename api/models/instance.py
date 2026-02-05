"""Fleet instance models.

Represents an EC2 Windows Server instance managed by Hyperion.
These models map closely to the data returned by the EC2 and SSM APIs
while presenting a fleet-management-centric view to callers.
"""

from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Dict, List, Optional

from pydantic import BaseModel, Field

from api.models.common import PaginationMeta


# ---------------------------------------------------------------------------
# Enumerations
# ---------------------------------------------------------------------------

class InstanceState(str, Enum):
    """EC2 instance lifecycle state."""

    PENDING = "pending"
    RUNNING = "running"
    STOPPING = "stopping"
    STOPPED = "stopped"
    SHUTTING_DOWN = "shutting-down"
    TERMINATED = "terminated"


class InstanceHealth(str, Enum):
    """Composite health status derived from EC2 and SSM health checks."""

    HEALTHY = "healthy"
    DEGRADED = "degraded"
    UNHEALTHY = "unhealthy"
    UNKNOWN = "unknown"


# ---------------------------------------------------------------------------
# Instance model
# ---------------------------------------------------------------------------

class FleetInstance(BaseModel):
    """Core representation of a managed Windows fleet instance."""

    instance_id: str = Field(
        description="EC2 instance ID (e.g. i-0abcdef1234567890)."
    )
    name: str = Field(
        default="",
        description="Value of the Name tag on the instance.",
    )
    state: InstanceState = Field(
        description="Current EC2 lifecycle state."
    )
    health: InstanceHealth = Field(
        default=InstanceHealth.UNKNOWN,
        description="Composite health derived from EC2 status checks and SSM ping.",
    )
    instance_type: str = Field(
        default="",
        description="EC2 instance type (e.g. t3.medium).",
    )
    private_ip: Optional[str] = Field(
        default=None,
        description="Primary private IPv4 address.",
    )
    availability_zone: str = Field(
        default="",
        description="AZ where the instance is running.",
    )
    ami_id: str = Field(
        default="",
        description="AMI from which the instance was launched.",
    )
    launch_time: Optional[datetime] = Field(
        default=None,
        description="UTC timestamp when the instance was started.",
    )
    ssm_ping_status: Optional[str] = Field(
        default=None,
        description="Latest SSM agent ping status (Online / ConnectionLost).",
    )
    platform: str = Field(
        default="Windows",
        description="Operating system platform.",
    )
    tags: Dict[str, str] = Field(
        default_factory=dict,
        description="All EC2 tags as a flat key-value map.",
    )
    compliance_status: Optional[str] = Field(
        default=None,
        description="Latest compliance check result (COMPLIANT / NON_COMPLIANT).",
    )
    last_patch_time: Optional[datetime] = Field(
        default=None,
        description="UTC timestamp of the most recent successful patch operation.",
    )

    class Config:
        json_schema_extra = {
            "example": {
                "instance_id": "i-0abcdef1234567890",
                "name": "hyperion-web-001",
                "state": "running",
                "health": "healthy",
                "instance_type": "t3.medium",
                "private_ip": "10.0.1.42",
                "availability_zone": "us-east-1a",
                "ami_id": "ami-0123456789abcdef0",
                "launch_time": "2026-01-15T08:30:00Z",
                "ssm_ping_status": "Online",
                "platform": "Windows",
                "tags": {
                    "Environment": "production",
                    "ManagedBy": "terraform",
                    "Project": "hyperion-fleet-manager",
                },
                "compliance_status": "COMPLIANT",
                "last_patch_time": "2026-01-20T02:00:00Z",
            }
        }


# ---------------------------------------------------------------------------
# List / pagination wrapper
# ---------------------------------------------------------------------------

class InstanceListResponse(BaseModel):
    """Paginated list of fleet instances."""

    success: bool = True
    data: List[FleetInstance]
    meta: PaginationMeta
    request_id: Optional[str] = None
    timestamp: datetime = Field(default_factory=datetime.utcnow)
