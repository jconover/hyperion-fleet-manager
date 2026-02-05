"""Metric definitions and calculations for Hyperion Fleet Manager.

This module provides metric classes and calculation logic for fleet health,
compliance, cost efficiency, and capacity utilization scores.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Any

from config import DimensionNames, MetricNames, Thresholds


class HealthStatus(Enum):
    """Health status levels for the fleet."""

    HEALTHY = "healthy"
    WARNING = "warning"
    CRITICAL = "critical"
    UNKNOWN = "unknown"


class ComplianceStatus(Enum):
    """Compliance status for instances."""

    COMPLIANT = "COMPLIANT"
    NON_COMPLIANT = "NON_COMPLIANT"
    UNKNOWN = "UNKNOWN"


@dataclass
class MetricValue:
    """Represents a single metric value with metadata.

    Attributes:
        name: Metric name.
        value: Metric value.
        unit: CloudWatch unit for the metric.
        dimensions: List of dimension dictionaries.
        timestamp: Metric timestamp.
    """

    name: str
    value: float
    unit: str = "None"
    dimensions: list[dict[str, str]] = field(default_factory=list)
    timestamp: datetime = field(default_factory=lambda: datetime.now(timezone.utc))

    def to_cloudwatch_format(self) -> dict[str, Any]:
        """Convert to CloudWatch PutMetricData format.

        Returns:
            Dictionary formatted for CloudWatch API.
        """
        return {
            "MetricName": self.name,
            "Value": self.value,
            "Unit": self.unit,
            "Dimensions": self.dimensions,
            "Timestamp": self.timestamp,
        }


@dataclass
class InstanceMetrics:
    """Metrics for a single instance.

    Attributes:
        instance_id: EC2 instance ID.
        instance_type: EC2 instance type.
        availability_zone: Instance availability zone.
        state: Instance state (running, stopped, etc.).
        cpu_utilization: Average CPU utilization percentage.
        memory_utilization: Average memory utilization percentage.
        disk_utilization: Average disk utilization percentage.
        is_compliant: Whether instance is compliant.
        hourly_cost: Estimated hourly cost.
    """

    instance_id: str
    instance_type: str = "unknown"
    availability_zone: str = "unknown"
    state: str = "unknown"
    cpu_utilization: float | None = None
    memory_utilization: float | None = None
    disk_utilization: float | None = None
    is_compliant: bool | None = None
    hourly_cost: float = 0.0


@dataclass
class FleetMetrics:
    """Aggregated metrics for the entire fleet.

    Attributes:
        total_instances: Total number of instances.
        running_instances: Number of running instances.
        stopped_instances: Number of stopped instances.
        pending_instances: Number of pending instances.
        avg_cpu_utilization: Average CPU utilization across fleet.
        avg_memory_utilization: Average memory utilization across fleet.
        avg_disk_utilization: Average disk utilization across fleet.
        compliant_instances: Number of compliant instances.
        non_compliant_instances: Number of non-compliant instances.
        total_hourly_cost: Total hourly cost of running instances.
        instance_metrics: List of individual instance metrics.
    """

    total_instances: int = 0
    running_instances: int = 0
    stopped_instances: int = 0
    pending_instances: int = 0
    avg_cpu_utilization: float = 0.0
    avg_memory_utilization: float = 0.0
    avg_disk_utilization: float = 0.0
    compliant_instances: int = 0
    non_compliant_instances: int = 0
    total_hourly_cost: float = 0.0
    instance_metrics: list[InstanceMetrics] = field(default_factory=list)


class BaseScore(ABC):
    """Abstract base class for score calculations."""

    @abstractmethod
    def calculate(self, fleet_metrics: FleetMetrics) -> float:
        """Calculate the score based on fleet metrics.

        Args:
            fleet_metrics: Aggregated fleet metrics.

        Returns:
            Calculated score as a percentage (0-100).
        """
        pass

    @abstractmethod
    def get_status(self, score: float) -> HealthStatus:
        """Get health status based on score.

        Args:
            score: Calculated score.

        Returns:
            Health status enum value.
        """
        pass


class FleetHealthScore(BaseScore):
    """Calculate overall fleet health score.

    The health score is a weighted combination of:
    - CPU utilization health (inverse - lower is better)
    - Memory utilization health (inverse - lower is better)
    - Disk utilization health (inverse - lower is better)
    - Compliance percentage
    """

    def calculate(self, fleet_metrics: FleetMetrics) -> float:
        """Calculate fleet health score.

        Args:
            fleet_metrics: Aggregated fleet metrics.

        Returns:
            Health score as a percentage (0-100).
        """
        if fleet_metrics.total_instances == 0:
            return 0.0

        # Calculate CPU health (inverse - 0% CPU = 100 health, 100% CPU = 0 health)
        cpu_health = self._calculate_utilization_health(
            fleet_metrics.avg_cpu_utilization,
            Thresholds.CPU_WARNING,
            Thresholds.CPU_CRITICAL,
        )

        # Calculate memory health
        memory_health = self._calculate_utilization_health(
            fleet_metrics.avg_memory_utilization,
            Thresholds.MEMORY_WARNING,
            Thresholds.MEMORY_CRITICAL,
        )

        # Calculate disk health
        disk_health = self._calculate_utilization_health(
            fleet_metrics.avg_disk_utilization,
            Thresholds.DISK_WARNING,
            Thresholds.DISK_CRITICAL,
        )

        # Calculate compliance health
        compliance_health = self._calculate_compliance_health(fleet_metrics)

        # Weighted average
        health_score = (
            cpu_health * Thresholds.CPU_WEIGHT
            + memory_health * Thresholds.MEMORY_WEIGHT
            + disk_health * Thresholds.DISK_WEIGHT
            + compliance_health * Thresholds.COMPLIANCE_WEIGHT
        )

        return round(min(100.0, max(0.0, health_score)), 2)

    def _calculate_utilization_health(
        self, utilization: float, warning_threshold: float, critical_threshold: float
    ) -> float:
        """Calculate health score from utilization metric.

        Args:
            utilization: Current utilization percentage.
            warning_threshold: Warning threshold.
            critical_threshold: Critical threshold.

        Returns:
            Health score (0-100).
        """
        if utilization <= warning_threshold:
            # Linear scale from 100 to 70 for 0 to warning threshold
            return 100 - (utilization / warning_threshold) * 30
        elif utilization <= critical_threshold:
            # Linear scale from 70 to 30 for warning to critical
            ratio = (utilization - warning_threshold) / (
                critical_threshold - warning_threshold
            )
            return 70 - ratio * 40
        else:
            # Linear scale from 30 to 0 for above critical
            ratio = min(1.0, (utilization - critical_threshold) / 10)
            return 30 - ratio * 30

    def _calculate_compliance_health(self, fleet_metrics: FleetMetrics) -> float:
        """Calculate compliance health score.

        Args:
            fleet_metrics: Fleet metrics with compliance data.

        Returns:
            Compliance health score (0-100).
        """
        total_checked = (
            fleet_metrics.compliant_instances + fleet_metrics.non_compliant_instances
        )
        if total_checked == 0:
            return 100.0  # No compliance data, assume healthy

        compliance_percentage = (
            fleet_metrics.compliant_instances / total_checked
        ) * 100
        return compliance_percentage

    def get_status(self, score: float) -> HealthStatus:
        """Get health status based on score.

        Args:
            score: Health score (0-100).

        Returns:
            Health status.
        """
        if score >= 80:
            return HealthStatus.HEALTHY
        elif score >= 60:
            return HealthStatus.WARNING
        elif score > 0:
            return HealthStatus.CRITICAL
        return HealthStatus.UNKNOWN


class ComplianceScore(BaseScore):
    """Calculate fleet-wide compliance score."""

    def calculate(self, fleet_metrics: FleetMetrics) -> float:
        """Calculate compliance score.

        Args:
            fleet_metrics: Aggregated fleet metrics.

        Returns:
            Compliance percentage (0-100).
        """
        total_checked = (
            fleet_metrics.compliant_instances + fleet_metrics.non_compliant_instances
        )
        if total_checked == 0:
            return 100.0  # No compliance data

        return round(
            (fleet_metrics.compliant_instances / total_checked) * 100, 2
        )

    def get_status(self, score: float) -> HealthStatus:
        """Get status based on compliance score.

        Args:
            score: Compliance score (0-100).

        Returns:
            Health status.
        """
        if score >= Thresholds.COMPLIANCE_WARNING:
            return HealthStatus.HEALTHY
        elif score >= Thresholds.COMPLIANCE_CRITICAL:
            return HealthStatus.WARNING
        elif score > 0:
            return HealthStatus.CRITICAL
        return HealthStatus.UNKNOWN


class CostEfficiencyScore(BaseScore):
    """Calculate cost efficiency score based on utilization.

    A higher score indicates better cost efficiency (instances are well-utilized).
    A lower score indicates potential over-provisioning or underutilization.
    """

    def calculate(self, fleet_metrics: FleetMetrics) -> float:
        """Calculate cost efficiency score.

        The score is based on the ratio of utilized capacity to total capacity.
        Idle instances (low CPU) reduce the score.

        Args:
            fleet_metrics: Aggregated fleet metrics.

        Returns:
            Cost efficiency score (0-100).
        """
        if fleet_metrics.running_instances == 0:
            return 0.0

        # Count underutilized and idle instances
        idle_count = 0
        underutilized_count = 0
        well_utilized_count = 0

        for instance in fleet_metrics.instance_metrics:
            if instance.state != "running" or instance.cpu_utilization is None:
                continue

            if instance.cpu_utilization < Thresholds.IDLE_CPU_THRESHOLD:
                idle_count += 1
            elif instance.cpu_utilization < Thresholds.UNDERUTILIZED_CPU_THRESHOLD:
                underutilized_count += 1
            else:
                well_utilized_count += 1

        total_running = idle_count + underutilized_count + well_utilized_count
        if total_running == 0:
            return 50.0  # No data, assume neutral

        # Calculate efficiency score
        # Well-utilized instances contribute fully, underutilized partially, idle minimally
        efficiency_score = (
            well_utilized_count * 100
            + underutilized_count * 50
            + idle_count * 10
        ) / total_running

        return round(min(100.0, max(0.0, efficiency_score)), 2)

    def get_status(self, score: float) -> HealthStatus:
        """Get status based on cost efficiency score.

        Args:
            score: Cost efficiency score (0-100).

        Returns:
            Health status.
        """
        if score >= 70:
            return HealthStatus.HEALTHY
        elif score >= 40:
            return HealthStatus.WARNING
        elif score > 0:
            return HealthStatus.CRITICAL
        return HealthStatus.UNKNOWN


class CapacityUtilization(BaseScore):
    """Calculate capacity utilization score.

    Measures how well the fleet capacity is being used.
    Considers CPU, memory, and disk utilization together.
    """

    def calculate(self, fleet_metrics: FleetMetrics) -> float:
        """Calculate capacity utilization score.

        Args:
            fleet_metrics: Aggregated fleet metrics.

        Returns:
            Capacity utilization percentage (0-100).
        """
        if fleet_metrics.running_instances == 0:
            return 0.0

        # Average of all utilization metrics
        metrics_count = 0
        total_utilization = 0.0

        if fleet_metrics.avg_cpu_utilization > 0:
            total_utilization += fleet_metrics.avg_cpu_utilization
            metrics_count += 1

        if fleet_metrics.avg_memory_utilization > 0:
            total_utilization += fleet_metrics.avg_memory_utilization
            metrics_count += 1

        if fleet_metrics.avg_disk_utilization > 0:
            total_utilization += fleet_metrics.avg_disk_utilization
            metrics_count += 1

        if metrics_count == 0:
            return 0.0

        return round(total_utilization / metrics_count, 2)

    def get_status(self, score: float) -> HealthStatus:
        """Get status based on capacity utilization.

        Args:
            score: Capacity utilization percentage (0-100).

        Returns:
            Health status.
        """
        if 20 <= score <= 70:
            return HealthStatus.HEALTHY
        elif 10 <= score < 20 or 70 < score <= 85:
            return HealthStatus.WARNING
        elif score > 85 or score < 10:
            return HealthStatus.CRITICAL
        return HealthStatus.UNKNOWN


class MetricAggregator:
    """Aggregates metrics and produces CloudWatch-ready metric values."""

    def __init__(self, environment: str, fleet_name: str) -> None:
        """Initialize the aggregator.

        Args:
            environment: Deployment environment.
            fleet_name: Name of the fleet.
        """
        self.environment = environment
        self.fleet_name = fleet_name
        self.default_dimensions = [
            {"Name": DimensionNames.ENVIRONMENT, "Value": environment},
            {"Name": DimensionNames.FLEET_NAME, "Value": fleet_name},
        ]
        self.health_score_calculator = FleetHealthScore()
        self.compliance_score_calculator = ComplianceScore()
        self.cost_efficiency_calculator = CostEfficiencyScore()
        self.capacity_utilization_calculator = CapacityUtilization()

    def aggregate(self, fleet_metrics: FleetMetrics) -> list[MetricValue]:
        """Aggregate fleet metrics into CloudWatch metric values.

        Args:
            fleet_metrics: Raw fleet metrics.

        Returns:
            List of MetricValue objects ready for CloudWatch.
        """
        metrics: list[MetricValue] = []
        timestamp = datetime.now(timezone.utc)

        # Instance count metrics
        metrics.extend(self._create_instance_count_metrics(fleet_metrics, timestamp))

        # Utilization metrics
        metrics.extend(self._create_utilization_metrics(fleet_metrics, timestamp))

        # Score metrics
        metrics.extend(self._create_score_metrics(fleet_metrics, timestamp))

        # Cost metrics
        metrics.extend(self._create_cost_metrics(fleet_metrics, timestamp))

        return metrics

    def _create_instance_count_metrics(
        self, fleet_metrics: FleetMetrics, timestamp: datetime
    ) -> list[MetricValue]:
        """Create instance count metrics.

        Args:
            fleet_metrics: Fleet metrics.
            timestamp: Metric timestamp.

        Returns:
            List of instance count metrics.
        """
        return [
            MetricValue(
                name=MetricNames.INSTANCE_COUNT,
                value=float(fleet_metrics.total_instances),
                unit="Count",
                dimensions=self.default_dimensions,
                timestamp=timestamp,
            ),
            MetricValue(
                name=MetricNames.RUNNING_INSTANCES,
                value=float(fleet_metrics.running_instances),
                unit="Count",
                dimensions=self.default_dimensions,
                timestamp=timestamp,
            ),
            MetricValue(
                name=MetricNames.STOPPED_INSTANCES,
                value=float(fleet_metrics.stopped_instances),
                unit="Count",
                dimensions=self.default_dimensions,
                timestamp=timestamp,
            ),
            MetricValue(
                name=MetricNames.PENDING_INSTANCES,
                value=float(fleet_metrics.pending_instances),
                unit="Count",
                dimensions=self.default_dimensions,
                timestamp=timestamp,
            ),
        ]

    def _create_utilization_metrics(
        self, fleet_metrics: FleetMetrics, timestamp: datetime
    ) -> list[MetricValue]:
        """Create utilization metrics.

        Args:
            fleet_metrics: Fleet metrics.
            timestamp: Metric timestamp.

        Returns:
            List of utilization metrics.
        """
        return [
            MetricValue(
                name=MetricNames.CPU_UTILIZATION,
                value=fleet_metrics.avg_cpu_utilization,
                unit="Percent",
                dimensions=self.default_dimensions,
                timestamp=timestamp,
            ),
            MetricValue(
                name=MetricNames.MEMORY_UTILIZATION,
                value=fleet_metrics.avg_memory_utilization,
                unit="Percent",
                dimensions=self.default_dimensions,
                timestamp=timestamp,
            ),
            MetricValue(
                name=MetricNames.DISK_UTILIZATION,
                value=fleet_metrics.avg_disk_utilization,
                unit="Percent",
                dimensions=self.default_dimensions,
                timestamp=timestamp,
            ),
        ]

    def _create_score_metrics(
        self, fleet_metrics: FleetMetrics, timestamp: datetime
    ) -> list[MetricValue]:
        """Create score metrics.

        Args:
            fleet_metrics: Fleet metrics.
            timestamp: Metric timestamp.

        Returns:
            List of score metrics.
        """
        health_score = self.health_score_calculator.calculate(fleet_metrics)
        compliance_score = self.compliance_score_calculator.calculate(fleet_metrics)
        cost_efficiency = self.cost_efficiency_calculator.calculate(fleet_metrics)
        capacity_util = self.capacity_utilization_calculator.calculate(fleet_metrics)

        return [
            MetricValue(
                name=MetricNames.FLEET_HEALTH_SCORE,
                value=health_score,
                unit="Percent",
                dimensions=self.default_dimensions,
                timestamp=timestamp,
            ),
            MetricValue(
                name=MetricNames.COMPLIANCE_SCORE,
                value=compliance_score,
                unit="Percent",
                dimensions=self.default_dimensions,
                timestamp=timestamp,
            ),
            MetricValue(
                name=MetricNames.COST_EFFICIENCY_SCORE,
                value=cost_efficiency,
                unit="Percent",
                dimensions=self.default_dimensions,
                timestamp=timestamp,
            ),
            MetricValue(
                name=MetricNames.CAPACITY_UTILIZATION,
                value=capacity_util,
                unit="Percent",
                dimensions=self.default_dimensions,
                timestamp=timestamp,
            ),
        ]

    def _create_cost_metrics(
        self, fleet_metrics: FleetMetrics, timestamp: datetime
    ) -> list[MetricValue]:
        """Create cost metrics.

        Args:
            fleet_metrics: Fleet metrics.
            timestamp: Metric timestamp.

        Returns:
            List of cost metrics.
        """
        cost_per_instance = (
            fleet_metrics.total_hourly_cost / fleet_metrics.running_instances
            if fleet_metrics.running_instances > 0
            else 0.0
        )

        return [
            MetricValue(
                name=MetricNames.COST_PER_INSTANCE,
                value=round(cost_per_instance, 4),
                unit="None",  # USD per hour, no standard unit
                dimensions=self.default_dimensions,
                timestamp=timestamp,
            ),
            MetricValue(
                name=MetricNames.TOTAL_FLEET_COST,
                value=round(fleet_metrics.total_hourly_cost, 4),
                unit="None",  # USD per hour
                dimensions=self.default_dimensions,
                timestamp=timestamp,
            ),
        ]
