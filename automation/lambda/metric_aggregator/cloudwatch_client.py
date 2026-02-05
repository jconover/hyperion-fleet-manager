"""CloudWatch client wrapper for Hyperion Fleet Manager.

This module provides a wrapper around boto3 CloudWatch operations,
including batch metric publishing and metric querying with pagination.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import TYPE_CHECKING, Any

import boto3
from aws_lambda_powertools import Logger
from botocore.exceptions import ClientError

from config import Config, MetricNamespace
from metrics import MetricValue

if TYPE_CHECKING:
    from mypy_boto3_cloudwatch import CloudWatchClient
    from mypy_boto3_cloudwatch.type_defs import MetricDataResultTypeDef


logger = Logger(child=True)


class CloudWatchClientError(Exception):
    """Custom exception for CloudWatch client errors."""

    pass


class CloudWatchMetricClient:
    """Wrapper for CloudWatch metric operations.

    This client handles batch publishing of metrics and querying
    with proper pagination support.
    """

    # CloudWatch PutMetricData limit
    MAX_METRICS_PER_BATCH = 20

    def __init__(self, config: Config) -> None:
        """Initialize the CloudWatch client.

        Args:
            config: Application configuration.
        """
        self.config = config
        self._client: CloudWatchClient | None = None

    @property
    def client(self) -> CloudWatchClient:
        """Get or create the CloudWatch client.

        Returns:
            Boto3 CloudWatch client.
        """
        if self._client is None:
            self._client = boto3.client("cloudwatch", region_name=self.config.region)
        return self._client

    def publish_metrics(
        self, metrics: list[MetricValue], namespace: str | None = None
    ) -> int:
        """Publish metrics to CloudWatch in batches.

        Args:
            metrics: List of MetricValue objects to publish.
            namespace: CloudWatch namespace. Defaults to config namespace.

        Returns:
            Number of metrics published successfully.

        Raises:
            CloudWatchClientError: If publishing fails.
        """
        if not metrics:
            logger.info("No metrics to publish")
            return 0

        namespace = namespace or self.config.metric_namespace
        published_count = 0

        # Split into batches of MAX_METRICS_PER_BATCH
        batches = [
            metrics[i : i + self.MAX_METRICS_PER_BATCH]
            for i in range(0, len(metrics), self.MAX_METRICS_PER_BATCH)
        ]

        logger.info(
            "Publishing metrics",
            extra={
                "total_metrics": len(metrics),
                "batch_count": len(batches),
                "namespace": namespace,
            },
        )

        for batch_index, batch in enumerate(batches):
            try:
                metric_data = [m.to_cloudwatch_format() for m in batch]
                self.client.put_metric_data(Namespace=namespace, MetricData=metric_data)
                published_count += len(batch)
                logger.debug(
                    "Published metric batch",
                    extra={
                        "batch_index": batch_index,
                        "batch_size": len(batch),
                    },
                )
            except ClientError as e:
                error_code = e.response.get("Error", {}).get("Code", "Unknown")
                error_message = e.response.get("Error", {}).get("Message", str(e))
                logger.error(
                    "Failed to publish metric batch",
                    extra={
                        "batch_index": batch_index,
                        "error_code": error_code,
                        "error_message": error_message,
                    },
                )
                raise CloudWatchClientError(
                    f"Failed to publish metrics: {error_code} - {error_message}"
                ) from e

        logger.info(
            "Successfully published all metrics",
            extra={"published_count": published_count},
        )
        return published_count

    def get_metric_statistics(
        self,
        namespace: str,
        metric_name: str,
        dimensions: list[dict[str, str]],
        start_time: datetime | None = None,
        end_time: datetime | None = None,
        period: int = 300,
        statistics: list[str] | None = None,
    ) -> dict[str, Any]:
        """Get metric statistics from CloudWatch.

        Args:
            namespace: CloudWatch namespace.
            metric_name: Name of the metric.
            dimensions: List of dimension filters.
            start_time: Start of time range. Defaults to 5 minutes ago.
            end_time: End of time range. Defaults to now.
            period: Period in seconds. Defaults to 300 (5 minutes).
            statistics: List of statistics to retrieve. Defaults to ["Average"].

        Returns:
            Dictionary with metric statistics.

        Raises:
            CloudWatchClientError: If query fails.
        """
        if end_time is None:
            end_time = datetime.now(timezone.utc)
        if start_time is None:
            start_time = end_time - timedelta(minutes=self.config.aggregation_period_minutes)
        if statistics is None:
            statistics = ["Average"]

        try:
            response = self.client.get_metric_statistics(
                Namespace=namespace,
                MetricName=metric_name,
                Dimensions=dimensions,
                StartTime=start_time,
                EndTime=end_time,
                Period=period,
                Statistics=statistics,
            )
            return response
        except ClientError as e:
            error_code = e.response.get("Error", {}).get("Code", "Unknown")
            error_message = e.response.get("Error", {}).get("Message", str(e))
            logger.error(
                "Failed to get metric statistics",
                extra={
                    "metric_name": metric_name,
                    "namespace": namespace,
                    "error_code": error_code,
                },
            )
            raise CloudWatchClientError(
                f"Failed to get metric statistics: {error_code} - {error_message}"
            ) from e

    def get_metric_data(
        self,
        queries: list[dict[str, Any]],
        start_time: datetime | None = None,
        end_time: datetime | None = None,
    ) -> list[MetricDataResultTypeDef]:
        """Get metric data using GetMetricData API with pagination.

        This method handles pagination automatically and returns all results.

        Args:
            queries: List of metric data queries in CloudWatch format.
            start_time: Start of time range. Defaults to 5 minutes ago.
            end_time: End of time range. Defaults to now.

        Returns:
            List of metric data results.

        Raises:
            CloudWatchClientError: If query fails.
        """
        if end_time is None:
            end_time = datetime.now(timezone.utc)
        if start_time is None:
            start_time = end_time - timedelta(minutes=self.config.aggregation_period_minutes)

        all_results: list[MetricDataResultTypeDef] = []
        next_token: str | None = None

        try:
            while True:
                kwargs: dict[str, Any] = {
                    "MetricDataQueries": queries,
                    "StartTime": start_time,
                    "EndTime": end_time,
                }
                if next_token:
                    kwargs["NextToken"] = next_token

                response = self.client.get_metric_data(**kwargs)
                all_results.extend(response.get("MetricDataResults", []))

                next_token = response.get("NextToken")
                if not next_token:
                    break

            logger.debug(
                "Retrieved metric data",
                extra={"query_count": len(queries), "result_count": len(all_results)},
            )
            return all_results

        except ClientError as e:
            error_code = e.response.get("Error", {}).get("Code", "Unknown")
            error_message = e.response.get("Error", {}).get("Message", str(e))
            logger.error(
                "Failed to get metric data",
                extra={"error_code": error_code, "query_count": len(queries)},
            )
            raise CloudWatchClientError(
                f"Failed to get metric data: {error_code} - {error_message}"
            ) from e

    def query_instance_metrics(
        self,
        instance_ids: list[str],
        metric_name: str,
        namespace: str = MetricNamespace.EC2,
        start_time: datetime | None = None,
        end_time: datetime | None = None,
        period: int = 300,
        stat: str = "Average",
    ) -> dict[str, float | None]:
        """Query a metric for multiple instances.

        Args:
            instance_ids: List of EC2 instance IDs.
            metric_name: Name of the metric to query.
            namespace: CloudWatch namespace.
            start_time: Start of time range.
            end_time: End of time range.
            period: Period in seconds.
            stat: Statistic to retrieve.

        Returns:
            Dictionary mapping instance ID to metric value.
        """
        if not instance_ids:
            return {}

        if end_time is None:
            end_time = datetime.now(timezone.utc)
        if start_time is None:
            start_time = end_time - timedelta(minutes=self.config.aggregation_period_minutes)

        # Build queries for each instance
        queries: list[dict[str, Any]] = []
        for idx, instance_id in enumerate(instance_ids):
            query_id = f"m{idx}"
            queries.append({
                "Id": query_id,
                "MetricStat": {
                    "Metric": {
                        "Namespace": namespace,
                        "MetricName": metric_name,
                        "Dimensions": [
                            {"Name": "InstanceId", "Value": instance_id}
                        ],
                    },
                    "Period": period,
                    "Stat": stat,
                },
                "ReturnData": True,
            })

        # Query in batches of 500 (CloudWatch limit)
        batch_size = 500
        results: dict[str, float | None] = {iid: None for iid in instance_ids}

        for i in range(0, len(queries), batch_size):
            batch_queries = queries[i : i + batch_size]
            batch_instance_ids = instance_ids[i : i + batch_size]

            try:
                metric_results = self.get_metric_data(
                    batch_queries, start_time, end_time
                )

                for result in metric_results:
                    # Extract instance ID from query ID
                    query_id = result.get("Id", "")
                    if query_id.startswith("m"):
                        try:
                            idx = int(query_id[1:])
                            instance_id = batch_instance_ids[idx - (i)]
                            values = result.get("Values", [])
                            if values:
                                # Use the most recent value
                                results[instance_id] = values[0]
                        except (ValueError, IndexError):
                            continue

            except CloudWatchClientError:
                logger.warning(
                    "Failed to query batch metrics",
                    extra={"batch_start": i, "metric_name": metric_name},
                )
                continue

        return results

    def query_cw_agent_metrics(
        self,
        instance_ids: list[str],
        metric_name: str,
        start_time: datetime | None = None,
        end_time: datetime | None = None,
    ) -> dict[str, float | None]:
        """Query CloudWatch Agent metrics (memory, disk) for instances.

        Args:
            instance_ids: List of EC2 instance IDs.
            metric_name: Metric name (e.g., "mem_used_percent").
            start_time: Start of time range.
            end_time: End of time range.

        Returns:
            Dictionary mapping instance ID to metric value.
        """
        return self.query_instance_metrics(
            instance_ids=instance_ids,
            metric_name=metric_name,
            namespace=MetricNamespace.CW_AGENT,
            start_time=start_time,
            end_time=end_time,
        )
