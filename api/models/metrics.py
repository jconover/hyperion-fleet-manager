"""CloudWatch metrics query and response models.

These models support time-series metric retrieval for fleet instances,
covering CPU utilisation, memory, disk, and network metrics.
"""

from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Dict, List, Optional

from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# Enumerations
# ---------------------------------------------------------------------------

class MetricName(str, Enum):
    """Well-known fleet metrics available through the API."""

    CPU_UTILIZATION = "CPUUtilization"
    MEMORY_UTILIZATION = "MemoryUtilization"
    DISK_UTILIZATION = "DiskUtilization"
    NETWORK_IN = "NetworkIn"
    NETWORK_OUT = "NetworkOut"
    STATUS_CHECK_FAILED = "StatusCheckFailed"
    SSM_PING_STATUS = "SSMPingStatus"


class MetricStatistic(str, Enum):
    """CloudWatch statistics that can be requested."""

    AVERAGE = "Average"
    SUM = "Sum"
    MINIMUM = "Minimum"
    MAXIMUM = "Maximum"
    SAMPLE_COUNT = "SampleCount"


# ---------------------------------------------------------------------------
# Query
# ---------------------------------------------------------------------------

class MetricQuery(BaseModel):
    """Parameters for a CloudWatch metric data query."""

    instance_ids: List[str] = Field(
        default_factory=list,
        max_length=20,
        description="Filter to specific instances. Empty means fleet-wide.",
    )
    metric_name: MetricName = Field(
        description="Metric to retrieve.",
    )
    statistic: MetricStatistic = Field(
        default=MetricStatistic.AVERAGE,
        description="Statistic to calculate over each period.",
    )
    start_time: datetime = Field(
        description="Start of the query window (UTC).",
    )
    end_time: datetime = Field(
        description="End of the query window (UTC).",
    )
    period_seconds: int = Field(
        default=300,
        ge=60,
        le=86400,
        description="Aggregation period in seconds (min 60).",
    )
    namespace: Optional[str] = Field(
        default=None,
        description="CloudWatch namespace override.  Uses default if omitted.",
    )

    class Config:
        json_schema_extra = {
            "example": {
                "instance_ids": ["i-0abcdef1234567890"],
                "metric_name": "CPUUtilization",
                "statistic": "Average",
                "start_time": "2026-02-01T00:00:00Z",
                "end_time": "2026-02-01T12:00:00Z",
                "period_seconds": 300,
            }
        }


# ---------------------------------------------------------------------------
# Response
# ---------------------------------------------------------------------------

class MetricDataPoint(BaseModel):
    """Single data point in a time-series."""

    timestamp: datetime
    value: float
    unit: str = ""


class MetricSeries(BaseModel):
    """Metric data for a single instance or the fleet aggregate."""

    instance_id: Optional[str] = Field(
        default=None,
        description="Instance this series belongs to, or null for fleet-wide.",
    )
    metric_name: str
    statistic: str
    data_points: List[MetricDataPoint] = Field(default_factory=list)
    label: str = ""


class MetricResponse(BaseModel):
    """Wrapper returned by the metrics query endpoint."""

    success: bool = True
    data: List[MetricSeries]
    query: Dict[str, object] = Field(
        default_factory=dict,
        description="Echo of the original query for client convenience.",
    )
    request_id: Optional[str] = None
    timestamp: datetime = Field(default_factory=datetime.utcnow)
