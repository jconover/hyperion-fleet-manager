"""Main Lambda handler for Hyperion Fleet Manager metric aggregation.

This Lambda function is triggered by CloudWatch Events every 5 minutes to:
- Aggregate metrics across the fleet (CPU, Memory, Disk utilization)
- Count instances by state
- Calculate compliance percentage
- Compute cost per instance
- Publish aggregated metrics to a custom CloudWatch namespace

The function uses AWS Lambda Powertools for structured logging and tracing.
"""

from __future__ import annotations

from typing import Any

from aws_lambda_powertools import Logger, Metrics, Tracer
from aws_lambda_powertools.metrics import MetricUnit
from aws_lambda_powertools.utilities.typing import LambdaContext

from cloudwatch_client import CloudWatchClientError, CloudWatchMetricClient
from config import MetricNamespace, get_config
from metrics import ComplianceStatus, FleetMetrics, MetricAggregator
from ssm_client import EC2InstanceClient, SSMClientError, SSMInventoryClient

# Initialize Lambda Powertools
logger = Logger(service="hyperion-metric-aggregator")
tracer = Tracer(service="hyperion-metric-aggregator")
metrics = Metrics(namespace="Hyperion/FleetManager", service="metric-aggregator")


class MetricAggregationError(Exception):
    """Custom exception for metric aggregation failures."""

    pass


@tracer.capture_method
def collect_instance_metrics(
    ec2_client: EC2InstanceClient,
    ssm_client: SSMInventoryClient,
    cloudwatch_client: CloudWatchMetricClient,
    fleet_name: str,
) -> FleetMetrics:
    """Collect metrics from all fleet instances.

    Args:
        ec2_client: EC2 instance client.
        ssm_client: SSM inventory client.
        cloudwatch_client: CloudWatch metric client.
        fleet_name: Name of the fleet to query.

    Returns:
        Aggregated fleet metrics.

    Raises:
        MetricAggregationError: If metric collection fails.
    """
    logger.info("Starting metric collection", extra={"fleet_name": fleet_name})

    try:
        # Get all instances in the fleet
        instances = ec2_client.get_fleet_instances(fleet_name)

        if not instances:
            logger.warning("No instances found in fleet", extra={"fleet_name": fleet_name})
            return FleetMetrics()

        # Get instance counts by state
        state_counts = ec2_client.get_instance_counts_by_state(instances)

        # Get running instance IDs for metric queries
        running_instance_ids = [
            i.instance_id for i in instances if i.state == "running"
        ]

        # Query CPU utilization from CloudWatch
        cpu_metrics = {}
        if running_instance_ids:
            cpu_metrics = cloudwatch_client.query_instance_metrics(
                instance_ids=running_instance_ids,
                metric_name="CPUUtilization",
                namespace=MetricNamespace.EC2,
            )

        # Query memory utilization from CloudWatch Agent
        memory_metrics = cloudwatch_client.query_cw_agent_metrics(
            instance_ids=running_instance_ids,
            metric_name="mem_used_percent",
        )

        # Query disk utilization from CloudWatch Agent
        disk_metrics = cloudwatch_client.query_cw_agent_metrics(
            instance_ids=running_instance_ids,
            metric_name="disk_used_percent",
        )

        # Get compliance data
        compliance_data = ssm_client.get_instance_compliance(running_instance_ids)

        # Update instance metrics with collected data
        for instance in instances:
            if instance.instance_id in cpu_metrics:
                instance.cpu_utilization = cpu_metrics.get(instance.instance_id)
            if instance.instance_id in memory_metrics:
                instance.memory_utilization = memory_metrics.get(instance.instance_id)
            if instance.instance_id in disk_metrics:
                instance.disk_utilization = disk_metrics.get(instance.instance_id)
            if instance.instance_id in compliance_data:
                instance.is_compliant = (
                    compliance_data[instance.instance_id] == ComplianceStatus.COMPLIANT
                )

        # Calculate aggregated metrics
        fleet_metrics = _aggregate_instance_metrics(instances, state_counts, compliance_data)

        logger.info(
            "Metric collection complete",
            extra={
                "total_instances": fleet_metrics.total_instances,
                "running_instances": fleet_metrics.running_instances,
                "avg_cpu": fleet_metrics.avg_cpu_utilization,
            },
        )

        return fleet_metrics

    except (SSMClientError, CloudWatchClientError) as e:
        logger.error("Failed to collect metrics", extra={"error": str(e)})
        raise MetricAggregationError(f"Metric collection failed: {e}") from e


def _aggregate_instance_metrics(
    instances: list,
    state_counts: dict[str, int],
    compliance_data: dict[str, ComplianceStatus],
) -> FleetMetrics:
    """Aggregate individual instance metrics into fleet-level metrics.

    Args:
        instances: List of instance metrics.
        state_counts: Dictionary of instance state counts.
        compliance_data: Dictionary of instance compliance status.

    Returns:
        Aggregated fleet metrics.
    """
    fleet_metrics = FleetMetrics(
        total_instances=len(instances),
        running_instances=state_counts.get("running", 0),
        stopped_instances=state_counts.get("stopped", 0),
        pending_instances=state_counts.get("pending", 0),
        instance_metrics=instances,
    )

    # Calculate averages for running instances
    running_instances = [i for i in instances if i.state == "running"]

    if running_instances:
        # CPU utilization average
        cpu_values = [
            i.cpu_utilization for i in running_instances if i.cpu_utilization is not None
        ]
        if cpu_values:
            fleet_metrics.avg_cpu_utilization = round(
                sum(cpu_values) / len(cpu_values), 2
            )

        # Memory utilization average
        memory_values = [
            i.memory_utilization
            for i in running_instances
            if i.memory_utilization is not None
        ]
        if memory_values:
            fleet_metrics.avg_memory_utilization = round(
                sum(memory_values) / len(memory_values), 2
            )

        # Disk utilization average
        disk_values = [
            i.disk_utilization
            for i in running_instances
            if i.disk_utilization is not None
        ]
        if disk_values:
            fleet_metrics.avg_disk_utilization = round(
                sum(disk_values) / len(disk_values), 2
            )

        # Calculate total hourly cost
        fleet_metrics.total_hourly_cost = sum(i.hourly_cost for i in running_instances)

    # Calculate compliance counts
    for status in compliance_data.values():
        if status == ComplianceStatus.COMPLIANT:
            fleet_metrics.compliant_instances += 1
        elif status == ComplianceStatus.NON_COMPLIANT:
            fleet_metrics.non_compliant_instances += 1

    return fleet_metrics


@tracer.capture_method
def publish_aggregated_metrics(
    cloudwatch_client: CloudWatchMetricClient,
    aggregator: MetricAggregator,
    fleet_metrics: FleetMetrics,
) -> int:
    """Publish aggregated metrics to CloudWatch.

    Args:
        cloudwatch_client: CloudWatch metric client.
        aggregator: Metric aggregator instance.
        fleet_metrics: Aggregated fleet metrics.

    Returns:
        Number of metrics published.

    Raises:
        MetricAggregationError: If publishing fails.
    """
    logger.info("Publishing aggregated metrics")

    try:
        # Generate metric values
        metric_values = aggregator.aggregate(fleet_metrics)

        # Publish to CloudWatch
        published_count = cloudwatch_client.publish_metrics(metric_values)

        logger.info(
            "Successfully published metrics",
            extra={"metric_count": published_count},
        )

        return published_count

    except CloudWatchClientError as e:
        logger.error("Failed to publish metrics", extra={"error": str(e)})
        raise MetricAggregationError(f"Failed to publish metrics: {e}") from e


@metrics.log_metrics(capture_cold_start_metric=True)
@tracer.capture_lambda_handler
@logger.inject_lambda_context(log_event=True)
def lambda_handler(event: dict[str, Any], context: LambdaContext) -> dict[str, Any]:
    """Main Lambda handler for metric aggregation.

    This function is triggered by CloudWatch Events (rate: 5 minutes) and:
    1. Queries EC2 for fleet instances
    2. Queries SSM for inventory and compliance data
    3. Queries CloudWatch for utilization metrics
    4. Aggregates metrics across the fleet
    5. Publishes aggregated metrics to custom namespace

    Args:
        event: CloudWatch Events event payload.
        context: Lambda context object.

    Returns:
        Response dictionary with status and metrics published.
    """
    logger.info("Starting metric aggregation")

    try:
        # Initialize configuration
        config = get_config()
        logger.append_keys(
            environment=config.environment,
            fleet_name=config.fleet_name,
        )

        # Initialize clients
        ec2_client = EC2InstanceClient(config)
        ssm_client = SSMInventoryClient(config)
        cloudwatch_client = CloudWatchMetricClient(config)
        aggregator = MetricAggregator(config.environment, config.fleet_name)

        # Collect metrics from all sources
        fleet_metrics = collect_instance_metrics(
            ec2_client, ssm_client, cloudwatch_client, config.fleet_name
        )

        # Publish aggregated metrics
        published_count = publish_aggregated_metrics(
            cloudwatch_client, aggregator, fleet_metrics
        )

        # Add custom metrics for Lambda Powertools
        metrics.add_metric(
            name="InstancesProcessed", unit=MetricUnit.Count, value=fleet_metrics.total_instances
        )
        metrics.add_metric(
            name="MetricsPublished", unit=MetricUnit.Count, value=published_count
        )

        response = {
            "statusCode": 200,
            "body": {
                "message": "Metric aggregation completed successfully",
                "fleet_name": config.fleet_name,
                "environment": config.environment,
                "instances_processed": fleet_metrics.total_instances,
                "running_instances": fleet_metrics.running_instances,
                "metrics_published": published_count,
                "fleet_health_score": aggregator.health_score_calculator.calculate(
                    fleet_metrics
                ),
                "compliance_score": aggregator.compliance_score_calculator.calculate(
                    fleet_metrics
                ),
            },
        }

        logger.info("Metric aggregation completed", extra=response["body"])
        return response

    except MetricAggregationError as e:
        logger.error("Metric aggregation failed", extra={"error": str(e)})
        metrics.add_metric(name="AggregationErrors", unit=MetricUnit.Count, value=1)
        return {
            "statusCode": 500,
            "body": {
                "message": "Metric aggregation failed",
                "error": str(e),
            },
        }

    except Exception as e:
        logger.exception("Unexpected error during metric aggregation")
        metrics.add_metric(name="UnexpectedErrors", unit=MetricUnit.Count, value=1)
        return {
            "statusCode": 500,
            "body": {
                "message": "Unexpected error occurred",
                "error": str(e),
            },
        }
