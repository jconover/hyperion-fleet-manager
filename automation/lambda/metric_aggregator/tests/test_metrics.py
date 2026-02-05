"""Unit tests for Hyperion Fleet Manager metric calculations.

This module contains comprehensive tests for all metric score calculations,
including FleetHealthScore, ComplianceScore, CostEfficiencyScore, and
CapacityUtilization.
"""

from __future__ import annotations

import os
from datetime import datetime, timezone
from typing import TYPE_CHECKING

import pytest

# Set environment variables before importing modules
os.environ["AWS_DEFAULT_REGION"] = "us-east-1"
os.environ["ENVIRONMENT"] = "test"
os.environ["FLEET_NAME"] = "test-fleet"

from config import DimensionNames, MetricNames, Thresholds
from metrics import (
    BaseScore,
    CapacityUtilization,
    ComplianceScore,
    ComplianceStatus,
    CostEfficiencyScore,
    FleetHealthScore,
    FleetMetrics,
    HealthStatus,
    InstanceMetrics,
    MetricAggregator,
    MetricValue,
)


class TestMetricValue:
    """Tests for MetricValue dataclass."""

    def test_creation_with_defaults(self) -> None:
        """Test MetricValue creation with default values."""
        metric = MetricValue(name="TestMetric", value=42.5)

        assert metric.name == "TestMetric"
        assert metric.value == 42.5
        assert metric.unit == "None"
        assert metric.dimensions == []
        assert isinstance(metric.timestamp, datetime)

    def test_creation_with_all_parameters(self) -> None:
        """Test MetricValue creation with all parameters specified."""
        timestamp = datetime(2024, 1, 15, 12, 0, 0, tzinfo=timezone.utc)
        dimensions = [
            {"Name": "Environment", "Value": "test"},
            {"Name": "FleetName", "Value": "test-fleet"},
        ]

        metric = MetricValue(
            name="CPUUtilization",
            value=75.5,
            unit="Percent",
            dimensions=dimensions,
            timestamp=timestamp,
        )

        assert metric.name == "CPUUtilization"
        assert metric.value == 75.5
        assert metric.unit == "Percent"
        assert metric.dimensions == dimensions
        assert metric.timestamp == timestamp

    def test_to_cloudwatch_format(self) -> None:
        """Test conversion to CloudWatch PutMetricData format."""
        timestamp = datetime(2024, 1, 15, 12, 0, 0, tzinfo=timezone.utc)
        dimensions = [{"Name": "Test", "Value": "Value"}]

        metric = MetricValue(
            name="TestMetric",
            value=42.5,
            unit="Count",
            dimensions=dimensions,
            timestamp=timestamp,
        )

        cw_format = metric.to_cloudwatch_format()

        assert cw_format["MetricName"] == "TestMetric"
        assert cw_format["Value"] == 42.5
        assert cw_format["Unit"] == "Count"
        assert cw_format["Dimensions"] == dimensions
        assert cw_format["Timestamp"] == timestamp

    def test_to_cloudwatch_format_empty_dimensions(self) -> None:
        """Test CloudWatch format with empty dimensions."""
        metric = MetricValue(name="TestMetric", value=100.0)
        cw_format = metric.to_cloudwatch_format()

        assert cw_format["Dimensions"] == []

    def test_negative_value(self) -> None:
        """Test MetricValue with negative value (edge case)."""
        metric = MetricValue(name="Delta", value=-10.5)
        assert metric.value == -10.5

    def test_zero_value(self) -> None:
        """Test MetricValue with zero value."""
        metric = MetricValue(name="ZeroMetric", value=0.0)
        assert metric.value == 0.0


class TestInstanceMetrics:
    """Tests for InstanceMetrics dataclass."""

    def test_creation_with_defaults(self) -> None:
        """Test InstanceMetrics creation with defaults."""
        instance = InstanceMetrics(instance_id="i-1234567890abcdef0")

        assert instance.instance_id == "i-1234567890abcdef0"
        assert instance.instance_type == "unknown"
        assert instance.availability_zone == "unknown"
        assert instance.state == "unknown"
        assert instance.cpu_utilization is None
        assert instance.memory_utilization is None
        assert instance.disk_utilization is None
        assert instance.is_compliant is None
        assert instance.hourly_cost == 0.0

    def test_creation_with_all_parameters(self) -> None:
        """Test InstanceMetrics creation with all parameters."""
        instance = InstanceMetrics(
            instance_id="i-1234567890abcdef0",
            instance_type="t3.large",
            availability_zone="us-east-1a",
            state="running",
            cpu_utilization=45.5,
            memory_utilization=60.0,
            disk_utilization=50.0,
            is_compliant=True,
            hourly_cost=0.0832,
        )

        assert instance.instance_id == "i-1234567890abcdef0"
        assert instance.instance_type == "t3.large"
        assert instance.availability_zone == "us-east-1a"
        assert instance.state == "running"
        assert instance.cpu_utilization == 45.5
        assert instance.memory_utilization == 60.0
        assert instance.disk_utilization == 50.0
        assert instance.is_compliant is True
        assert instance.hourly_cost == 0.0832


class TestFleetMetrics:
    """Tests for FleetMetrics dataclass."""

    def test_creation_with_defaults(self) -> None:
        """Test FleetMetrics creation with defaults."""
        fleet = FleetMetrics()

        assert fleet.total_instances == 0
        assert fleet.running_instances == 0
        assert fleet.stopped_instances == 0
        assert fleet.pending_instances == 0
        assert fleet.avg_cpu_utilization == 0.0
        assert fleet.avg_memory_utilization == 0.0
        assert fleet.avg_disk_utilization == 0.0
        assert fleet.compliant_instances == 0
        assert fleet.non_compliant_instances == 0
        assert fleet.total_hourly_cost == 0.0
        assert fleet.instance_metrics == []

    def test_creation_with_instance_metrics(self) -> None:
        """Test FleetMetrics creation with instance metrics list."""
        instances = [
            InstanceMetrics(instance_id="i-1", state="running"),
            InstanceMetrics(instance_id="i-2", state="stopped"),
        ]

        fleet = FleetMetrics(
            total_instances=2,
            running_instances=1,
            stopped_instances=1,
            instance_metrics=instances,
        )

        assert fleet.total_instances == 2
        assert len(fleet.instance_metrics) == 2


class TestFleetHealthScore:
    """Tests for FleetHealthScore calculation."""

    @pytest.fixture
    def calculator(self) -> FleetHealthScore:
        """Create a FleetHealthScore calculator."""
        return FleetHealthScore()

    def test_empty_fleet_returns_zero(self, calculator: FleetHealthScore) -> None:
        """Test that empty fleet returns zero health score."""
        fleet = FleetMetrics(total_instances=0)
        score = calculator.calculate(fleet)
        assert score == 0.0

    def test_perfect_health_fleet(self, calculator: FleetHealthScore) -> None:
        """Test health score for a perfectly healthy fleet."""
        fleet = FleetMetrics(
            total_instances=10,
            running_instances=10,
            avg_cpu_utilization=20.0,  # Low CPU
            avg_memory_utilization=30.0,  # Low memory
            avg_disk_utilization=25.0,  # Low disk
            compliant_instances=10,
            non_compliant_instances=0,
        )

        score = calculator.calculate(fleet)
        assert score >= 90.0  # Should be very healthy

    def test_warning_level_utilization(self, calculator: FleetHealthScore) -> None:
        """Test health score at warning threshold."""
        fleet = FleetMetrics(
            total_instances=5,
            running_instances=5,
            avg_cpu_utilization=Thresholds.CPU_WARNING,  # At warning
            avg_memory_utilization=Thresholds.MEMORY_WARNING,
            avg_disk_utilization=Thresholds.DISK_WARNING,
            compliant_instances=5,
            non_compliant_instances=0,
        )

        score = calculator.calculate(fleet)
        # At warning thresholds, score should be around 70
        assert 60 <= score <= 80

    def test_critical_utilization(self, calculator: FleetHealthScore) -> None:
        """Test health score at critical levels."""
        fleet = FleetMetrics(
            total_instances=5,
            running_instances=5,
            avg_cpu_utilization=95.0,
            avg_memory_utilization=95.0,
            avg_disk_utilization=98.0,
            compliant_instances=0,
            non_compliant_instances=5,
        )

        score = calculator.calculate(fleet)
        assert score < 30  # Should be critical

    def test_compliance_impact_on_health(self, calculator: FleetHealthScore) -> None:
        """Test that compliance affects health score."""
        # Fully compliant fleet
        compliant_fleet = FleetMetrics(
            total_instances=10,
            running_instances=10,
            avg_cpu_utilization=50.0,
            avg_memory_utilization=50.0,
            avg_disk_utilization=50.0,
            compliant_instances=10,
            non_compliant_instances=0,
        )

        # Non-compliant fleet with same utilization
        non_compliant_fleet = FleetMetrics(
            total_instances=10,
            running_instances=10,
            avg_cpu_utilization=50.0,
            avg_memory_utilization=50.0,
            avg_disk_utilization=50.0,
            compliant_instances=0,
            non_compliant_instances=10,
        )

        compliant_score = calculator.calculate(compliant_fleet)
        non_compliant_score = calculator.calculate(non_compliant_fleet)

        assert compliant_score > non_compliant_score

    def test_utilization_health_calculation_below_warning(
        self, calculator: FleetHealthScore
    ) -> None:
        """Test utilization health calculation below warning threshold."""
        # _calculate_utilization_health is private but we test through calculate
        fleet = FleetMetrics(
            total_instances=1,
            running_instances=1,
            avg_cpu_utilization=35.0,  # Half of warning threshold (70)
            avg_memory_utilization=0.0,
            avg_disk_utilization=0.0,
            compliant_instances=1,
            non_compliant_instances=0,
        )

        score = calculator.calculate(fleet)
        # CPU at 35% should give good CPU health component
        assert score > 70

    def test_utilization_health_calculation_between_warning_and_critical(
        self, calculator: FleetHealthScore
    ) -> None:
        """Test utilization health between warning and critical thresholds."""
        fleet = FleetMetrics(
            total_instances=1,
            running_instances=1,
            avg_cpu_utilization=80.0,  # Between 70 (warning) and 90 (critical)
            avg_memory_utilization=80.0,
            avg_disk_utilization=85.0,
            compliant_instances=1,
            non_compliant_instances=0,
        )

        score = calculator.calculate(fleet)
        # Should be in warning range
        assert 40 <= score <= 70

    def test_utilization_health_calculation_above_critical(
        self, calculator: FleetHealthScore
    ) -> None:
        """Test utilization health above critical threshold."""
        fleet = FleetMetrics(
            total_instances=1,
            running_instances=1,
            avg_cpu_utilization=100.0,  # Above critical
            avg_memory_utilization=100.0,
            avg_disk_utilization=100.0,
            compliant_instances=1,
            non_compliant_instances=0,
        )

        score = calculator.calculate(fleet)
        assert score < 40  # Should be low

    def test_get_status_healthy(self, calculator: FleetHealthScore) -> None:
        """Test status determination for healthy score."""
        assert calculator.get_status(85.0) == HealthStatus.HEALTHY
        assert calculator.get_status(80.0) == HealthStatus.HEALTHY
        assert calculator.get_status(100.0) == HealthStatus.HEALTHY

    def test_get_status_warning(self, calculator: FleetHealthScore) -> None:
        """Test status determination for warning score."""
        assert calculator.get_status(79.9) == HealthStatus.WARNING
        assert calculator.get_status(65.0) == HealthStatus.WARNING
        assert calculator.get_status(60.0) == HealthStatus.WARNING

    def test_get_status_critical(self, calculator: FleetHealthScore) -> None:
        """Test status determination for critical score."""
        assert calculator.get_status(59.9) == HealthStatus.CRITICAL
        assert calculator.get_status(30.0) == HealthStatus.CRITICAL
        assert calculator.get_status(1.0) == HealthStatus.CRITICAL

    def test_get_status_unknown(self, calculator: FleetHealthScore) -> None:
        """Test status determination for unknown/zero score."""
        assert calculator.get_status(0.0) == HealthStatus.UNKNOWN

    def test_score_bounds(self, calculator: FleetHealthScore) -> None:
        """Test that score is always between 0 and 100."""
        # Test with extreme values
        extreme_fleet = FleetMetrics(
            total_instances=1,
            running_instances=1,
            avg_cpu_utilization=200.0,  # Impossible but should be handled
            avg_memory_utilization=200.0,
            avg_disk_utilization=200.0,
            compliant_instances=0,
            non_compliant_instances=100,
        )

        score = calculator.calculate(extreme_fleet)
        assert 0.0 <= score <= 100.0

    def test_compliance_health_no_data(self, calculator: FleetHealthScore) -> None:
        """Test compliance health when no compliance data exists."""
        fleet = FleetMetrics(
            total_instances=5,
            running_instances=5,
            avg_cpu_utilization=50.0,
            avg_memory_utilization=50.0,
            avg_disk_utilization=50.0,
            compliant_instances=0,  # No compliance data
            non_compliant_instances=0,
        )

        score = calculator.calculate(fleet)
        # With no compliance data, compliance health should be 100%
        assert score > 50


class TestComplianceScore:
    """Tests for ComplianceScore calculation."""

    @pytest.fixture
    def calculator(self) -> ComplianceScore:
        """Create a ComplianceScore calculator."""
        return ComplianceScore()

    def test_full_compliance(self, calculator: ComplianceScore) -> None:
        """Test score with 100% compliance."""
        fleet = FleetMetrics(
            compliant_instances=10,
            non_compliant_instances=0,
        )

        score = calculator.calculate(fleet)
        assert score == 100.0

    def test_no_compliance(self, calculator: ComplianceScore) -> None:
        """Test score with 0% compliance."""
        fleet = FleetMetrics(
            compliant_instances=0,
            non_compliant_instances=10,
        )

        score = calculator.calculate(fleet)
        assert score == 0.0

    def test_partial_compliance(self, calculator: ComplianceScore) -> None:
        """Test score with partial compliance."""
        fleet = FleetMetrics(
            compliant_instances=7,
            non_compliant_instances=3,
        )

        score = calculator.calculate(fleet)
        assert score == 70.0

    def test_two_thirds_compliance(self, calculator: ComplianceScore) -> None:
        """Test score with 2/3 compliance."""
        fleet = FleetMetrics(
            compliant_instances=2,
            non_compliant_instances=1,
        )

        score = calculator.calculate(fleet)
        assert 66.0 <= score <= 67.0  # 66.67%

    def test_no_compliance_data(self, calculator: ComplianceScore) -> None:
        """Test score when no compliance data exists."""
        fleet = FleetMetrics(
            compliant_instances=0,
            non_compliant_instances=0,
        )

        score = calculator.calculate(fleet)
        assert score == 100.0  # Assume healthy when no data

    def test_rounding(self, calculator: ComplianceScore) -> None:
        """Test that score is rounded to 2 decimal places."""
        fleet = FleetMetrics(
            compliant_instances=1,
            non_compliant_instances=2,
        )

        score = calculator.calculate(fleet)
        # 1/3 = 33.333... should round to 33.33
        assert score == 33.33

    def test_get_status_healthy(self, calculator: ComplianceScore) -> None:
        """Test status for healthy compliance (>= 90%)."""
        assert calculator.get_status(95.0) == HealthStatus.HEALTHY
        assert calculator.get_status(90.0) == HealthStatus.HEALTHY
        assert calculator.get_status(100.0) == HealthStatus.HEALTHY

    def test_get_status_warning(self, calculator: ComplianceScore) -> None:
        """Test status for warning compliance (80-90%)."""
        assert calculator.get_status(89.9) == HealthStatus.WARNING
        assert calculator.get_status(85.0) == HealthStatus.WARNING
        assert calculator.get_status(80.0) == HealthStatus.WARNING

    def test_get_status_critical(self, calculator: ComplianceScore) -> None:
        """Test status for critical compliance (< 80%)."""
        assert calculator.get_status(79.9) == HealthStatus.CRITICAL
        assert calculator.get_status(50.0) == HealthStatus.CRITICAL
        assert calculator.get_status(1.0) == HealthStatus.CRITICAL

    def test_get_status_unknown(self, calculator: ComplianceScore) -> None:
        """Test status for zero compliance."""
        assert calculator.get_status(0.0) == HealthStatus.UNKNOWN


class TestCostEfficiencyScore:
    """Tests for CostEfficiencyScore calculation."""

    @pytest.fixture
    def calculator(self) -> CostEfficiencyScore:
        """Create a CostEfficiencyScore calculator."""
        return CostEfficiencyScore()

    def test_well_utilized_fleet(self, calculator: CostEfficiencyScore) -> None:
        """Test score with all well-utilized instances."""
        fleet = FleetMetrics(
            running_instances=3,
            instance_metrics=[
                InstanceMetrics(
                    instance_id="i-1", state="running", cpu_utilization=50.0
                ),
                InstanceMetrics(
                    instance_id="i-2", state="running", cpu_utilization=60.0
                ),
                InstanceMetrics(
                    instance_id="i-3", state="running", cpu_utilization=40.0
                ),
            ],
        )

        score = calculator.calculate(fleet)
        assert score == 100.0

    def test_idle_fleet(self, calculator: CostEfficiencyScore) -> None:
        """Test score with all idle instances (< 5% CPU)."""
        fleet = FleetMetrics(
            running_instances=3,
            instance_metrics=[
                InstanceMetrics(
                    instance_id="i-1", state="running", cpu_utilization=2.0
                ),
                InstanceMetrics(
                    instance_id="i-2", state="running", cpu_utilization=3.0
                ),
                InstanceMetrics(
                    instance_id="i-3", state="running", cpu_utilization=1.0
                ),
            ],
        )

        score = calculator.calculate(fleet)
        assert score == 10.0

    def test_underutilized_fleet(self, calculator: CostEfficiencyScore) -> None:
        """Test score with underutilized instances (5-20% CPU)."""
        fleet = FleetMetrics(
            running_instances=3,
            instance_metrics=[
                InstanceMetrics(
                    instance_id="i-1", state="running", cpu_utilization=10.0
                ),
                InstanceMetrics(
                    instance_id="i-2", state="running", cpu_utilization=15.0
                ),
                InstanceMetrics(
                    instance_id="i-3", state="running", cpu_utilization=12.0
                ),
            ],
        )

        score = calculator.calculate(fleet)
        assert score == 50.0

    def test_mixed_utilization_fleet(self, calculator: CostEfficiencyScore) -> None:
        """Test score with mixed utilization levels."""
        fleet = FleetMetrics(
            running_instances=3,
            instance_metrics=[
                InstanceMetrics(
                    instance_id="i-1", state="running", cpu_utilization=50.0
                ),  # Well-utilized
                InstanceMetrics(
                    instance_id="i-2", state="running", cpu_utilization=10.0
                ),  # Underutilized
                InstanceMetrics(
                    instance_id="i-3", state="running", cpu_utilization=2.0
                ),  # Idle
            ],
        )

        score = calculator.calculate(fleet)
        # (100 + 50 + 10) / 3 = 53.33
        assert 53.0 <= score <= 54.0

    def test_no_running_instances(self, calculator: CostEfficiencyScore) -> None:
        """Test score with no running instances."""
        fleet = FleetMetrics(running_instances=0)
        score = calculator.calculate(fleet)
        assert score == 0.0

    def test_stopped_instances_ignored(self, calculator: CostEfficiencyScore) -> None:
        """Test that stopped instances are ignored in calculation."""
        fleet = FleetMetrics(
            running_instances=2,
            instance_metrics=[
                InstanceMetrics(
                    instance_id="i-1", state="running", cpu_utilization=50.0
                ),
                InstanceMetrics(
                    instance_id="i-2", state="stopped", cpu_utilization=None
                ),
                InstanceMetrics(
                    instance_id="i-3", state="running", cpu_utilization=50.0
                ),
            ],
        )

        score = calculator.calculate(fleet)
        assert score == 100.0  # Only running instances count

    def test_instances_with_no_cpu_data(self, calculator: CostEfficiencyScore) -> None:
        """Test that instances with no CPU data are ignored."""
        fleet = FleetMetrics(
            running_instances=3,
            instance_metrics=[
                InstanceMetrics(
                    instance_id="i-1", state="running", cpu_utilization=50.0
                ),
                InstanceMetrics(
                    instance_id="i-2", state="running", cpu_utilization=None
                ),
                InstanceMetrics(
                    instance_id="i-3", state="running", cpu_utilization=50.0
                ),
            ],
        )

        score = calculator.calculate(fleet)
        assert score == 100.0  # Only instances with data count

    def test_no_cpu_data_at_all(self, calculator: CostEfficiencyScore) -> None:
        """Test score when no instance has CPU data."""
        fleet = FleetMetrics(
            running_instances=3,
            instance_metrics=[
                InstanceMetrics(
                    instance_id="i-1", state="running", cpu_utilization=None
                ),
                InstanceMetrics(
                    instance_id="i-2", state="running", cpu_utilization=None
                ),
            ],
        )

        score = calculator.calculate(fleet)
        assert score == 50.0  # Neutral when no data

    def test_boundary_idle_threshold(self, calculator: CostEfficiencyScore) -> None:
        """Test boundary at idle threshold (5%)."""
        # Just below idle threshold
        fleet_idle = FleetMetrics(
            running_instances=1,
            instance_metrics=[
                InstanceMetrics(
                    instance_id="i-1", state="running", cpu_utilization=4.9
                ),
            ],
        )

        # Just above idle threshold
        fleet_underutilized = FleetMetrics(
            running_instances=1,
            instance_metrics=[
                InstanceMetrics(
                    instance_id="i-1", state="running", cpu_utilization=5.1
                ),
            ],
        )

        idle_score = calculator.calculate(fleet_idle)
        underutilized_score = calculator.calculate(fleet_underutilized)

        assert idle_score == 10.0
        assert underutilized_score == 50.0

    def test_boundary_underutilized_threshold(
        self, calculator: CostEfficiencyScore
    ) -> None:
        """Test boundary at underutilized threshold (20%)."""
        # Just below threshold
        fleet_under = FleetMetrics(
            running_instances=1,
            instance_metrics=[
                InstanceMetrics(
                    instance_id="i-1", state="running", cpu_utilization=19.9
                ),
            ],
        )

        # Just above threshold
        fleet_well = FleetMetrics(
            running_instances=1,
            instance_metrics=[
                InstanceMetrics(
                    instance_id="i-1", state="running", cpu_utilization=20.1
                ),
            ],
        )

        under_score = calculator.calculate(fleet_under)
        well_score = calculator.calculate(fleet_well)

        assert under_score == 50.0
        assert well_score == 100.0

    def test_get_status_healthy(self, calculator: CostEfficiencyScore) -> None:
        """Test status for healthy efficiency (>= 70%)."""
        assert calculator.get_status(70.0) == HealthStatus.HEALTHY
        assert calculator.get_status(85.0) == HealthStatus.HEALTHY
        assert calculator.get_status(100.0) == HealthStatus.HEALTHY

    def test_get_status_warning(self, calculator: CostEfficiencyScore) -> None:
        """Test status for warning efficiency (40-70%)."""
        assert calculator.get_status(69.9) == HealthStatus.WARNING
        assert calculator.get_status(50.0) == HealthStatus.WARNING
        assert calculator.get_status(40.0) == HealthStatus.WARNING

    def test_get_status_critical(self, calculator: CostEfficiencyScore) -> None:
        """Test status for critical efficiency (< 40%)."""
        assert calculator.get_status(39.9) == HealthStatus.CRITICAL
        assert calculator.get_status(20.0) == HealthStatus.CRITICAL
        assert calculator.get_status(1.0) == HealthStatus.CRITICAL

    def test_get_status_unknown(self, calculator: CostEfficiencyScore) -> None:
        """Test status for zero efficiency."""
        assert calculator.get_status(0.0) == HealthStatus.UNKNOWN


class TestCapacityUtilization:
    """Tests for CapacityUtilization calculation."""

    @pytest.fixture
    def calculator(self) -> CapacityUtilization:
        """Create a CapacityUtilization calculator."""
        return CapacityUtilization()

    def test_balanced_utilization(self, calculator: CapacityUtilization) -> None:
        """Test capacity with balanced utilization across metrics."""
        fleet = FleetMetrics(
            running_instances=5,
            avg_cpu_utilization=50.0,
            avg_memory_utilization=50.0,
            avg_disk_utilization=50.0,
        )

        score = calculator.calculate(fleet)
        assert score == 50.0

    def test_unbalanced_utilization(self, calculator: CapacityUtilization) -> None:
        """Test capacity with unbalanced utilization."""
        fleet = FleetMetrics(
            running_instances=5,
            avg_cpu_utilization=30.0,
            avg_memory_utilization=60.0,
            avg_disk_utilization=90.0,
        )

        score = calculator.calculate(fleet)
        assert score == 60.0  # (30 + 60 + 90) / 3

    def test_no_running_instances(self, calculator: CapacityUtilization) -> None:
        """Test capacity with no running instances."""
        fleet = FleetMetrics(running_instances=0)
        score = calculator.calculate(fleet)
        assert score == 0.0

    def test_partial_metrics(self, calculator: CapacityUtilization) -> None:
        """Test capacity when only some metrics are available."""
        fleet = FleetMetrics(
            running_instances=5,
            avg_cpu_utilization=60.0,
            avg_memory_utilization=0.0,  # No data
            avg_disk_utilization=40.0,
        )

        score = calculator.calculate(fleet)
        assert score == 50.0  # (60 + 40) / 2

    def test_only_cpu_metric(self, calculator: CapacityUtilization) -> None:
        """Test capacity with only CPU metric available."""
        fleet = FleetMetrics(
            running_instances=5,
            avg_cpu_utilization=80.0,
            avg_memory_utilization=0.0,
            avg_disk_utilization=0.0,
        )

        score = calculator.calculate(fleet)
        assert score == 80.0

    def test_all_zero_metrics(self, calculator: CapacityUtilization) -> None:
        """Test capacity when all metrics are zero."""
        fleet = FleetMetrics(
            running_instances=5,
            avg_cpu_utilization=0.0,
            avg_memory_utilization=0.0,
            avg_disk_utilization=0.0,
        )

        score = calculator.calculate(fleet)
        assert score == 0.0

    def test_rounding(self, calculator: CapacityUtilization) -> None:
        """Test that score is rounded to 2 decimal places."""
        fleet = FleetMetrics(
            running_instances=5,
            avg_cpu_utilization=33.33,
            avg_memory_utilization=33.33,
            avg_disk_utilization=33.34,
        )

        score = calculator.calculate(fleet)
        assert score == 33.33

    def test_get_status_healthy(self, calculator: CapacityUtilization) -> None:
        """Test status for optimal utilization (20-70%)."""
        assert calculator.get_status(45.0) == HealthStatus.HEALTHY
        assert calculator.get_status(20.0) == HealthStatus.HEALTHY
        assert calculator.get_status(70.0) == HealthStatus.HEALTHY

    def test_get_status_warning_low(self, calculator: CapacityUtilization) -> None:
        """Test status for low warning utilization (10-20%)."""
        assert calculator.get_status(15.0) == HealthStatus.WARNING
        assert calculator.get_status(10.0) == HealthStatus.WARNING

    def test_get_status_warning_high(self, calculator: CapacityUtilization) -> None:
        """Test status for high warning utilization (70-85%)."""
        assert calculator.get_status(75.0) == HealthStatus.WARNING
        assert calculator.get_status(85.0) == HealthStatus.WARNING

    def test_get_status_critical_low(self, calculator: CapacityUtilization) -> None:
        """Test status for critically low utilization (< 10%)."""
        assert calculator.get_status(5.0) == HealthStatus.CRITICAL
        assert calculator.get_status(9.0) == HealthStatus.CRITICAL

    def test_get_status_critical_high(self, calculator: CapacityUtilization) -> None:
        """Test status for critically high utilization (> 85%)."""
        assert calculator.get_status(90.0) == HealthStatus.CRITICAL
        assert calculator.get_status(100.0) == HealthStatus.CRITICAL


class TestMetricAggregator:
    """Tests for MetricAggregator class."""

    @pytest.fixture
    def aggregator(self) -> MetricAggregator:
        """Create a MetricAggregator instance."""
        return MetricAggregator(environment="test", fleet_name="test-fleet")

    @pytest.fixture
    def sample_fleet_metrics(self) -> FleetMetrics:
        """Create sample fleet metrics for testing."""
        return FleetMetrics(
            total_instances=4,
            running_instances=3,
            stopped_instances=1,
            pending_instances=0,
            avg_cpu_utilization=45.0,
            avg_memory_utilization=55.0,
            avg_disk_utilization=40.0,
            compliant_instances=3,
            non_compliant_instances=1,
            total_hourly_cost=0.50,
            instance_metrics=[
                InstanceMetrics(
                    instance_id="i-1",
                    state="running",
                    cpu_utilization=50.0,
                    hourly_cost=0.10,
                ),
                InstanceMetrics(
                    instance_id="i-2",
                    state="running",
                    cpu_utilization=40.0,
                    hourly_cost=0.20,
                ),
                InstanceMetrics(
                    instance_id="i-3",
                    state="running",
                    cpu_utilization=45.0,
                    hourly_cost=0.20,
                ),
                InstanceMetrics(instance_id="i-4", state="stopped"),
            ],
        )

    def test_initialization(self, aggregator: MetricAggregator) -> None:
        """Test aggregator initialization."""
        assert aggregator.environment == "test"
        assert aggregator.fleet_name == "test-fleet"
        assert len(aggregator.default_dimensions) == 2

    def test_default_dimensions(self, aggregator: MetricAggregator) -> None:
        """Test that default dimensions are set correctly."""
        dims = aggregator.default_dimensions
        env_dim = next(d for d in dims if d["Name"] == DimensionNames.ENVIRONMENT)
        fleet_dim = next(d for d in dims if d["Name"] == DimensionNames.FLEET_NAME)

        assert env_dim["Value"] == "test"
        assert fleet_dim["Value"] == "test-fleet"

    def test_aggregate_returns_all_metrics(
        self, aggregator: MetricAggregator, sample_fleet_metrics: FleetMetrics
    ) -> None:
        """Test that aggregation returns all expected metric types."""
        metrics = aggregator.aggregate(sample_fleet_metrics)
        metric_names = {m.name for m in metrics}

        expected = {
            MetricNames.INSTANCE_COUNT,
            MetricNames.RUNNING_INSTANCES,
            MetricNames.STOPPED_INSTANCES,
            MetricNames.PENDING_INSTANCES,
            MetricNames.CPU_UTILIZATION,
            MetricNames.MEMORY_UTILIZATION,
            MetricNames.DISK_UTILIZATION,
            MetricNames.FLEET_HEALTH_SCORE,
            MetricNames.COMPLIANCE_SCORE,
            MetricNames.COST_EFFICIENCY_SCORE,
            MetricNames.CAPACITY_UTILIZATION,
            MetricNames.COST_PER_INSTANCE,
            MetricNames.TOTAL_FLEET_COST,
        }

        assert expected.issubset(metric_names)

    def test_aggregate_metric_count(
        self, aggregator: MetricAggregator, sample_fleet_metrics: FleetMetrics
    ) -> None:
        """Test total number of metrics produced."""
        metrics = aggregator.aggregate(sample_fleet_metrics)
        assert len(metrics) == 13

    def test_instance_count_metrics(
        self, aggregator: MetricAggregator, sample_fleet_metrics: FleetMetrics
    ) -> None:
        """Test instance count metric values."""
        metrics = aggregator.aggregate(sample_fleet_metrics)

        instance_count = next(
            m for m in metrics if m.name == MetricNames.INSTANCE_COUNT
        )
        running = next(m for m in metrics if m.name == MetricNames.RUNNING_INSTANCES)
        stopped = next(m for m in metrics if m.name == MetricNames.STOPPED_INSTANCES)
        pending = next(m for m in metrics if m.name == MetricNames.PENDING_INSTANCES)

        assert instance_count.value == 4.0
        assert running.value == 3.0
        assert stopped.value == 1.0
        assert pending.value == 0.0

    def test_utilization_metrics(
        self, aggregator: MetricAggregator, sample_fleet_metrics: FleetMetrics
    ) -> None:
        """Test utilization metric values."""
        metrics = aggregator.aggregate(sample_fleet_metrics)

        cpu = next(m for m in metrics if m.name == MetricNames.CPU_UTILIZATION)
        memory = next(m for m in metrics if m.name == MetricNames.MEMORY_UTILIZATION)
        disk = next(m for m in metrics if m.name == MetricNames.DISK_UTILIZATION)

        assert cpu.value == 45.0
        assert memory.value == 55.0
        assert disk.value == 40.0
        assert cpu.unit == "Percent"
        assert memory.unit == "Percent"
        assert disk.unit == "Percent"

    def test_score_metrics(
        self, aggregator: MetricAggregator, sample_fleet_metrics: FleetMetrics
    ) -> None:
        """Test that score metrics are calculated and included."""
        metrics = aggregator.aggregate(sample_fleet_metrics)

        health = next(m for m in metrics if m.name == MetricNames.FLEET_HEALTH_SCORE)
        compliance = next(m for m in metrics if m.name == MetricNames.COMPLIANCE_SCORE)
        cost_eff = next(
            m for m in metrics if m.name == MetricNames.COST_EFFICIENCY_SCORE
        )
        capacity = next(
            m for m in metrics if m.name == MetricNames.CAPACITY_UTILIZATION
        )

        # All scores should be between 0 and 100
        assert 0.0 <= health.value <= 100.0
        assert 0.0 <= compliance.value <= 100.0
        assert 0.0 <= cost_eff.value <= 100.0
        assert 0.0 <= capacity.value <= 100.0

        # All should have Percent unit
        assert health.unit == "Percent"
        assert compliance.unit == "Percent"
        assert cost_eff.unit == "Percent"
        assert capacity.unit == "Percent"

    def test_cost_metrics(
        self, aggregator: MetricAggregator, sample_fleet_metrics: FleetMetrics
    ) -> None:
        """Test cost metric calculations."""
        metrics = aggregator.aggregate(sample_fleet_metrics)

        cost_per = next(m for m in metrics if m.name == MetricNames.COST_PER_INSTANCE)
        total_cost = next(m for m in metrics if m.name == MetricNames.TOTAL_FLEET_COST)

        # Total cost / running instances
        expected_cost_per = 0.50 / 3
        assert abs(cost_per.value - expected_cost_per) < 0.001
        assert total_cost.value == 0.50

    def test_cost_per_instance_no_running(
        self, aggregator: MetricAggregator
    ) -> None:
        """Test cost per instance when no instances are running."""
        fleet = FleetMetrics(
            total_instances=2,
            running_instances=0,
            total_hourly_cost=0.0,
        )

        metrics = aggregator.aggregate(fleet)
        cost_per = next(m for m in metrics if m.name == MetricNames.COST_PER_INSTANCE)

        assert cost_per.value == 0.0

    def test_all_metrics_have_dimensions(
        self, aggregator: MetricAggregator, sample_fleet_metrics: FleetMetrics
    ) -> None:
        """Test that all metrics include default dimensions."""
        metrics = aggregator.aggregate(sample_fleet_metrics)

        for metric in metrics:
            assert len(metric.dimensions) == 2
            dimension_names = {d["Name"] for d in metric.dimensions}
            assert DimensionNames.ENVIRONMENT in dimension_names
            assert DimensionNames.FLEET_NAME in dimension_names

    def test_all_metrics_have_timestamps(
        self, aggregator: MetricAggregator, sample_fleet_metrics: FleetMetrics
    ) -> None:
        """Test that all metrics have timestamps."""
        metrics = aggregator.aggregate(sample_fleet_metrics)

        for metric in metrics:
            assert metric.timestamp is not None
            assert isinstance(metric.timestamp, datetime)

    def test_empty_fleet_aggregation(self, aggregator: MetricAggregator) -> None:
        """Test aggregation of empty fleet."""
        empty_fleet = FleetMetrics()
        metrics = aggregator.aggregate(empty_fleet)

        # Should still produce all metrics
        assert len(metrics) == 13

        # Instance counts should all be zero
        instance_count = next(
            m for m in metrics if m.name == MetricNames.INSTANCE_COUNT
        )
        assert instance_count.value == 0.0


class TestMetricValidation:
    """Tests for metric value validation and edge cases."""

    def test_metric_value_with_very_large_number(self) -> None:
        """Test MetricValue handles very large numbers."""
        metric = MetricValue(name="Large", value=1e15)
        cw_format = metric.to_cloudwatch_format()
        assert cw_format["Value"] == 1e15

    def test_metric_value_with_very_small_number(self) -> None:
        """Test MetricValue handles very small numbers."""
        metric = MetricValue(name="Small", value=1e-10)
        cw_format = metric.to_cloudwatch_format()
        assert cw_format["Value"] == 1e-10

    def test_fleet_health_score_precision(self) -> None:
        """Test that health score maintains appropriate precision."""
        calculator = FleetHealthScore()
        fleet = FleetMetrics(
            total_instances=100,
            running_instances=100,
            avg_cpu_utilization=33.333333,
            avg_memory_utilization=33.333333,
            avg_disk_utilization=33.333333,
            compliant_instances=100,
            non_compliant_instances=0,
        )

        score = calculator.calculate(fleet)
        # Score should be rounded to 2 decimal places
        assert score == round(score, 2)

    def test_compliance_status_enum(self) -> None:
        """Test ComplianceStatus enum values."""
        assert ComplianceStatus.COMPLIANT.value == "COMPLIANT"
        assert ComplianceStatus.NON_COMPLIANT.value == "NON_COMPLIANT"
        assert ComplianceStatus.UNKNOWN.value == "UNKNOWN"

    def test_health_status_enum(self) -> None:
        """Test HealthStatus enum values."""
        assert HealthStatus.HEALTHY.value == "healthy"
        assert HealthStatus.WARNING.value == "warning"
        assert HealthStatus.CRITICAL.value == "critical"
        assert HealthStatus.UNKNOWN.value == "unknown"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
