"""Unit tests for Hyperion Fleet Manager Metric Aggregator Lambda handler.

This module contains comprehensive tests for the metric aggregator,
using moto for AWS service mocking.
"""

from __future__ import annotations

import json
import os
from datetime import datetime, timedelta, timezone
from typing import Any
from unittest.mock import MagicMock, patch

import boto3
import pytest
from moto import mock_aws

# Set environment variables before importing modules
os.environ["AWS_DEFAULT_REGION"] = "us-east-1"
os.environ["AWS_ACCESS_KEY_ID"] = "testing"
os.environ["AWS_SECRET_ACCESS_KEY"] = "testing"
os.environ["ENVIRONMENT"] = "test"
os.environ["FLEET_NAME"] = "test-fleet"
os.environ["POWERTOOLS_SERVICE_NAME"] = "test-metric-aggregator"
os.environ["POWERTOOLS_METRICS_NAMESPACE"] = "Test/Namespace"

# Import after setting environment
from config import Config, get_config
from metrics import (
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


@pytest.fixture
def config() -> Config:
    """Create a test configuration."""
    return Config(
        environment="test",
        region="us-east-1",
        fleet_name="test-fleet",
        metric_namespace="Test/FleetManager",
    )


@pytest.fixture
def sample_instance_metrics() -> list[InstanceMetrics]:
    """Create sample instance metrics for testing."""
    return [
        InstanceMetrics(
            instance_id="i-1234567890abcdef0",
            instance_type="t3.large",
            availability_zone="us-east-1a",
            state="running",
            cpu_utilization=45.5,
            memory_utilization=60.0,
            disk_utilization=50.0,
            is_compliant=True,
            hourly_cost=0.0832,
        ),
        InstanceMetrics(
            instance_id="i-1234567890abcdef1",
            instance_type="t3.medium",
            availability_zone="us-east-1b",
            state="running",
            cpu_utilization=75.0,
            memory_utilization=80.0,
            disk_utilization=70.0,
            is_compliant=True,
            hourly_cost=0.0416,
        ),
        InstanceMetrics(
            instance_id="i-1234567890abcdef2",
            instance_type="t3.large",
            availability_zone="us-east-1a",
            state="stopped",
            cpu_utilization=None,
            memory_utilization=None,
            disk_utilization=None,
            is_compliant=None,
            hourly_cost=0.0,
        ),
        InstanceMetrics(
            instance_id="i-1234567890abcdef3",
            instance_type="m5.xlarge",
            availability_zone="us-east-1b",
            state="running",
            cpu_utilization=3.0,  # Idle instance
            memory_utilization=20.0,
            disk_utilization=30.0,
            is_compliant=False,
            hourly_cost=0.192,
        ),
    ]


@pytest.fixture
def sample_fleet_metrics(sample_instance_metrics: list[InstanceMetrics]) -> FleetMetrics:
    """Create sample fleet metrics for testing."""
    return FleetMetrics(
        total_instances=4,
        running_instances=3,
        stopped_instances=1,
        pending_instances=0,
        avg_cpu_utilization=41.17,  # (45.5 + 75 + 3) / 3
        avg_memory_utilization=53.33,  # (60 + 80 + 20) / 3
        avg_disk_utilization=50.0,  # (50 + 70 + 30) / 3
        compliant_instances=2,
        non_compliant_instances=1,
        total_hourly_cost=0.3168,  # 0.0832 + 0.0416 + 0.192
        instance_metrics=sample_instance_metrics,
    )


class TestConfig:
    """Tests for configuration module."""

    def test_get_config_defaults(self) -> None:
        """Test default configuration values."""
        config = get_config()
        assert config.environment == "test"
        assert config.fleet_name == "test-fleet"
        assert config.region == "us-east-1"

    def test_get_instance_cost_known_type(self, config: Config) -> None:
        """Test cost lookup for known instance type."""
        cost = config.get_instance_cost("t3.large")
        assert cost == 0.0832

    def test_get_instance_cost_unknown_type(self, config: Config) -> None:
        """Test cost lookup for unknown instance type returns default."""
        cost = config.get_instance_cost("x99.unknown")
        assert cost == 0.10

    def test_is_production(self) -> None:
        """Test production environment detection."""
        dev_config = Config(environment="dev")
        prod_config = Config(environment="production")

        assert not dev_config.is_production
        assert prod_config.is_production

    def test_default_dimensions(self, config: Config) -> None:
        """Test default dimension generation."""
        dimensions = config.default_dimensions
        assert len(dimensions) == 2
        assert {"Name": "Environment", "Value": "test"} in dimensions
        assert {"Name": "FleetName", "Value": "test-fleet"} in dimensions


class TestMetricValue:
    """Tests for MetricValue class."""

    def test_metric_value_creation(self) -> None:
        """Test creating a metric value."""
        metric = MetricValue(
            name="TestMetric",
            value=42.5,
            unit="Percent",
            dimensions=[{"Name": "Test", "Value": "Value"}],
        )

        assert metric.name == "TestMetric"
        assert metric.value == 42.5
        assert metric.unit == "Percent"

    def test_to_cloudwatch_format(self) -> None:
        """Test conversion to CloudWatch format."""
        metric = MetricValue(
            name="TestMetric",
            value=42.5,
            unit="Percent",
            dimensions=[{"Name": "Test", "Value": "Value"}],
        )

        cw_format = metric.to_cloudwatch_format()

        assert cw_format["MetricName"] == "TestMetric"
        assert cw_format["Value"] == 42.5
        assert cw_format["Unit"] == "Percent"
        assert cw_format["Dimensions"] == [{"Name": "Test", "Value": "Value"}]
        assert "Timestamp" in cw_format


class TestFleetHealthScore:
    """Tests for FleetHealthScore calculation."""

    def test_healthy_fleet(self, sample_fleet_metrics: FleetMetrics) -> None:
        """Test health score for a reasonably healthy fleet."""
        calculator = FleetHealthScore()
        score = calculator.calculate(sample_fleet_metrics)

        # Fleet with moderate utilization should have decent health score
        assert 50 <= score <= 80

    def test_empty_fleet(self) -> None:
        """Test health score for empty fleet."""
        calculator = FleetHealthScore()
        empty_metrics = FleetMetrics()

        score = calculator.calculate(empty_metrics)
        assert score == 0.0

    def test_critical_utilization(self) -> None:
        """Test health score with critical utilization levels."""
        calculator = FleetHealthScore()
        critical_metrics = FleetMetrics(
            total_instances=1,
            running_instances=1,
            avg_cpu_utilization=95.0,
            avg_memory_utilization=95.0,
            avg_disk_utilization=98.0,
            compliant_instances=0,
            non_compliant_instances=1,
        )

        score = calculator.calculate(critical_metrics)
        assert score < 30  # Should be critical

    def test_get_status_healthy(self) -> None:
        """Test status determination for healthy score."""
        calculator = FleetHealthScore()
        assert calculator.get_status(85) == HealthStatus.HEALTHY

    def test_get_status_warning(self) -> None:
        """Test status determination for warning score."""
        calculator = FleetHealthScore()
        assert calculator.get_status(65) == HealthStatus.WARNING

    def test_get_status_critical(self) -> None:
        """Test status determination for critical score."""
        calculator = FleetHealthScore()
        assert calculator.get_status(30) == HealthStatus.CRITICAL


class TestComplianceScore:
    """Tests for ComplianceScore calculation."""

    def test_full_compliance(self) -> None:
        """Test score with full compliance."""
        calculator = ComplianceScore()
        metrics = FleetMetrics(
            compliant_instances=10,
            non_compliant_instances=0,
        )

        score = calculator.calculate(metrics)
        assert score == 100.0

    def test_partial_compliance(self, sample_fleet_metrics: FleetMetrics) -> None:
        """Test score with partial compliance."""
        calculator = ComplianceScore()
        score = calculator.calculate(sample_fleet_metrics)

        # 2 compliant, 1 non-compliant = 66.67%
        assert 66 <= score <= 67

    def test_no_compliance_data(self) -> None:
        """Test score with no compliance data."""
        calculator = ComplianceScore()
        metrics = FleetMetrics()

        score = calculator.calculate(metrics)
        assert score == 100.0  # Assume healthy when no data

    def test_get_status(self) -> None:
        """Test status determination."""
        calculator = ComplianceScore()
        assert calculator.get_status(95) == HealthStatus.HEALTHY
        assert calculator.get_status(85) == HealthStatus.WARNING
        assert calculator.get_status(70) == HealthStatus.CRITICAL


class TestCostEfficiencyScore:
    """Tests for CostEfficiencyScore calculation."""

    def test_well_utilized_fleet(self) -> None:
        """Test score with well-utilized instances."""
        calculator = CostEfficiencyScore()
        metrics = FleetMetrics(
            running_instances=3,
            instance_metrics=[
                InstanceMetrics(
                    instance_id="i-1",
                    state="running",
                    cpu_utilization=50.0,
                ),
                InstanceMetrics(
                    instance_id="i-2",
                    state="running",
                    cpu_utilization=60.0,
                ),
                InstanceMetrics(
                    instance_id="i-3",
                    state="running",
                    cpu_utilization=40.0,
                ),
            ],
        )

        score = calculator.calculate(metrics)
        assert score == 100.0  # All well-utilized

    def test_idle_fleet(self) -> None:
        """Test score with idle instances."""
        calculator = CostEfficiencyScore()
        metrics = FleetMetrics(
            running_instances=3,
            instance_metrics=[
                InstanceMetrics(
                    instance_id="i-1",
                    state="running",
                    cpu_utilization=2.0,  # Idle
                ),
                InstanceMetrics(
                    instance_id="i-2",
                    state="running",
                    cpu_utilization=3.0,  # Idle
                ),
                InstanceMetrics(
                    instance_id="i-3",
                    state="running",
                    cpu_utilization=1.0,  # Idle
                ),
            ],
        )

        score = calculator.calculate(metrics)
        assert score == 10.0  # All idle = low efficiency

    def test_mixed_utilization(self, sample_fleet_metrics: FleetMetrics) -> None:
        """Test score with mixed utilization."""
        calculator = CostEfficiencyScore()
        score = calculator.calculate(sample_fleet_metrics)

        # Mix of well-utilized, underutilized, and idle
        assert 40 <= score <= 80

    def test_empty_fleet(self) -> None:
        """Test score with no running instances."""
        calculator = CostEfficiencyScore()
        metrics = FleetMetrics(running_instances=0)

        score = calculator.calculate(metrics)
        assert score == 0.0


class TestCapacityUtilization:
    """Tests for CapacityUtilization calculation."""

    def test_balanced_utilization(self) -> None:
        """Test capacity utilization with balanced metrics."""
        calculator = CapacityUtilization()
        metrics = FleetMetrics(
            running_instances=1,
            avg_cpu_utilization=50.0,
            avg_memory_utilization=50.0,
            avg_disk_utilization=50.0,
        )

        score = calculator.calculate(metrics)
        assert score == 50.0

    def test_no_running_instances(self) -> None:
        """Test capacity utilization with no running instances."""
        calculator = CapacityUtilization()
        metrics = FleetMetrics(running_instances=0)

        score = calculator.calculate(metrics)
        assert score == 0.0

    def test_get_status_optimal(self) -> None:
        """Test status for optimal utilization."""
        calculator = CapacityUtilization()
        assert calculator.get_status(45) == HealthStatus.HEALTHY

    def test_get_status_overutilized(self) -> None:
        """Test status for over-utilized capacity."""
        calculator = CapacityUtilization()
        assert calculator.get_status(90) == HealthStatus.CRITICAL


class TestMetricAggregator:
    """Tests for MetricAggregator class."""

    def test_aggregate_creates_all_metrics(
        self, sample_fleet_metrics: FleetMetrics
    ) -> None:
        """Test that aggregation creates all expected metrics."""
        aggregator = MetricAggregator("test", "test-fleet")
        metrics = aggregator.aggregate(sample_fleet_metrics)

        metric_names = {m.name for m in metrics}

        # Check for all expected metrics
        expected_metrics = {
            "InstanceCount",
            "RunningInstances",
            "StoppedInstances",
            "PendingInstances",
            "CPUUtilization",
            "MemoryUtilization",
            "DiskUtilization",
            "FleetHealthScore",
            "ComplianceScore",
            "CostEfficiencyScore",
            "CapacityUtilization",
            "CostPerInstance",
            "TotalFleetCost",
        }

        assert expected_metrics.issubset(metric_names)

    def test_aggregate_includes_dimensions(
        self, sample_fleet_metrics: FleetMetrics
    ) -> None:
        """Test that aggregated metrics include proper dimensions."""
        aggregator = MetricAggregator("test", "test-fleet")
        metrics = aggregator.aggregate(sample_fleet_metrics)

        for metric in metrics:
            dimension_names = {d["Name"] for d in metric.dimensions}
            assert "Environment" in dimension_names
            assert "FleetName" in dimension_names

    def test_aggregate_correct_values(
        self, sample_fleet_metrics: FleetMetrics
    ) -> None:
        """Test that aggregated metrics have correct values."""
        aggregator = MetricAggregator("test", "test-fleet")
        metrics = aggregator.aggregate(sample_fleet_metrics)

        # Find specific metrics and verify values
        for metric in metrics:
            if metric.name == "InstanceCount":
                assert metric.value == 4.0
            elif metric.name == "RunningInstances":
                assert metric.value == 3.0
            elif metric.name == "StoppedInstances":
                assert metric.value == 1.0


@mock_aws
class TestCloudWatchClient:
    """Tests for CloudWatch client with moto mocking."""

    def test_publish_metrics_success(self, config: Config) -> None:
        """Test successful metric publishing."""
        from cloudwatch_client import CloudWatchMetricClient

        # Create CloudWatch client
        client = CloudWatchMetricClient(config)

        # Create test metrics
        metrics = [
            MetricValue(
                name="TestMetric1",
                value=42.0,
                unit="Count",
                dimensions=[{"Name": "Test", "Value": "Value"}],
            ),
            MetricValue(
                name="TestMetric2",
                value=84.0,
                unit="Percent",
                dimensions=[{"Name": "Test", "Value": "Value"}],
            ),
        ]

        # Publish metrics
        count = client.publish_metrics(metrics)
        assert count == 2

    def test_publish_metrics_batching(self, config: Config) -> None:
        """Test that metrics are batched correctly."""
        from cloudwatch_client import CloudWatchMetricClient

        client = CloudWatchMetricClient(config)

        # Create more than 20 metrics to test batching
        metrics = [
            MetricValue(
                name=f"TestMetric{i}",
                value=float(i),
                unit="Count",
            )
            for i in range(25)
        ]

        count = client.publish_metrics(metrics)
        assert count == 25

    def test_publish_empty_metrics(self, config: Config) -> None:
        """Test publishing empty metric list."""
        from cloudwatch_client import CloudWatchMetricClient

        client = CloudWatchMetricClient(config)
        count = client.publish_metrics([])
        assert count == 0


@mock_aws
class TestSSMClient:
    """Tests for SSM client with moto mocking."""

    def setup_method(self) -> None:
        """Set up mock SSM resources."""
        self.ssm = boto3.client("ssm", region_name="us-east-1")

    def test_get_managed_instances_empty(self, config: Config) -> None:
        """Test getting managed instances when none exist."""
        from ssm_client import SSMInventoryClient

        client = SSMInventoryClient(config)
        instances = client.get_managed_instances()

        assert instances == []


@mock_aws
class TestEC2Client:
    """Tests for EC2 instance client with moto mocking."""

    def setup_method(self) -> None:
        """Set up mock EC2 resources."""
        self.ec2 = boto3.client("ec2", region_name="us-east-1")

        # Create a VPC first
        vpc_response = self.ec2.create_vpc(CidrBlock="10.0.0.0/16")
        self.vpc_id = vpc_response["Vpc"]["VpcId"]

        # Create a subnet
        subnet_response = self.ec2.create_subnet(
            VpcId=self.vpc_id,
            CidrBlock="10.0.1.0/24",
            AvailabilityZone="us-east-1a",
        )
        self.subnet_id = subnet_response["Subnet"]["SubnetId"]

    def test_get_fleet_instances(self, config: Config) -> None:
        """Test getting fleet instances."""
        from ssm_client import EC2InstanceClient

        # Create test instances with fleet tag
        self.ec2.run_instances(
            ImageId="ami-12345678",
            MinCount=2,
            MaxCount=2,
            InstanceType="t3.large",
            SubnetId=self.subnet_id,
            TagSpecifications=[
                {
                    "ResourceType": "instance",
                    "Tags": [
                        {"Key": "Fleet", "Value": "test-fleet"},
                        {"Key": "Name", "Value": "test-instance"},
                    ],
                }
            ],
        )

        client = EC2InstanceClient(config)
        instances = client.get_fleet_instances("test-fleet")

        assert len(instances) == 2
        for instance in instances:
            assert instance.instance_type == "t3.large"
            assert instance.state == "running"

    def test_get_instance_counts_by_state(self, config: Config) -> None:
        """Test counting instances by state."""
        from ssm_client import EC2InstanceClient

        instances = [
            InstanceMetrics(instance_id="i-1", state="running"),
            InstanceMetrics(instance_id="i-2", state="running"),
            InstanceMetrics(instance_id="i-3", state="stopped"),
            InstanceMetrics(instance_id="i-4", state="pending"),
        ]

        client = EC2InstanceClient(config)
        counts = client.get_instance_counts_by_state(instances)

        assert counts["running"] == 2
        assert counts["stopped"] == 1
        assert counts["pending"] == 1


class TestLambdaHandler:
    """Tests for the main Lambda handler."""

    @mock_aws
    def test_handler_success(self) -> None:
        """Test successful Lambda invocation."""
        # Set up mock AWS resources
        ec2 = boto3.client("ec2", region_name="us-east-1")
        vpc = ec2.create_vpc(CidrBlock="10.0.0.0/16")
        subnet = ec2.create_subnet(
            VpcId=vpc["Vpc"]["VpcId"],
            CidrBlock="10.0.1.0/24",
            AvailabilityZone="us-east-1a",
        )

        # Create test instances
        ec2.run_instances(
            ImageId="ami-12345678",
            MinCount=2,
            MaxCount=2,
            InstanceType="t3.large",
            SubnetId=subnet["Subnet"]["SubnetId"],
            TagSpecifications=[
                {
                    "ResourceType": "instance",
                    "Tags": [{"Key": "Fleet", "Value": "test-fleet"}],
                }
            ],
        )

        # Import handler after setting up mocks
        from handler import lambda_handler

        # Create mock event and context
        event: dict[str, Any] = {
            "source": "aws.events",
            "detail-type": "Scheduled Event",
        }
        context = MagicMock()
        context.function_name = "test-function"
        context.memory_limit_in_mb = 512
        context.invoked_function_arn = (
            "arn:aws:lambda:us-east-1:123456789012:function:test"
        )
        context.aws_request_id = "test-request-id"

        # Invoke handler
        response = lambda_handler(event, context)

        assert response["statusCode"] == 200
        assert "instances_processed" in response["body"]

    def test_handler_error_handling(self) -> None:
        """Test handler error handling."""
        from handler import lambda_handler

        # Mock clients to raise errors
        with patch("handler.EC2InstanceClient") as mock_ec2:
            mock_ec2.return_value.get_fleet_instances.side_effect = Exception(
                "Test error"
            )

            event: dict[str, Any] = {}
            context = MagicMock()
            context.function_name = "test-function"
            context.memory_limit_in_mb = 512
            context.invoked_function_arn = (
                "arn:aws:lambda:us-east-1:123456789012:function:test"
            )
            context.aws_request_id = "test-request-id"

            response = lambda_handler(event, context)

            assert response["statusCode"] == 500
            assert "error" in response["body"]


class TestIntegration:
    """Integration tests for the full aggregation flow."""

    def test_full_aggregation_flow(
        self, sample_instance_metrics: list[InstanceMetrics]
    ) -> None:
        """Test complete metric aggregation flow."""
        # Create fleet metrics from instance data
        fleet_metrics = FleetMetrics(
            total_instances=len(sample_instance_metrics),
            running_instances=sum(
                1 for i in sample_instance_metrics if i.state == "running"
            ),
            stopped_instances=sum(
                1 for i in sample_instance_metrics if i.state == "stopped"
            ),
            instance_metrics=sample_instance_metrics,
        )

        # Calculate averages
        running = [i for i in sample_instance_metrics if i.state == "running"]
        if running:
            cpu_values = [i.cpu_utilization for i in running if i.cpu_utilization]
            fleet_metrics.avg_cpu_utilization = sum(cpu_values) / len(cpu_values)

        # Aggregate metrics
        aggregator = MetricAggregator("test", "test-fleet")
        metrics = aggregator.aggregate(fleet_metrics)

        # Verify all expected metrics are present
        assert len(metrics) >= 10

        # Verify scores are calculated
        health_score = next(
            (m for m in metrics if m.name == "FleetHealthScore"), None
        )
        assert health_score is not None
        assert 0 <= health_score.value <= 100


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
