"""Configuration module for Hyperion Fleet Manager metric aggregator.

This module provides environment-based configuration for the Lambda function,
including metric namespaces, dimension definitions, and threshold values.
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from enum import Enum
from typing import ClassVar


class Environment(Enum):
    """Supported deployment environments."""

    DEV = "dev"
    STAGING = "staging"
    PRODUCTION = "production"


@dataclass(frozen=True)
class MetricNamespace:
    """CloudWatch metric namespace definitions."""

    # Custom namespace for Hyperion Fleet Manager metrics
    HYPERION_FLEET: ClassVar[str] = "Hyperion/FleetManager"
    # AWS built-in namespaces for querying
    EC2: ClassVar[str] = "AWS/EC2"
    CW_AGENT: ClassVar[str] = "CWAgent"


@dataclass(frozen=True)
class MetricNames:
    """Standardized metric names for the fleet."""

    # Utilization metrics
    CPU_UTILIZATION: ClassVar[str] = "CPUUtilization"
    MEMORY_UTILIZATION: ClassVar[str] = "MemoryUtilization"
    DISK_UTILIZATION: ClassVar[str] = "DiskUtilization"

    # Fleet metrics
    INSTANCE_COUNT: ClassVar[str] = "InstanceCount"
    RUNNING_INSTANCES: ClassVar[str] = "RunningInstances"
    STOPPED_INSTANCES: ClassVar[str] = "StoppedInstances"
    PENDING_INSTANCES: ClassVar[str] = "PendingInstances"

    # Aggregated metrics
    FLEET_HEALTH_SCORE: ClassVar[str] = "FleetHealthScore"
    COMPLIANCE_SCORE: ClassVar[str] = "ComplianceScore"
    COST_EFFICIENCY_SCORE: ClassVar[str] = "CostEfficiencyScore"
    CAPACITY_UTILIZATION: ClassVar[str] = "CapacityUtilization"

    # Cost metrics
    COST_PER_INSTANCE: ClassVar[str] = "CostPerInstance"
    TOTAL_FLEET_COST: ClassVar[str] = "TotalFleetCost"


@dataclass(frozen=True)
class DimensionNames:
    """CloudWatch dimension names."""

    ENVIRONMENT: ClassVar[str] = "Environment"
    FLEET_NAME: ClassVar[str] = "FleetName"
    INSTANCE_TYPE: ClassVar[str] = "InstanceType"
    AVAILABILITY_ZONE: ClassVar[str] = "AvailabilityZone"
    INSTANCE_STATE: ClassVar[str] = "InstanceState"
    COMPLIANCE_STATUS: ClassVar[str] = "ComplianceStatus"


@dataclass(frozen=True)
class Thresholds:
    """Threshold values for health and compliance calculations.

    These thresholds are used to determine the health status of the fleet
    and calculate various scores.
    """

    # CPU utilization thresholds (percentage)
    CPU_WARNING: ClassVar[float] = 70.0
    CPU_CRITICAL: ClassVar[float] = 90.0

    # Memory utilization thresholds (percentage)
    MEMORY_WARNING: ClassVar[float] = 75.0
    MEMORY_CRITICAL: ClassVar[float] = 90.0

    # Disk utilization thresholds (percentage)
    DISK_WARNING: ClassVar[float] = 80.0
    DISK_CRITICAL: ClassVar[float] = 95.0

    # Compliance thresholds (percentage)
    COMPLIANCE_WARNING: ClassVar[float] = 90.0
    COMPLIANCE_CRITICAL: ClassVar[float] = 80.0

    # Health score weights
    CPU_WEIGHT: ClassVar[float] = 0.30
    MEMORY_WEIGHT: ClassVar[float] = 0.25
    DISK_WEIGHT: ClassVar[float] = 0.20
    COMPLIANCE_WEIGHT: ClassVar[float] = 0.25

    # Cost efficiency thresholds
    IDLE_CPU_THRESHOLD: ClassVar[float] = 5.0  # Below this is considered idle
    UNDERUTILIZED_CPU_THRESHOLD: ClassVar[float] = 20.0


@dataclass
class Config:
    """Main configuration class for the metric aggregator.

    Attributes:
        environment: Deployment environment (dev, staging, production).
        region: AWS region for API calls.
        fleet_name: Name of the fleet being monitored.
        metric_namespace: CloudWatch namespace for custom metrics.
        aggregation_period_minutes: Period for metric aggregation.
        max_instances_per_query: Maximum instances to query at once.
        enable_detailed_metrics: Enable detailed per-instance metrics.
        log_level: Logging level for the function.
        ssm_inventory_type_name: SSM Inventory type to query.
        cost_per_hour: Dictionary of instance type to hourly cost.
    """

    environment: str = field(
        default_factory=lambda: os.environ.get("ENVIRONMENT", "dev")
    )
    region: str = field(
        default_factory=lambda: os.environ.get("AWS_REGION", "us-east-1")
    )
    fleet_name: str = field(
        default_factory=lambda: os.environ.get("FLEET_NAME", "hyperion-fleet")
    )
    metric_namespace: str = field(
        default_factory=lambda: os.environ.get(
            "METRIC_NAMESPACE", MetricNamespace.HYPERION_FLEET
        )
    )
    aggregation_period_minutes: int = field(
        default_factory=lambda: int(os.environ.get("AGGREGATION_PERIOD_MINUTES", "5"))
    )
    max_instances_per_query: int = field(
        default_factory=lambda: int(os.environ.get("MAX_INSTANCES_PER_QUERY", "100"))
    )
    enable_detailed_metrics: bool = field(
        default_factory=lambda: os.environ.get(
            "ENABLE_DETAILED_METRICS", "false"
        ).lower()
        == "true"
    )
    log_level: str = field(
        default_factory=lambda: os.environ.get("LOG_LEVEL", "INFO")
    )
    ssm_inventory_type_name: str = field(
        default_factory=lambda: os.environ.get(
            "SSM_INVENTORY_TYPE", "AWS:InstanceInformation"
        )
    )
    # Instance type to hourly cost mapping (USD)
    # These are approximate on-demand prices for us-east-1
    cost_per_hour: dict[str, float] = field(default_factory=lambda: {
        "t3.micro": 0.0104,
        "t3.small": 0.0208,
        "t3.medium": 0.0416,
        "t3.large": 0.0832,
        "t3.xlarge": 0.1664,
        "t3.2xlarge": 0.3328,
        "m5.large": 0.096,
        "m5.xlarge": 0.192,
        "m5.2xlarge": 0.384,
        "m5.4xlarge": 0.768,
        "r5.large": 0.126,
        "r5.xlarge": 0.252,
        "r5.2xlarge": 0.504,
        "c5.large": 0.085,
        "c5.xlarge": 0.17,
        "c5.2xlarge": 0.34,
        # Default for unknown instance types
        "default": 0.10,
    })

    def get_instance_cost(self, instance_type: str) -> float:
        """Get hourly cost for an instance type.

        Args:
            instance_type: The EC2 instance type.

        Returns:
            Hourly cost in USD.
        """
        return self.cost_per_hour.get(
            instance_type, self.cost_per_hour.get("default", 0.10)
        )

    @property
    def is_production(self) -> bool:
        """Check if running in production environment."""
        return self.environment.lower() == Environment.PRODUCTION.value

    @property
    def default_dimensions(self) -> list[dict[str, str]]:
        """Get default dimensions for metrics.

        Returns:
            List of dimension dictionaries.
        """
        return [
            {"Name": DimensionNames.ENVIRONMENT, "Value": self.environment},
            {"Name": DimensionNames.FLEET_NAME, "Value": self.fleet_name},
        ]


def get_config() -> Config:
    """Factory function to create configuration instance.

    Returns:
        Configured Config instance based on environment variables.
    """
    return Config()
