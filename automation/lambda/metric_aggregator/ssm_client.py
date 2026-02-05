"""SSM client wrapper for Hyperion Fleet Manager.

This module provides a wrapper around boto3 SSM operations for querying
inventory data and compliance information.
"""

from __future__ import annotations

from typing import TYPE_CHECKING, Any

import boto3
from aws_lambda_powertools import Logger
from botocore.exceptions import ClientError

from config import Config
from metrics import ComplianceStatus, InstanceMetrics

if TYPE_CHECKING:
    from mypy_boto3_ssm import SSMClient


logger = Logger(child=True)


class SSMClientError(Exception):
    """Custom exception for SSM client errors."""

    pass


class SSMInventoryClient:
    """Wrapper for SSM Inventory and compliance operations.

    This client handles querying SSM Inventory for managed instance
    information and compliance data.
    """

    def __init__(self, config: Config) -> None:
        """Initialize the SSM client.

        Args:
            config: Application configuration.
        """
        self.config = config
        self._client: SSMClient | None = None

    @property
    def client(self) -> SSMClient:
        """Get or create the SSM client.

        Returns:
            Boto3 SSM client.
        """
        if self._client is None:
            self._client = boto3.client("ssm", region_name=self.config.region)
        return self._client

    def get_managed_instances(self) -> list[dict[str, Any]]:
        """Get all managed instances from SSM.

        Returns:
            List of managed instance information dictionaries.

        Raises:
            SSMClientError: If query fails.
        """
        instances: list[dict[str, Any]] = []

        try:
            paginator = self.client.get_paginator("describe_instance_information")

            # Filter for EC2 instances managed by SSM
            filters = [
                {"Key": "ResourceType", "Values": ["EC2Instance"]},
            ]

            for page in paginator.paginate(Filters=filters):
                for instance_info in page.get("InstanceInformationList", []):
                    instances.append({
                        "instance_id": instance_info.get("InstanceId", ""),
                        "ping_status": instance_info.get("PingStatus", "Unknown"),
                        "platform_type": instance_info.get("PlatformType", "Unknown"),
                        "platform_name": instance_info.get("PlatformName", "Unknown"),
                        "platform_version": instance_info.get("PlatformVersion", ""),
                        "agent_version": instance_info.get("AgentVersion", ""),
                        "is_latest_version": instance_info.get("IsLatestVersion", False),
                        "computer_name": instance_info.get("ComputerName", ""),
                        "ip_address": instance_info.get("IPAddress", ""),
                        "resource_type": instance_info.get("ResourceType", ""),
                    })

            logger.info(
                "Retrieved managed instances",
                extra={"instance_count": len(instances)},
            )
            return instances

        except ClientError as e:
            error_code = e.response.get("Error", {}).get("Code", "Unknown")
            error_message = e.response.get("Error", {}).get("Message", str(e))
            logger.error(
                "Failed to get managed instances",
                extra={"error_code": error_code, "error_message": error_message},
            )
            raise SSMClientError(
                f"Failed to get managed instances: {error_code} - {error_message}"
            ) from e

    def get_inventory(
        self, instance_ids: list[str] | None = None
    ) -> list[dict[str, Any]]:
        """Get SSM inventory for instances.

        Args:
            instance_ids: Optional list of instance IDs to filter.
                         If None, retrieves inventory for all instances.

        Returns:
            List of inventory entries.

        Raises:
            SSMClientError: If query fails.
        """
        inventory_items: list[dict[str, Any]] = []

        try:
            filters = []
            if instance_ids:
                # SSM Inventory uses resource ID format
                filters.append({
                    "Key": "AWS:InstanceInformation.InstanceId",
                    "Values": instance_ids,
                    "Type": "Equal",
                })

            paginator = self.client.get_paginator("get_inventory")

            for page in paginator.paginate(Filters=filters if filters else []):
                for entity in page.get("Entities", []):
                    instance_id = entity.get("Id", "")
                    content = entity.get("Data", {})

                    # Extract instance information
                    instance_info = content.get("AWS:InstanceInformation", {})
                    if instance_info:
                        content_items = instance_info.get("Content", [])
                        if content_items:
                            inventory_items.append({
                                "instance_id": instance_id,
                                **content_items[0],
                            })

            logger.debug(
                "Retrieved inventory",
                extra={"item_count": len(inventory_items)},
            )
            return inventory_items

        except ClientError as e:
            error_code = e.response.get("Error", {}).get("Code", "Unknown")
            error_message = e.response.get("Error", {}).get("Message", str(e))
            logger.error(
                "Failed to get inventory",
                extra={"error_code": error_code, "error_message": error_message},
            )
            raise SSMClientError(
                f"Failed to get inventory: {error_code} - {error_message}"
            ) from e

    def get_compliance_summary(self) -> dict[str, int]:
        """Get compliance summary across all managed instances.

        Returns:
            Dictionary with compliance counts by status.

        Raises:
            SSMClientError: If query fails.
        """
        try:
            response = self.client.list_resource_compliance_summaries(
                Filters=[
                    {
                        "Key": "ComplianceType",
                        "Values": ["Association", "Patch"],
                        "Type": "EQUAL",
                    }
                ]
            )

            summary = {
                "compliant": 0,
                "non_compliant": 0,
                "unknown": 0,
            }

            for item in response.get("ResourceComplianceSummaryItems", []):
                status = item.get("Status", "UNKNOWN").upper()
                if status == "COMPLIANT":
                    summary["compliant"] += 1
                elif status == "NON_COMPLIANT":
                    summary["non_compliant"] += 1
                else:
                    summary["unknown"] += 1

            logger.info("Retrieved compliance summary", extra={"summary": summary})
            return summary

        except ClientError as e:
            error_code = e.response.get("Error", {}).get("Code", "Unknown")
            error_message = e.response.get("Error", {}).get("Message", str(e))
            logger.error(
                "Failed to get compliance summary",
                extra={"error_code": error_code, "error_message": error_message},
            )
            raise SSMClientError(
                f"Failed to get compliance summary: {error_code} - {error_message}"
            ) from e

    def get_instance_compliance(
        self, instance_ids: list[str]
    ) -> dict[str, ComplianceStatus]:
        """Get compliance status for specific instances.

        Args:
            instance_ids: List of instance IDs to check.

        Returns:
            Dictionary mapping instance ID to compliance status.

        Raises:
            SSMClientError: If query fails.
        """
        compliance_map: dict[str, ComplianceStatus] = {
            iid: ComplianceStatus.UNKNOWN for iid in instance_ids
        }

        if not instance_ids:
            return compliance_map

        try:
            paginator = self.client.get_paginator("list_compliance_items")

            for instance_id in instance_ids:
                try:
                    # Get compliance items for this instance
                    for page in paginator.paginate(
                        ResourceIds=[instance_id],
                        ResourceTypes=["ManagedInstance"],
                    ):
                        for item in page.get("ComplianceItems", []):
                            status = item.get("Status", "UNKNOWN").upper()
                            if status == "NON_COMPLIANT":
                                # Any non-compliant item makes the instance non-compliant
                                compliance_map[instance_id] = ComplianceStatus.NON_COMPLIANT
                                break
                            elif status == "COMPLIANT":
                                # Set to compliant only if not already non-compliant
                                if compliance_map[instance_id] == ComplianceStatus.UNKNOWN:
                                    compliance_map[instance_id] = ComplianceStatus.COMPLIANT

                except ClientError as e:
                    # Log but continue with other instances
                    logger.warning(
                        "Failed to get compliance for instance",
                        extra={
                            "instance_id": instance_id,
                            "error": str(e),
                        },
                    )
                    continue

            logger.debug(
                "Retrieved instance compliance",
                extra={"instance_count": len(instance_ids)},
            )
            return compliance_map

        except ClientError as e:
            error_code = e.response.get("Error", {}).get("Code", "Unknown")
            error_message = e.response.get("Error", {}).get("Message", str(e))
            logger.error(
                "Failed to get instance compliance",
                extra={"error_code": error_code, "error_message": error_message},
            )
            raise SSMClientError(
                f"Failed to get instance compliance: {error_code} - {error_message}"
            ) from e

    def get_patch_compliance(self, instance_ids: list[str]) -> dict[str, dict[str, Any]]:
        """Get patch compliance details for instances.

        Args:
            instance_ids: List of instance IDs to check.

        Returns:
            Dictionary mapping instance ID to patch compliance details.

        Raises:
            SSMClientError: If query fails.
        """
        patch_compliance: dict[str, dict[str, Any]] = {}

        try:
            for instance_id in instance_ids:
                try:
                    response = self.client.describe_instance_patch_states(
                        InstanceIds=[instance_id]
                    )

                    for patch_state in response.get("InstancePatchStates", []):
                        patch_compliance[instance_id] = {
                            "installed_count": patch_state.get("InstalledCount", 0),
                            "installed_other_count": patch_state.get(
                                "InstalledOtherCount", 0
                            ),
                            "missing_count": patch_state.get("MissingCount", 0),
                            "failed_count": patch_state.get("FailedCount", 0),
                            "not_applicable_count": patch_state.get(
                                "NotApplicableCount", 0
                            ),
                            "operation": patch_state.get("Operation", "Unknown"),
                            "operation_end_time": patch_state.get("OperationEndTime"),
                        }

                except ClientError:
                    # Instance may not have patch data
                    patch_compliance[instance_id] = {
                        "installed_count": 0,
                        "missing_count": 0,
                        "failed_count": 0,
                    }

            return patch_compliance

        except ClientError as e:
            error_code = e.response.get("Error", {}).get("Code", "Unknown")
            error_message = e.response.get("Error", {}).get("Message", str(e))
            logger.error(
                "Failed to get patch compliance",
                extra={"error_code": error_code, "error_message": error_message},
            )
            raise SSMClientError(
                f"Failed to get patch compliance: {error_code} - {error_message}"
            ) from e


class EC2InstanceClient:
    """Client for EC2 instance information not available through SSM."""

    def __init__(self, config: Config) -> None:
        """Initialize the EC2 client.

        Args:
            config: Application configuration.
        """
        self.config = config
        self._client = None

    @property
    def client(self):
        """Get or create the EC2 client."""
        if self._client is None:
            self._client = boto3.client("ec2", region_name=self.config.region)
        return self._client

    def get_fleet_instances(self, fleet_name: str) -> list[InstanceMetrics]:
        """Get all instances in the fleet.

        Args:
            fleet_name: Name of the fleet (used in tag filtering).

        Returns:
            List of InstanceMetrics with basic instance information.

        Raises:
            SSMClientError: If query fails.
        """
        instances: list[InstanceMetrics] = []

        try:
            paginator = self.client.get_paginator("describe_instances")

            # Filter by fleet tag
            filters = [
                {
                    "Name": "tag:Fleet",
                    "Values": [fleet_name],
                },
            ]

            for page in paginator.paginate(Filters=filters):
                for reservation in page.get("Reservations", []):
                    for instance in reservation.get("Instances", []):
                        instance_id = instance.get("InstanceId", "")
                        instance_type = instance.get("InstanceType", "unknown")
                        state = instance.get("State", {}).get("Name", "unknown")
                        az = instance.get("Placement", {}).get(
                            "AvailabilityZone", "unknown"
                        )

                        # Calculate hourly cost
                        hourly_cost = self.config.get_instance_cost(instance_type)

                        instances.append(
                            InstanceMetrics(
                                instance_id=instance_id,
                                instance_type=instance_type,
                                availability_zone=az,
                                state=state,
                                hourly_cost=hourly_cost if state == "running" else 0.0,
                            )
                        )

            logger.info(
                "Retrieved fleet instances",
                extra={"fleet_name": fleet_name, "instance_count": len(instances)},
            )
            return instances

        except ClientError as e:
            error_code = e.response.get("Error", {}).get("Code", "Unknown")
            error_message = e.response.get("Error", {}).get("Message", str(e))
            logger.error(
                "Failed to get fleet instances",
                extra={
                    "fleet_name": fleet_name,
                    "error_code": error_code,
                    "error_message": error_message,
                },
            )
            raise SSMClientError(
                f"Failed to get fleet instances: {error_code} - {error_message}"
            ) from e

    def get_instance_counts_by_state(
        self, instances: list[InstanceMetrics]
    ) -> dict[str, int]:
        """Count instances by state.

        Args:
            instances: List of instance metrics.

        Returns:
            Dictionary mapping state to count.
        """
        counts: dict[str, int] = {
            "running": 0,
            "stopped": 0,
            "pending": 0,
            "stopping": 0,
            "terminated": 0,
            "shutting-down": 0,
        }

        for instance in instances:
            state = instance.state.lower()
            if state in counts:
                counts[state] += 1
            else:
                counts[state] = 1

        return counts
