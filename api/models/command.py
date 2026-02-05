"""SSM command execution models.

These models support the asynchronous command execution workflow:
1. Client submits a CommandRequest.
2. API returns a CommandResult with status=PENDING and a command_id.
3. Client polls by command_id until status is SUCCESS or FAILED.
"""

from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Dict, List, Optional

from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# Enumerations
# ---------------------------------------------------------------------------

class CommandStatus(str, Enum):
    """Lifecycle of an SSM Run Command invocation."""

    PENDING = "pending"
    IN_PROGRESS = "in_progress"
    SUCCESS = "success"
    FAILED = "failed"
    TIMED_OUT = "timed_out"
    CANCELLED = "cancelled"


# ---------------------------------------------------------------------------
# Request
# ---------------------------------------------------------------------------

class CommandRequest(BaseModel):
    """Payload to execute a command on one or more fleet instances."""

    instance_ids: List[str] = Field(
        min_length=1,
        max_length=50,
        description="Target EC2 instance IDs (1-50).",
    )
    document_name: str = Field(
        default="AWS-RunPowerShellScript",
        description="SSM document to execute.",
    )
    parameters: Dict[str, List[str]] = Field(
        default_factory=dict,
        description=(
            "SSM document parameters.  For AWS-RunPowerShellScript use "
            '{"commands": ["Get-Service"]}.'
        ),
    )
    comment: str = Field(
        default="",
        max_length=256,
        description="Optional human-readable comment attached to the invocation.",
    )
    timeout_seconds: int = Field(
        default=300,
        ge=30,
        le=3600,
        description="Per-instance execution timeout (30-3600 s).",
    )

    class Config:
        json_schema_extra = {
            "example": {
                "instance_ids": ["i-0abcdef1234567890"],
                "document_name": "AWS-RunPowerShellScript",
                "parameters": {"commands": ["Get-Service | Where-Object {$_.Status -eq 'Running'}"]},
                "comment": "List running services",
                "timeout_seconds": 120,
            }
        }


# ---------------------------------------------------------------------------
# Result
# ---------------------------------------------------------------------------

class InstanceCommandOutput(BaseModel):
    """Per-instance result of a command invocation."""

    instance_id: str
    status: CommandStatus
    exit_code: Optional[int] = None
    stdout: str = ""
    stderr: str = ""


class CommandResult(BaseModel):
    """Aggregate result of a command invocation across target instances."""

    command_id: str = Field(
        description="SSM command ID for polling / cancellation."
    )
    status: CommandStatus = Field(
        description="Aggregate status across all target instances."
    )
    document_name: str
    requested_at: datetime = Field(default_factory=datetime.utcnow)
    completed_at: Optional[datetime] = None
    instance_results: List[InstanceCommandOutput] = Field(default_factory=list)
    comment: str = ""
    request_id: Optional[str] = None
