"""Pytest configuration and shared fixtures for metric aggregator tests.

This module provides common test fixtures and configuration used across
all test modules in the metric aggregator test suite.
"""

from __future__ import annotations

import os
import sys
from datetime import datetime, timezone
from typing import Any, Generator
from unittest.mock import MagicMock

import boto3
import pytest
from moto import mock_aws

# Add the parent directory to sys.path to allow imports from the lambda module
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def pytest_configure(config: Any) -> None:
    """Configure pytest with custom markers and environment.

    This function is called before test collection begins. It sets up
    environment variables required for AWS SDK and Lambda Powertools.
    """
    # Set required environment variables for testing
    os.environ["AWS_DEFAULT_REGION"] = "us-east-1"
    os.environ["AWS_ACCESS_KEY_ID"] = "testing"
    os.environ["AWS_SECRET_ACCESS_KEY"] = "testing"
    os.environ["ENVIRONMENT"] = "test"
    os.environ["FLEET_NAME"] = "test-fleet"
    os.environ["POWERTOOLS_SERVICE_NAME"] = "test-metric-aggregator"
    os.environ["POWERTOOLS_METRICS_NAMESPACE"] = "Test/Namespace"
    os.environ["LOG_LEVEL"] = "DEBUG"

    # Register custom markers
    config.addinivalue_line(
        "markers", "integration: marks tests as integration tests (deselect with '-m \"not integration\"')"
    )
    config.addinivalue_line(
        "markers", "slow: marks tests as slow running (deselect with '-m \"not slow\"')"
    )


@pytest.fixture(scope="session")
def aws_credentials() -> None:
    """Mock AWS credentials for moto.

    This fixture sets up fake AWS credentials that moto will use for
    mocking AWS service calls. It's session-scoped for efficiency.
    """
    os.environ["AWS_ACCESS_KEY_ID"] = "testing"
    os.environ["AWS_SECRET_ACCESS_KEY"] = "testing"
    os.environ["AWS_SECURITY_TOKEN"] = "testing"
    os.environ["AWS_SESSION_TOKEN"] = "testing"
    os.environ["AWS_DEFAULT_REGION"] = "us-east-1"


@pytest.fixture
def mock_aws_services(aws_credentials: None) -> Generator[None, None, None]:
    """Provide mocked AWS services for testing.

    This fixture wraps test functions with moto's mock_aws context manager,
    enabling all AWS service mocks for the duration of the test.

    Yields:
        None - the fixture provides the mocking context
    """
    with mock_aws():
        yield


@pytest.fixture
def ec2_client(mock_aws_services: None) -> Any:
    """Create a mocked EC2 client.

    Returns:
        Mocked boto3 EC2 client.
    """
    return boto3.client("ec2", region_name="us-east-1")


@pytest.fixture
def cloudwatch_client(mock_aws_services: None) -> Any:
    """Create a mocked CloudWatch client.

    Returns:
        Mocked boto3 CloudWatch client.
    """
    return boto3.client("cloudwatch", region_name="us-east-1")


@pytest.fixture
def ssm_client(mock_aws_services: None) -> Any:
    """Create a mocked SSM client.

    Returns:
        Mocked boto3 SSM client.
    """
    return boto3.client("ssm", region_name="us-east-1")


@pytest.fixture
def vpc_with_subnet(ec2_client: Any) -> dict[str, str]:
    """Create a VPC with subnet for instance testing.

    Creates a VPC and a subnet in us-east-1a for use in tests that
    need to launch EC2 instances.

    Returns:
        Dictionary with vpc_id and subnet_id.
    """
    vpc = ec2_client.create_vpc(CidrBlock="10.0.0.0/16")
    vpc_id = vpc["Vpc"]["VpcId"]

    subnet = ec2_client.create_subnet(
        VpcId=vpc_id,
        CidrBlock="10.0.1.0/24",
        AvailabilityZone="us-east-1a",
    )
    subnet_id = subnet["Subnet"]["SubnetId"]

    return {"vpc_id": vpc_id, "subnet_id": subnet_id}


@pytest.fixture
def fleet_instances(ec2_client: Any, vpc_with_subnet: dict[str, str]) -> list[str]:
    """Create test fleet instances.

    Creates 3 EC2 instances tagged as part of the test fleet.

    Returns:
        List of instance IDs.
    """
    response = ec2_client.run_instances(
        ImageId="ami-12345678",
        MinCount=3,
        MaxCount=3,
        InstanceType="t3.large",
        SubnetId=vpc_with_subnet["subnet_id"],
        TagSpecifications=[
            {
                "ResourceType": "instance",
                "Tags": [
                    {"Key": "Fleet", "Value": "test-fleet"},
                    {"Key": "Name", "Value": "test-instance"},
                    {"Key": "Environment", "Value": "test"},
                ],
            }
        ],
    )

    instance_ids = [instance["InstanceId"] for instance in response["Instances"]]
    return instance_ids


@pytest.fixture
def lambda_context() -> Any:
    """Create a mock Lambda context object.

    Returns a MagicMock configured to simulate the Lambda context
    object passed to handler functions.

    Returns:
        Mock Lambda context with typical attributes set.
    """
    context = MagicMock()
    context.function_name = "hyperion-metric-aggregator-test"
    context.memory_limit_in_mb = 512
    context.invoked_function_arn = (
        "arn:aws:lambda:us-east-1:123456789012:function:hyperion-metric-aggregator-test"
    )
    context.aws_request_id = "test-request-id-12345"
    context.log_group_name = "/aws/lambda/hyperion-metric-aggregator-test"
    context.log_stream_name = "2024/01/01/[$LATEST]test-stream"

    def get_remaining_time_in_millis() -> int:
        return 120000  # 2 minutes

    context.get_remaining_time_in_millis = get_remaining_time_in_millis

    return context


@pytest.fixture
def cloudwatch_event() -> dict[str, Any]:
    """Create a sample CloudWatch Events scheduled event.

    Returns:
        Dictionary representing a CloudWatch Events scheduled event payload.
    """
    return {
        "version": "0",
        "id": "12345678-1234-1234-1234-123456789012",
        "detail-type": "Scheduled Event",
        "source": "aws.events",
        "account": "123456789012",
        "time": "2024-01-01T12:00:00Z",
        "region": "us-east-1",
        "resources": [
            "arn:aws:events:us-east-1:123456789012:rule/hyperion-metric-aggregation-test"
        ],
        "detail": {},
    }


@pytest.fixture
def test_config() -> dict[str, Any]:
    """Create test configuration dictionary.

    Returns:
        Dictionary with test configuration values.
    """
    return {
        "environment": "test",
        "region": "us-east-1",
        "fleet_name": "test-fleet",
        "metric_namespace": "Test/FleetManager",
        "aggregation_period_minutes": 5,
        "max_instances_per_query": 100,
        "enable_detailed_metrics": False,
        "log_level": "DEBUG",
    }


@pytest.fixture
def sample_instance_data() -> list[dict[str, Any]]:
    """Create sample instance data for testing.

    Returns:
        List of dictionaries with instance metric data.
    """
    return [
        {
            "instance_id": "i-1234567890abcdef0",
            "instance_type": "t3.large",
            "availability_zone": "us-east-1a",
            "state": "running",
            "cpu_utilization": 45.5,
            "memory_utilization": 60.0,
            "disk_utilization": 50.0,
            "is_compliant": True,
            "hourly_cost": 0.0832,
        },
        {
            "instance_id": "i-1234567890abcdef1",
            "instance_type": "t3.medium",
            "availability_zone": "us-east-1b",
            "state": "running",
            "cpu_utilization": 75.0,
            "memory_utilization": 80.0,
            "disk_utilization": 70.0,
            "is_compliant": True,
            "hourly_cost": 0.0416,
        },
        {
            "instance_id": "i-1234567890abcdef2",
            "instance_type": "t3.large",
            "availability_zone": "us-east-1a",
            "state": "stopped",
            "cpu_utilization": None,
            "memory_utilization": None,
            "disk_utilization": None,
            "is_compliant": None,
            "hourly_cost": 0.0,
        },
        {
            "instance_id": "i-1234567890abcdef3",
            "instance_type": "m5.xlarge",
            "availability_zone": "us-east-1b",
            "state": "running",
            "cpu_utilization": 3.0,  # Idle instance
            "memory_utilization": 20.0,
            "disk_utilization": 30.0,
            "is_compliant": False,
            "hourly_cost": 0.192,
        },
    ]


@pytest.fixture
def sample_compliance_data() -> dict[str, str]:
    """Create sample compliance status data.

    Returns:
        Dictionary mapping instance IDs to compliance status.
    """
    return {
        "i-1234567890abcdef0": "COMPLIANT",
        "i-1234567890abcdef1": "COMPLIANT",
        "i-1234567890abcdef3": "NON_COMPLIANT",
    }


@pytest.fixture
def sample_cloudwatch_metrics() -> dict[str, list[dict[str, Any]]]:
    """Create sample CloudWatch metric data.

    Returns:
        Dictionary with metric data responses.
    """
    now = datetime.now(timezone.utc)
    return {
        "CPUUtilization": [
            {
                "Id": "m0",
                "Label": "CPUUtilization",
                "Timestamps": [now],
                "Values": [45.5],
                "StatusCode": "Complete",
            },
            {
                "Id": "m1",
                "Label": "CPUUtilization",
                "Timestamps": [now],
                "Values": [75.0],
                "StatusCode": "Complete",
            },
            {
                "Id": "m2",
                "Label": "CPUUtilization",
                "Timestamps": [now],
                "Values": [3.0],
                "StatusCode": "Complete",
            },
        ],
        "mem_used_percent": [
            {
                "Id": "m0",
                "Label": "mem_used_percent",
                "Timestamps": [now],
                "Values": [60.0],
                "StatusCode": "Complete",
            },
            {
                "Id": "m1",
                "Label": "mem_used_percent",
                "Timestamps": [now],
                "Values": [80.0],
                "StatusCode": "Complete",
            },
            {
                "Id": "m2",
                "Label": "mem_used_percent",
                "Timestamps": [now],
                "Values": [20.0],
                "StatusCode": "Complete",
            },
        ],
    }


@pytest.fixture
def empty_fleet_data() -> dict[str, Any]:
    """Create data representing an empty fleet.

    Returns:
        Dictionary with empty fleet metrics.
    """
    return {
        "total_instances": 0,
        "running_instances": 0,
        "stopped_instances": 0,
        "pending_instances": 0,
        "avg_cpu_utilization": 0.0,
        "avg_memory_utilization": 0.0,
        "avg_disk_utilization": 0.0,
        "compliant_instances": 0,
        "non_compliant_instances": 0,
        "total_hourly_cost": 0.0,
    }


@pytest.fixture
def critical_fleet_data() -> dict[str, Any]:
    """Create data representing a fleet in critical state.

    Returns:
        Dictionary with critical fleet metrics.
    """
    return {
        "total_instances": 5,
        "running_instances": 5,
        "stopped_instances": 0,
        "pending_instances": 0,
        "avg_cpu_utilization": 95.0,
        "avg_memory_utilization": 92.0,
        "avg_disk_utilization": 98.0,
        "compliant_instances": 1,
        "non_compliant_instances": 4,
        "total_hourly_cost": 2.50,
    }


@pytest.fixture
def healthy_fleet_data() -> dict[str, Any]:
    """Create data representing a healthy fleet.

    Returns:
        Dictionary with healthy fleet metrics.
    """
    return {
        "total_instances": 10,
        "running_instances": 8,
        "stopped_instances": 2,
        "pending_instances": 0,
        "avg_cpu_utilization": 45.0,
        "avg_memory_utilization": 55.0,
        "avg_disk_utilization": 40.0,
        "compliant_instances": 8,
        "non_compliant_instances": 0,
        "total_hourly_cost": 1.20,
    }


@pytest.fixture
def mock_config() -> Any:
    """Create a mock Config object.

    Returns:
        Mock configuration object with default values.
    """
    from config import Config

    return Config(
        environment="test",
        region="us-east-1",
        fleet_name="test-fleet",
        metric_namespace="Test/FleetManager",
        aggregation_period_minutes=5,
    )


@pytest.fixture
def mock_ec2_instance_client(mock_config: Any) -> Any:
    """Create a mock EC2InstanceClient.

    Returns:
        Mock EC2InstanceClient with predefined behavior.
    """
    from metrics import InstanceMetrics

    mock_client = MagicMock()
    mock_client.config = mock_config

    # Default return values
    mock_client.get_fleet_instances.return_value = [
        InstanceMetrics(
            instance_id="i-1",
            instance_type="t3.large",
            state="running",
            availability_zone="us-east-1a",
            hourly_cost=0.0832,
        ),
        InstanceMetrics(
            instance_id="i-2",
            instance_type="t3.large",
            state="running",
            availability_zone="us-east-1b",
            hourly_cost=0.0832,
        ),
    ]

    mock_client.get_instance_counts_by_state.return_value = {
        "running": 2,
        "stopped": 0,
        "pending": 0,
    }

    return mock_client


@pytest.fixture
def mock_ssm_inventory_client(mock_config: Any) -> Any:
    """Create a mock SSMInventoryClient.

    Returns:
        Mock SSMInventoryClient with predefined behavior.
    """
    from metrics import ComplianceStatus

    mock_client = MagicMock()
    mock_client.config = mock_config

    # Default return values
    mock_client.get_managed_instances.return_value = []
    mock_client.get_instance_compliance.return_value = {
        "i-1": ComplianceStatus.COMPLIANT,
        "i-2": ComplianceStatus.COMPLIANT,
    }

    return mock_client


@pytest.fixture
def mock_cloudwatch_metric_client(mock_config: Any) -> Any:
    """Create a mock CloudWatchMetricClient.

    Returns:
        Mock CloudWatchMetricClient with predefined behavior.
    """
    mock_client = MagicMock()
    mock_client.config = mock_config

    # Default return values
    mock_client.query_instance_metrics.return_value = {
        "i-1": 45.5,
        "i-2": 50.0,
    }
    mock_client.query_cw_agent_metrics.return_value = {
        "i-1": 60.0,
        "i-2": 55.0,
    }
    mock_client.publish_metrics.return_value = 10

    return mock_client


# Helper functions for tests


def create_instance_metrics_list(
    count: int,
    state: str = "running",
    cpu_range: tuple[float, float] = (20.0, 80.0),
) -> list[Any]:
    """Create a list of InstanceMetrics for testing.

    Args:
        count: Number of instances to create.
        state: Instance state (running, stopped, etc.).
        cpu_range: Tuple of (min, max) CPU utilization values.

    Returns:
        List of InstanceMetrics objects.
    """
    from metrics import InstanceMetrics
    import random

    instances = []
    for i in range(count):
        cpu = random.uniform(*cpu_range) if state == "running" else None
        instances.append(
            InstanceMetrics(
                instance_id=f"i-test{i:04d}",
                instance_type="t3.large",
                state=state,
                availability_zone=f"us-east-1{'a' if i % 2 == 0 else 'b'}",
                cpu_utilization=cpu,
                memory_utilization=cpu * 1.1 if cpu else None,
                disk_utilization=40.0 if state == "running" else None,
                is_compliant=True if state == "running" else None,
                hourly_cost=0.0832 if state == "running" else 0.0,
            )
        )
    return instances
